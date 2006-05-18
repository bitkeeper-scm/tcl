#include <stdio.h>
#include <stdarg.h>
#include "tclInt.h"
#include "Lcompile.h"
#include "Lgrammar.h"
#include "Last.h"

static L_compile_frame *lframe = NULL;
Tcl_Obj *L_errors = NULL;
int L_line_number = 0;
void *L_current_ast = NULL;
int L_interactive = 0;

/* these are generated by lex: */
void *L__scan_bytes (const char *bytes, int len);
void L__delete_buffer(void *buf);

/* functions local to this file */
static void L_free_ast(L_ast_node *ast);
static int global_symbol_p(L_symbol *symbol);
static int create_array_string_rep(char *rep, int pos, L_type *dim);
static int check_and_figure_array_size(L_type *dim);

/* we keep track of each AST node we allocate and free them all at once */
L_ast_node *ast_trace_root = NULL;

int 
L_PragmaObjCmd(
    ClientData clientData,
    Tcl_Interp *interp, 
    int objc,
    Tcl_Obj *CONST objv[])
{ 
    int stringLen; 
    char *stringPtr;
    L_ast_node *ast;

    if (objc != 2) {
        L_bomb("Assertion failed in L_PragmaObjCmd: we expected only 1 argument but got %d.",
               objc - 1);
    }
    stringPtr = Tcl_GetStringFromObj(objv [1], &stringLen);
    if (LParseScript(interp, stringPtr, stringLen, &ast) != TCL_OK) {
        return TCL_ERROR;
    }
    return LCompileScript(interp, stringPtr, stringLen, NULL, ast);
}

/* Parse an L script into an AST */
int
LParseScript(
    Tcl_Interp *interp,
    CONST char *str,
    int numBytes,
    L_ast_node **L_ast
) {
    void    *lex_buffer = (void *)L__scan_bytes(str, numBytes);

    L_trace("Parsing: %.*s", numBytes, str);
    L_line_number = 0;
    L_errors = NULL;
    L_parse();
    if (L_ast == NULL) {
        L_free_ast(L_current_ast);
    } else {
        *L_ast = L_current_ast;
    }
    L__delete_buffer(lex_buffer);
    if (L_errors) {
            Tcl_SetObjResult(interp, L_errors);
            L_trace("Failed to parse.");
            return TCL_ERROR;
    }
    L_trace("Done parsing.");
    return TCL_OK;
}


/* Compile an AST into Tcl ByteCodes */
int
LCompileScript(
    Tcl_Interp *interp,
    CONST char *str,
    int numBytes,
    CompileEnv *envPtr,
    void *ast)
{
    L_trace("Compiling: \n %.*s", numBytes, str);

    L_frame_push(interp, envPtr);
    if (envPtr)
        lframe->originalCodeNext = envPtr->codeNext;

    switch(((L_ast_node*)ast)->type) {
    case L_NODE_FUNCTION_DECLARATION:
        L_compile_function_decls(ast);
        break;
    default:
        L_bomb("LCompileScript error, expecting a function declaration, "
               "got: %s", L_node_type_tostr[((L_ast_node*)ast)->type]);
    }
    if (envPtr)
        maybeFixupEmptyCode(lframe);
    L_frame_pop();

    L_free_ast(ast);
    if (L_errors) {
            Tcl_SetObjResult(interp, L_errors);
            L_trace("Failed to compile.");
            return TCL_ERROR;
    }
    L_trace("Done compiling");
    return TCL_OK;
}

void
L_compile_function_decls(L_function_declaration *fun)
{
    Proc *procPtr;
    CompileEnv *envPtr;
    Tcl_Obj *bodyObjPtr;
    Tcl_Command cmd;

    if (!fun) return;
    envPtr = (CompileEnv *)ckalloc(sizeof(CompileEnv));
    L_frame_push(lframe->interp, envPtr);

    procPtr = (Proc *)ckalloc(sizeof(Proc));
    procPtr->iPtr = (struct Interp *)lframe->interp;
    procPtr->refCount = 1;
    procPtr->bodyPtr = Tcl_NewObj();
    procPtr->numArgs  = 0;
    procPtr->numCompiledLocals = 0;
    procPtr->firstLocalPtr = NULL;
    procPtr->lastLocalPtr = NULL;

    TclInitCompileEnv(lframe->interp, envPtr, "L Compiler",
                      strlen("L Compiler"));
    lframe->originalCodeNext = envPtr->codeNext;
    envPtr->procPtr = procPtr;

    L_compile_parameters(fun->params);
    L_compile_block(fun->body);
    
    /* This is the "fall off the end" implicit return. We return "". */
    L_return(FALSE);

    TclInitByteCodeObj(procPtr->bodyPtr, lframe->envPtr);
    bodyObjPtr = TclNewProcBodyObj(procPtr);
    if (bodyObjPtr == NULL) {
        L_bomb("failed to create a ProcBodyObj for some reason");
    }
    Tcl_IncrRefCount(bodyObjPtr);

    cmd = Tcl_CreateObjCommand(lframe->interp, fun->name->u.s,
        TclObjInterpProc, (ClientData) procPtr, TclProcDeleteProc);
    procPtr->cmdPtr = (Command *) cmd;


    TclFreeCompileEnv(lframe->envPtr);
    ckfree((char *)lframe->envPtr);
    L_frame_pop();
    L_compile_function_decls(fun->next);
}

void 
L_compile_variable_decls(L_variable_declaration *var)
{
    L_symbol *symbol;
    int localIndex;

    if (!var) return;
    L_trace("declaring variable %s", var->name->u.s);
    localIndex = TclFindCompiledLocal(var->name->u.s, strlen(var->name->u.s), 
                                      1, 0, lframe->envPtr->procPtr);
    if ((symbol = L_get_symbol(var->name, FALSE)) &&
        !global_symbol_p(symbol))
    {
        L_errorf(var, "Illegal redeclaration of local variable %s",
                 var->name->u.s);
    }
    symbol = L_make_symbol(var->name, var->type->kind, NULL, localIndex);

    if (var->initial_value || var->type->next) {
        if (var->type->next) {
            /* array */
            L_type *array_dimensions = var->type->next;
            int total_size;
            char *arrayRep;

            total_size = check_and_figure_array_size(array_dimensions);
            if (total_size < 0) {
                /* some sort of bad declaration, skip to the next one */
                goto next_decl;
            } else if (total_size == 0) {
                /* XXX variable sized arrays don't work yet. */
                MK_STRING_NODE(var->initial_value, "");
            } else {
                arrayRep = ckalloc(total_size);
                create_array_string_rep(arrayRep, 0, array_dimensions);
                var->initial_value =
                    mk_expression(L_EXPRESSION_STRING, -1, NULL, NULL,
                                  NULL, NULL, NULL);
                var->initial_value->u.s = arrayRep;
            }
        }

        L_compile_expressions(var->initial_value);
        L_STORE_SCALAR(localIndex);
        TclEmitOpcode(INST_POP, lframe->envPtr);
    }
 next_decl:
    L_compile_variable_decls(var->next);
}

/* Verify that the array dimensions in a declaration are valid array
   dimensions, and add up the space requirement of the string representation
   of the array.  The space required for one element is 3: "{} ".  The space
   required S_n for each dimension of size D_n is D_n ((S_n-1 - 1) + 3). */
int
check_and_figure_array_size(L_type *dim)
{
    int retval;

    if (!dim) return 0;
    if (!(dim->array_dim->kind == L_EXPRESSION_INT)) {
        L_errorf(dim, "Invalid array dimension for a declaration, %d",
                 L_expression_tostr[dim->array_dim->kind]);
        return -1;
    }
    if (dim->array_dim->u.i < 0) {
        L_errorf(dim->array_dim, "Negative array dimension: %d",
                 dim->array_dim->u.i);
        return -1;
    }
    retval = check_and_figure_array_size(dim->next);
    if (retval < 0) {
        return retval;
    }

    if (dim->next) {
        return dim->array_dim->u.i * (retval + 2);
    } else {
        return dim->array_dim->u.i * 3;
    }
}

/* Build a "string representation" for a TCL list.  A 3 x 2 array, for
   example, looks like this: {{} {}} {{} {}} {{} {}}\0.  Returns the length of
   the string, or -1 if there was an error. */
int
create_array_string_rep(
    char *rep,                  /* The string we're building */
    int pos,                    /* Our current position in the string */
    L_type *dim)                /* The array dimensions */
{
    int i, retval;

    if (!dim) { return 0; }

    for (i = 0; i < dim->array_dim->u.i * 3; i += 3) {
        rep[pos + i] = '{';
        retval = create_array_string_rep(rep, pos + i + 1, dim->next);
        if (retval < 0) {
            return -1;
        } else if (retval > 0) {
            /* the -1 is so we overwrite the null on the end */
            pos = retval - i - 1;
        }
        rep[pos + i + 1] = '}';
        rep[pos + i + 2] = ' ';
    }
    rep[pos + i - 1] = '\0';
    return pos + i - 1;
}

int
global_symbol_p(L_symbol *symbol)
{
    /* XXX implement me once we have globals.  --timjr 2006.5.7 */
    return FALSE;
}

void
L_compile_statements(L_statement *stmt)
{
    if (!stmt) return;
    switch (stmt->kind) {
    case L_STATEMENT_BLOCK:
        L_compile_block(stmt->u.block);
        break;
    case L_STATEMENT_EXPR:
        L_compile_expressions(stmt->u.expr);
        /* Expressions leave a value on the evaluation stack, but statements
           don't. So pop the value. */
        TclEmitOpcode(INST_POP, lframe->envPtr);
        break;
    case L_STATEMENT_IF_UNLESS:
        L_compile_if_unless(stmt->u.cond);
        break;
    case L_STATEMENT_LOOP:
        L_compile_loop(stmt->u.loop);
        break;
    case L_STATEMENT_RETURN:
        L_trace("compiling return statement");
        if (stmt->u.expr) {
            L_trace("    with return value");
            /* compile the return value */
            L_compile_expressions(stmt->u.expr);
        } else {
            L_trace("    without return value");
            /* Leave a NULL (an Tcl_Obj with the string rep "") on the stack. */
            TclEmitPush( TclAddLiteralObj(lframe->envPtr, Tcl_NewObj(), NULL),
                         lframe->envPtr );
        }
        /* INST_RETURN_STK involves a little more magic that I haven't wangled out
           yet... but I think it lets us pass back error codes and such that could
           be useful. --timjr 2006.3.31  */
        /* TclEmitOpcode(INST_RETURN_STK, lframe->envPtr); */
        TclEmitOpcode(INST_DONE, lframe->envPtr);
        break;
    }
    L_compile_statements(stmt->next);
}

void
L_compile_block(L_block *block) {
    L_compile_variable_decls(block->decls);
    L_compile_statements(block->body);
}

void 
L_compile_parameters(L_variable_declaration *param)
{
    Proc *procPtr = lframe->envPtr->procPtr;
    CompiledLocal *localPtr;
    int i;
    
    for (i = 0; param; param = param->next, i++) {
        L_trace("Compiling parameter %d (%s)", i, param->name->u.s);
        /* Formal parameters are stored in local variable slots. */
        procPtr->numArgs = i + 1;
        procPtr->numCompiledLocals = i + 1;
        localPtr = (CompiledLocal *) ckalloc(sizeof(CompiledLocal) -
                                             sizeof(localPtr->name) +
                                             strlen(param->name->u.s) + 1);
        if (procPtr->firstLocalPtr == NULL) {
            procPtr->firstLocalPtr = procPtr->lastLocalPtr = localPtr;
        } else {
            procPtr->lastLocalPtr->nextPtr = localPtr;
            procPtr->lastLocalPtr = localPtr;
        }
        localPtr->nextPtr = NULL;
        localPtr->nameLength = strlen(param->name->u.s);
        localPtr->frameIndex = i;
        localPtr->flags = VAR_SCALAR | VAR_ARGUMENT;
        localPtr->resolveInfo = NULL;
        localPtr->defValuePtr = NULL;
        strcpy(localPtr->name, param->name->u.s);
        
        L_make_symbol(param->name, param->type->kind, NULL, i);
    }
}

void 
L_compile_expressions(L_expression *expr)
{
    Tcl_Obj *obj;
    int i = 0;
    L_expression *tmp;

    if (!expr) return;
/*     L_trace("Compiling an expression of type %s", */
/*             L_expression_tostr[expr->kind]); */
    switch (expr->kind) {
    case L_EXPRESSION_FUNCALL:
        TclEmitPush(TclRegisterNewLiteral(lframe->envPtr, expr->a->u.s,
                                          strlen(expr->a->u.s)),
                    lframe->envPtr);
        L_compile_expressions(expr->b);
        /* count the parameters */
        for (tmp = expr->b; tmp; tmp = tmp->next, i++);
        TclEmitInstInt4(INST_INVOKE_STK4, i+1, lframe->envPtr);
        break;
    case L_EXPRESSION_PRE:
    case L_EXPRESSION_POST:
        L_compile_incdec(expr);
        break;
    case L_EXPRESSION_UNARY:
        L_compile_unop(expr);
        break;
    case L_EXPRESSION_BINARY:
        L_compile_binop(expr);
        break;
    case L_EXPRESSION_INT:
        obj = Tcl_NewIntObj(expr->u.i);
        TclEmitPush(TclAddLiteralObj(lframe->envPtr, obj, NULL),
                    lframe->envPtr);
        break;
    case L_EXPRESSION_STRING:
        obj = Tcl_NewStringObj(expr->u.s, strlen(expr->u.s));
        TclEmitPush(TclAddLiteralObj(lframe->envPtr, obj, NULL),
                    lframe->envPtr);
        break;
    case L_EXPRESSION_FLOAT:
        obj = Tcl_NewDoubleObj(expr->u.d);
        TclEmitPush(TclAddLiteralObj(lframe->envPtr, obj, NULL),
                    lframe->envPtr);
        break;
    case L_EXPRESSION_VARIABLE:
        L_push_variable(expr);
        break;
    default:
        L_bomb("Unknown expression type %d", expr->kind);
    }
    L_compile_expressions(expr->next);
}

void L_compile_unop(L_expression *expr)
{
    L_compile_expressions(expr->a);
    switch (expr->op) {
    case T_BANG:
        TclEmitOpcode(INST_LNOT, lframe->envPtr);
        break;
    case T_BITNOT:
        TclEmitOpcode(INST_BITNOT, lframe->envPtr);
        break;
    case T_PLUS:
        TclEmitOpcode(INST_UPLUS, lframe->envPtr);
        break;
    case T_MINUS:
        TclEmitOpcode(INST_UMINUS, lframe->envPtr);
        break;
    default:
        L_bomb("Unknown unary operator %d", expr->op);
    }
}

void L_compile_binop(L_expression *expr)
{
    int instruction = 0;

    if (expr->op == T_EQUALS) {
        L_compile_assignment(expr);
    } else if ((expr->op == T_ANDAND) ||
               (expr->op == T_OROR)) {
        L_compile_short_circuit_op(expr);
    } else {
        L_compile_expressions(expr->a);
        L_compile_expressions(expr->b);
        switch (expr->op) {
        case T_PLUS:
            instruction = INST_ADD;
            break;
        case T_MINUS:
            instruction = INST_SUB;
            break;
        case T_STAR:
            instruction = INST_MULT;
            break;
        case T_SLASH:
            instruction = INST_DIV;
            break;
        case T_PERC:
            instruction = INST_MOD;
            break;
        case T_EQ:
        case T_EQUALEQUAL:
            instruction = INST_EQ;
            break;
        case T_NE:
        case T_NOTEQUAL:
            instruction = INST_NEQ;
            break;
        case T_GT:
        case T_GREATER:
            instruction = INST_GT;
            break;
        case T_GE:
        case T_GREATEREQ:
            instruction = INST_GE;
            break;
        case T_LT:
        case T_LESSTHAN:
            instruction = INST_LT;
            break;
        case T_LE:
        case T_LESSTHANEQ:
            instruction = INST_LE;
            break;
        case T_LSHIFT:
            instruction = INST_LSHIFT;
            break;
        case T_RSHIFT:
            instruction = INST_RSHIFT;
            break;
        case T_BITOR:
            instruction = INST_BITOR;
            break;
        case T_BITXOR:
            instruction = INST_BITXOR;
            break;
        case T_BITAND:
            instruction = INST_BITAND;
            break;
        default:
            L_bomb("Undefined operator %d", expr->op);
        }
        TclEmitOpcode(instruction, lframe->envPtr);
    }
}

void
L_compile_short_circuit_op(L_expression *expr)
{
    JumpFixup fixup;

    L_compile_expressions(expr->a);
    /* In case the operator short-circuits, we need one value on the
       evaluation stack for the jump and one for the value of the
       expression. */
    TclEmitOpcode(INST_DUP, lframe->envPtr);
    if (expr->op == T_ANDAND) {
        TclEmitForwardJump(lframe->envPtr, TCL_FALSE_JUMP, &fixup);
    } else {
        TclEmitForwardJump(lframe->envPtr, TCL_TRUE_JUMP, &fixup);
    }
    /* If the operator doesn't short-circuit, we want to leave the value of
       the second expression on the stack, so remove the value that we DUPed
       above. */
    TclEmitOpcode(INST_POP, lframe->envPtr);
    L_compile_expressions(expr->b);
    TclFixupForwardJumpToHere(lframe->envPtr, &fixup, 127);
}

void
L_compile_if_unless(L_if_unless *cond)
{
    JumpFixup jumpFalse, jumpEnd;

    L_compile_expressions(cond->condition);
    /* emit a jump which will skip the consequent if the top value on the
       stack is false. */
    TclEmitForwardJump(lframe->envPtr, TCL_FALSE_JUMP, &jumpFalse);

    L_frame_push(lframe->interp, lframe->envPtr);
    /* consequent */
    if (cond->if_body != NULL) {
        L_compile_statements(cond->if_body);
        TclFixupForwardJumpToHere(lframe->envPtr, &jumpFalse, 127);
    }
    /* alternate */
    if (cond->else_body != NULL) {
        /* End the scope that was started for the consequent and start a new
           one, copying the jump fixup pointers. */
        L_frame_pop();
        L_frame_push(lframe->interp, lframe->envPtr);
        TclEmitForwardJump(lframe->envPtr, TCL_UNCONDITIONAL_JUMP, &jumpEnd);
        TclFixupForwardJumpToHere(lframe->envPtr, &jumpFalse, 127);
        L_compile_statements(cond->else_body);
        TclFixupForwardJumpToHere(lframe->envPtr, &jumpEnd, 127);

    } else {
        TclFixupForwardJumpToHere(lframe->envPtr, &jumpFalse, 127);
    }
    L_frame_pop();
}

void
L_compile_loop(L_loop *loop)
{
    JumpFixup jumpToCond;
    int bodyCodeOffset, jumpDist;

    TclEmitForwardJump(lframe->envPtr, TCL_UNCONDITIONAL_JUMP, &jumpToCond);
    L_frame_push(lframe->interp, lframe->envPtr);
    bodyCodeOffset = lframe->envPtr->codeNext - lframe->envPtr->codeStart;
    L_compile_statements(loop->body);
    L_frame_pop(lframe->interp, lframe->envPtr);
    if (TclFixupForwardJumpToHere(lframe->envPtr, &jumpToCond, 127)) {
        bodyCodeOffset += 3;
    }
    L_compile_expressions(loop->condition);
    jumpDist = lframe->envPtr->codeNext - lframe->envPtr->codeStart -
        bodyCodeOffset;
    if (jumpDist > 127) {
        TclEmitInstInt4(INST_JUMP_TRUE4, -jumpDist, lframe->envPtr);
    } else {
        TclEmitInstInt1(INST_JUMP_TRUE1, -jumpDist, lframe->envPtr);
    }
}

void
L_push_variable(L_expression *expr)
{
    L_symbol *var;
    L_expression *name = expr->a;

    if (!(var = L_get_symbol(name, TRUE))) return;
    L_LOAD_SCALAR(var->localIndex);
    if (expr->indices) {
        int index_count = 0;
        L_expression *i;

        for (i = expr->indices; i; i = i->indices, index_count++) {
            L_compile_expressions(i->a);
        }
        L_trace("INDICES: %d\n", index_count);

        if (index_count == 1) {
            TclEmitOpcode(INST_LIST_INDEX, lframe->envPtr);
        } else {
            TclEmitInstInt4(INST_LIST_INDEX_MULTI, index_count + 1,
                            lframe->envPtr);
        }
    }
}

void 
L_return(int value_on_stack_p)
{
    if (!value_on_stack_p) {
        /* Leave a NULL (an Tcl_Obj with the string rep "") on the stack. */
        TclEmitPush( TclAddLiteralObj(lframe->envPtr, Tcl_NewObj(), NULL),
                     lframe->envPtr);
    }
    /* INST_RETURN_STK involves a little more magic that I haven't wangled out
       yet... but I think it lets us pass back error codes and such that could
       be useful. --timjr 2006.3.31  */
/*     TclEmitOpcode(INST_RETURN_STK, lframe->envPtr); */
    TclEmitOpcode(INST_DONE, lframe->envPtr);
}

void
L_compile_assignment(L_expression *expr)
{
    L_symbol *var;
    L_expression *lval = expr->a;
    L_expression *rval = expr->b;

    L_trace("COMPILING ASSIGNMENT: %s, %s", L_expression_tostr[lval->a->kind],
            lval->a->u.s);
    if (!(var = L_get_symbol(lval->a, TRUE))) return;
    if (lval->indices) {
        /* we have array indices */
        int index_count = 0;
        L_expression *i;
        for (i = lval->indices; i; i = i->indices, index_count++) {
            L_compile_expressions(i->a);
        }
        L_compile_expressions(rval);
        L_LOAD_SCALAR(var->localIndex);
        if (index_count == 1) {
            TclEmitOpcode(INST_LSET_LIST, lframe->envPtr);
        } else {
            TclEmitInstInt4(INST_LSET_FLAT, index_count + 2, lframe->envPtr);
        }
        /* store the modified array back in the variable */
        L_STORE_SCALAR(var->localIndex);
    } else {
        /* no array indices */
        L_compile_expressions(rval);
        L_STORE_SCALAR(var->localIndex);
    }
}

void 
L_compile_incdec(L_expression *expr)
{
    L_symbol *var;

    if (!(var = L_get_symbol(expr->a, TRUE))) return;
    if (expr->kind == L_EXPRESSION_PRE) {
        TclEmitInstInt1(INST_INCR_SCALAR1_IMM, var->localIndex,
                        lframe->envPtr);
        TclEmitInt1((expr->op == T_PLUSPLUS) ? 1 : -1, lframe->envPtr);
    } else {
        /* we push the value of the variable, do the increment, and then pop
           the result of the increment, leaving the old value on top. */
        L_push_variable(expr);
        TclEmitInstInt1(INST_INCR_SCALAR1_IMM, var->localIndex,
                        lframe->envPtr);
        TclEmitInt1((expr->op == T_PLUSPLUS) ? 1 : -1, lframe->envPtr);
        TclEmitOpcode(INST_POP, lframe->envPtr);
    }
}

/* Create a new symbol and add it to the current symbol table */
L_symbol *
L_make_symbol(
    L_expression *name,
    int base_type,
    L_ast_node *array_type,
    int localIndex)
{
    int new;
    L_symbol *symbol = (L_symbol *)ckalloc(sizeof(L_symbol));
    Tcl_HashEntry *hPtr = Tcl_CreateHashEntry(lframe->symtab, name->u.s, &new);
    if (!new) {
        L_errorf(name, "Duplicate definition of symbol %s", name->u.s);
    }
    symbol->name = name->u.s;
/*     symbol->base_type = base_type; */
/*     symbol->array_type = array_type; */
    symbol->localIndex = localIndex;
    Tcl_SetHashValue(hPtr, symbol);
    return symbol;
    return (L_symbol*)0;
}

/* Look up a symbol in the current symbol table, return NULL and optionally
   emit an error if not found */
L_symbol *
L_get_symbol(L_expression *name, int error_p) 
{
    Tcl_HashEntry *hPtr = NULL; 
    L_compile_frame *frame;

    for (frame = lframe; !hPtr && frame; frame = frame->prevFrame) {
        hPtr = Tcl_FindHashEntry(frame->symtab, name->u.s);
    }
    if (hPtr) {
        return (L_symbol *)Tcl_GetHashValue(hPtr);
    } else {
        if (error_p) {
            L_errorf(name, "Undeclared variable: %s", name->u.s);
        }
        return NULL;
    }
}


/* maybeFixupEmptyCode() doesn't fix anything up right now, because we always
   emit code for the implicit return value.  But I guess that when we start
   creating global code again, we'll want it back.  --timjr 2006.5.11 */
/**
 * In case no bytecode was emitted, emit something, because
 * otherwise we'll get an error from TclExecuteByteCode.
 */
void
maybeFixupEmptyCode(L_compile_frame *frame)
{
    if (frame->envPtr->codeNext == frame->originalCodeNext) {
        TclEmitPush( TclAddLiteralObj(frame->envPtr, Tcl_NewObj(), NULL),
            frame->envPtr);
    }
}


/* Push and Pop the L_compile_frames. */

void 
L_frame_push(Tcl_Interp *interp, CompileEnv *envPtr) 
{
    L_compile_frame *new_frame = 
        (L_compile_frame *)ckalloc(sizeof(L_compile_frame));
    new_frame->interp = interp;
    new_frame->envPtr = envPtr;
    new_frame->symtab = (Tcl_HashTable *)ckalloc(sizeof(Tcl_HashTable));
    Tcl_InitHashTable(new_frame->symtab, TCL_STRING_KEYS);
    new_frame->prevFrame = lframe;
    lframe = new_frame;
}

void 
L_frame_pop() 
{
    L_compile_frame *prev = lframe->prevFrame;
    Tcl_HashEntry *hPtr;
    Tcl_HashSearch hSearch;

    /* free the symbol table */
    for (hPtr = Tcl_FirstHashEntry(lframe->symtab, &hSearch); hPtr != NULL;
         hPtr = Tcl_NextHashEntry(&hSearch)) {
        ckfree(Tcl_GetHashValue(hPtr));
    }
    Tcl_DeleteHashTable(lframe->symtab);
    ckfree((char *)lframe->symtab);
    /* now free the frame itself and update the global frame pointer */
    ckfree((char *)lframe);
    lframe = prev;
}

/* Give up the ghost. */
void 
L_bomb(const char *format, ...) 
{
    va_list ap;

    va_start(ap, format);
    fprintf(stderr, "L Internal Error: ");
    vfprintf(stderr, format, ap);
    va_end(ap);
    fprintf(stderr, "\n");
    exit(1);
}

/* Print L compiler debugging info. */
void 
L_trace(const char *format, ...) 
{
    va_list ap;

    va_start(ap, format);
    if (getenv("LTRACE")) {
        fprintf(stderr, "***: ");
        vfprintf(stderr, format, ap);
        fprintf(stderr, "\n");
    }
    va_end(ap);
    fflush(stderr);
}

/* L_error is yyerror */
void
L_error(char *s)
{
    if (!L_errors) {
        L_errors = Tcl_NewObj();
    }
    TclObjPrintf(NULL, L_errors, "L Error: %s on line %d\n", s, L_line_number);
}

/* Sometimes you feel like a char*, sometimes you don't. */
void
L_errorf(void *node, const char *format, ...)
{
    va_list ap;
    char *buf;

    va_start(ap, format);
    /* this would be nice, but it's not exported functionality: */
    /* ObjPrintfVA(NULL, L_errors, format, ap); */
    /* GNU also has a nice memory allocating sprintf function we might be able
       to use: */
    /* #ifdef _GNU_SOURCE */
    /*     vasprintf(&buf, format, ap); */
    /*     L_error(buf); */
    /*     free(buf); */
#define TYPICAL_ARBITRARY_CONSTANT 1024
    buf = ckalloc(TYPICAL_ARBITRARY_CONSTANT);
    vsnprintf(buf, TYPICAL_ARBITRARY_CONSTANT, format, ap);
    va_end(ap);
    if (!L_errors) {
        L_errors = Tcl_NewObj();
    }
    TclObjPrintf(NULL, L_errors, "L Error: %s on line %d\n", buf,
                 ((L_ast_node *)node)->line_no);
    ckfree(buf);
}

static void 
L_free_ast(L_ast_node *ast) {
    while(ast_trace_root) {
        L_ast_node *node = ast_trace_root;
        ast_trace_root = ast_trace_root->_trace;
        if (node->type == L_NODE_EXPRESSION &&
            ((L_expression *)node)->kind == L_EXPRESSION_STRING) {
            ckfree(((L_expression *)node)->u.s);
        }
        ckfree((char *)node);
    }
    ast_trace_root = NULL;
}

/*
 * Local Variables:
 * mode: c
 * c-basic-offset: 4
 * fill-column: 78
 * End:
 */


