#ifndef L_COMPILE_H
#define L_COMPILE_H

#include "tclInt.h"
#include "tclCompile.h"
#include "Last.h"

#ifndef TRUE
#define TRUE 1
#endif /* TRUE */
#ifndef FALSE
#define FALSE 0
#endif /* FALSE */

/* A linked list of jump fixups. */
typedef struct JumpOffsetList {
    int offset;			/* the code offset of the jump instruction */
    struct JumpOffsetList *next; /* the next offset in the list */
} JumpOffsetList;

/**
 * An L_compile_frame is just a stack that lets the semantic actions
 * track state as the parser does its thing.
 */
typedef struct L_compile_frame {
    Tcl_Interp	*interp;
    CompileEnv	*envPtr;
    Tcl_HashTable *symtab;
    /* When a compile frame corresponds to a block in the code, we store the
       AST node of the block here. */
    L_ast_node *block;
    /* The "original code next" is where we save the compEnv->codeNext
     * pointer so we can check if any code was emitted in this frame.
     * Yikk.  --timjr 2006.2.23 */
    unsigned char *originalCodeNext;
    /* We collect JumpFixups for all of the jumps emitted for break and
       continue statements, so that we can stuff in the correct jump targets
       once we're done compiling the loops. */
    JumpOffsetList *continue_jumps;
    JumpOffsetList *break_jumps;
    struct L_compile_frame *prevFrame;
} L_compile_frame;

/* L_symbols are used to represent variables. */
typedef struct L_symbol {
    char *name;
    L_type *type;
    int localIndex;
    int global_p;
} L_symbol;


int LCompileScript(Tcl_Interp *interp, CONST char *str, int numBytes, 
                    CompileEnv *envPtr, void *ast);
int LParseScript(Tcl_Interp *interp, CONST char *str, int numBytes, L_ast_node **ast);
void L_push_variable(L_expression *name);
void L_return(int value_on_stack_p);
void maybeFixupEmptyCode(L_compile_frame *frame);
void L_frame_push(Tcl_Interp *interp, CompileEnv *compEnv, void *block);
void L_frame_pop();
void L_bomb(const char *format, ...);
void L_trace(const char *format, ...);
void L_errorf(void *node, const char *format, ...);
L_symbol *L_get_symbol(L_expression *name, int error_p);
L_symbol *L_make_symbol(L_expression *name, L_type *type, int localIndex);
void L_compile_toplevel_statements(L_toplevel_statement *stmt);
void L_compile_function_decl(L_function_declaration *fun);
void L_compile_struct_decl(L_type *decl);
void L_compile_variable_decls(L_variable_declaration *var);
void L_compile_statements(L_statement *stmt);
void L_compile_parameters(L_variable_declaration *param);
void L_compile_expressions(L_expression *expr);
void L_compile_if_unless(L_if_unless *cond);
void L_compile_block(L_block *body);
void L_compile_assignment(L_expression *lvalue);
void L_compile_binop(L_expression *expr);
void L_compile_incdec(L_expression *expr);
void L_compile_unop(L_expression *expr);
void L_compile_short_circuit_op(L_expression *expr);
void L_compile_loop(L_loop *loop);
void L_compile_foreach_loop(L_foreach_loop *loop);
L_type *L_compile_index(L_type *index_type, L_expression *index);
void L_compile_twiddle(L_expression *expr);
void L_compile_interpolated_string(L_expression *expr);
void L_compile_global_decls(L_variable_declaration *decl);
L_type *L_lookup_typedef(L_expression *name, int error_p);
void L_store_typedef(L_expression *name, L_type *type);
void L_compile_defined(L_expression *lval);
void L_compile_break(L_statement *stmt);
void L_compile_continue(L_statement *stmt);


/* in LPointerObj.c */
Tcl_Obj *L_NewPointerObj(int callFrame, CONST char *varName,
                         int offset, Tcl_Interp *interp);

/* L_error is yyerror (for parse errors) */
void L_error(char *s);

/* L_parse is generated by yacc... not sure where the prototype is
   actually meant to be found. --timjr 2006.2.23  */
int L_parse(void);

void L_start_lexer();

/* A special value that marks a pointer as having no offset.  */
#define LPOINTER_NO_OFFSET -1


/* This is the type that Yacc will use for all semantic values. */
#define YYSTYPE void *

/* AST convenience macros */
#define MK_STRING_NODE(var,str) do {\
        var = mk_expression(L_EXPRESSION_STRING, -1, NULL, NULL, NULL, NULL, NULL);\
        ((L_expression *)var)->u.string = ckalloc(strlen(str) + 1);\
        strcpy(((L_expression *)var)->u.string, str);\
} while(0);

#define MK_INT_NODE(var,int) do {\
        var = mk_expression(L_EXPRESSION_INTEGER, -1, NULL, NULL, NULL, NULL, NULL);\
        ((L_expression *)var)->u.integer = int;\
} while(0);

#define MK_FLOAT_NODE(var,float) do {\
        var = mk_expression(L_EXPRESSION_FLOTE, -1, NULL, NULL, NULL, NULL, NULL);\
        ((L_expression *)var)->u.flote = float;\
} while(0);

#define MK_BINOP_NODE(var,op,e1,e2) do {\
        var = mk_expression(L_EXPRESSION_BINARY, op, e1, e2, NULL, NULL, NULL);\
} while(0);

#define L_NODE_TYPE(node) ((L_ast_node*)node)->node_type


/* REVERSE() assumes that node is a singly linked list of type type with
   forward pointers named ptr.  The last element in the list becomes the
   first and is stored back into node. */
#define REVERSE(type,ptr,node) { \
    type *a, *b, *c; \
    for (a = NULL, b = node, c = (node ? ((type *)node)->ptr : NULL); \
         b != NULL; \
         b->ptr = a, a = b, b = c, c = (c ? c->ptr : NULL)); \
    node = a; \
}

/* APPEND() starts at a, walks ptr until the end, and then attaches b to a.
   (Note that it's actually NCONC). */
#define APPEND(type,ptr,a,b) { \
    type *runner; \
    for (runner = a; runner->ptr; runner = runner->ptr); \
    runner->ptr = b; \
}

/* Emit the load or store instruction with appropriate operand size. */
#define L_STORE_SCALAR(index) {\
    int idx = index;\
    if (idx <= 255) {\
        TclEmitInstInt1(INST_STORE_SCALAR1, idx, lframe->envPtr);\
    } else {\
        TclEmitInstInt4(INST_STORE_SCALAR4, idx, lframe->envPtr);\
    }\
}

#define L_LOAD_SCALAR(index) {\
    int idx = index;\
    if (idx <= 255) {\
        TclEmitInstInt1(INST_LOAD_SCALAR1, idx, lframe->envPtr);\
    } else {\
        TclEmitInstInt4(INST_LOAD_SCALAR4, idx, lframe->envPtr);\
    }\
}

/* Emit code to push a literal string on the stack. */
#define L_PUSH_STR(str) {\
    TclEmitPush(TclRegisterNewLiteral(lframe->envPtr, str,\
                                      strlen(str)),\
                lframe->envPtr);\
}

/* Emit code to push a Tcl_Obj on the stack. */
#define L_PUSH_OBJ(obj) {\
    TclEmitPush(TclAddLiteralObj(lframe->envPtr, obj, NULL),\
                lframe->envPtr);\
}

#endif /* L_COMPILE_H */

/*
 * Local Variables:
 * mode: c
 * c-basic-offset: 4
 * fill-column: 78
 * End:
 */
