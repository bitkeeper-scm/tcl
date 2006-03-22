#include <stdio.h>
#include "tclInt.h"
#include "Lcompile.h"
#include "Ltokens.h"

static L_compile_frame *lframe = NULL;
char *L_parse_errors = NULL;
int L_line_number = 0;

int 
L_PragmaObjCmd(
    ClientData clientData,
    Tcl_Interp *interp, 
    int objc,
    Tcl_Obj *CONST objv[])
{ 
    int stringLen; 
    char *stringPtr;

    if (objc != 2) {
        L_bomb("Assertion failed in L_PragmaObjCmd: we expected only 1 argument but got %d.",
               objc - 1);
    }
    stringPtr = Tcl_GetStringFromObj(objv [1], &stringLen);
    return LCompileScript(interp, stringPtr, stringLen, NULL);
}

/* LCompileScript() is the main entry point into the land of L. */
int
LCompileScript(
    Tcl_Interp *interp,
    CONST char *str,
    int numBytes,
    CompileEnv *envPtr)
{
    int parseError;
    void    *lex_buffer = (void *)L__scan_bytes(str, numBytes);

    L_line_number = 1;

    L_frame_push(interp, envPtr);
    if (envPtr)
        lframe->originalCodeNext = envPtr->codeNext;
    parseError = L_parse();
    L__delete_buffer(lex_buffer);
    if (envPtr)
        maybeFixupEmptyCode(lframe);
    L_frame_pop();

    /* In case there was a parse error, store the error in interp and return
       TCL_ERROR. */
    if (parseError) {
        Tcl_Obj *result  = Tcl_NewObj();
        /* I would like to just set interp->errorLine, but that doesn't work
           for some reason. --timjr 2006.3.15 */
        TclObjPrintf(interp, result, "L Error: %s on line %d", 
                     L_parse_errors, L_line_number);
        Tcl_SetObjResult(interp, result);
        ckfree(L_parse_errors);
        return TCL_ERROR;
    }
    return TCL_OK;
}

/**
 * These next functions are the bulk of the parser's semantic actions.
 * Right now they attempt to compile straight to bytecode.  We may
 * want to first generate an AST so we can chew on it a little harder,
 * and don't have to mess with global variables.
 */

void 
L_begin_function_decl(ltoken *name) 
{
    CompileEnv *envPtr;

    envPtr = (CompileEnv *)ckalloc(sizeof(CompileEnv));
    L_frame_push(lframe->interp, envPtr);
    TclInitCompileEnv(lframe->interp, envPtr, "L Compiler", 
                      strlen("L Compiler"));
    lframe->originalCodeNext = envPtr->codeNext;
    TclEmitPush( TclAddLiteralObj(lframe->envPtr, Tcl_NewObj(), NULL),
                 lframe->envPtr);
}

void 
L_end_function_decl(ltoken *name) 
{
    Interp *iPtr = (Interp *)lframe->interp;
    Proc *procPtr;
    Tcl_Obj *bodyObjPtr;
    Tcl_Command cmd;

    procPtr = (Proc *) ckalloc(sizeof(Proc));
    procPtr->iPtr = iPtr;
    procPtr->refCount = 1;
    procPtr->bodyPtr = Tcl_NewObj();
    procPtr->numArgs  = 0;
    procPtr->numCompiledLocals = 0;
    procPtr->firstLocalPtr = NULL;
    procPtr->lastLocalPtr = NULL;

    TclEmitOpcode(INST_DONE, lframe->envPtr);

    TclInitByteCodeObj(procPtr->bodyPtr, lframe->envPtr);
    bodyObjPtr = TclNewProcBodyObj(procPtr);
    if (bodyObjPtr == NULL) {
        L_bomb("failed to create a ProcBodyObj for some reason");
    }
    Tcl_IncrRefCount(bodyObjPtr);

    cmd = Tcl_CreateObjCommand(lframe->interp, name->v.s,
        TclObjInterpProc, (ClientData) procPtr, TclProcDeleteProc);
    procPtr->cmdPtr = (Command *) cmd;

    TclFreeCompileEnv(lframe->envPtr);
    L_frame_pop();
}


void 
L_begin_function_call(ltoken *name) 
{
    TclEmitPush(TclRegisterNewLiteral(lframe->envPtr, name->v.s, 
                                      strlen(name->v.s)), 
                lframe->envPtr);
}

void 
L_end_function_call(ltoken *name, int param_count) 
{
    TclEmitInstInt4(INST_INVOKE_STK4, param_count+1, lframe->envPtr);
}


#define JUMP_IF_FALSE_INDEX 0
#define JUMP_IF_END_INDEX 1

void 
L_if_condition() 
{
/*     int jumpIndex; */
    JumpFixupArray *jumpFalsePtr;

    jumpFalsePtr = (JumpFixupArray *)ckalloc(sizeof(JumpFixupArray));
    /* save the fixup array in a compile frame so that we can do the fixups at
       the end of this if statement. */
    L_frame_push(lframe->interp, lframe->envPtr);
    lframe->jumpFalseFixupArrayPtr = jumpFalsePtr;

    TclInitJumpFixupArray(jumpFalsePtr);
    /* allocate space for two jump fixups, one for the skipping the consequent
       and one for skipping the alternate. */
/*     if ((jumpFalsePtr->next + 2) >= jumpFalsePtr->end) { */
    if (2 >= jumpFalsePtr->end) {
        TclExpandJumpFixupArray(jumpFalsePtr);
    }
/*     jumpIndex = jumpFalsePtr->next; */
/*     jumpFalsePtr->next++; */
    jumpFalsePtr->next += 2;
    TclEmitForwardJump(lframe->envPtr, TCL_FALSE_JUMP, 
                       jumpFalsePtr->fixup + JUMP_IF_FALSE_INDEX);
}

void 
L_if_statements_end(int finalBlock) 
{
    if (finalBlock) {
        TclEmitForwardJump(lframe->envPtr, TCL_UNCONDITIONAL_JUMP,
                           lframe->jumpFalseFixupArrayPtr->fixup + JUMP_IF_END_INDEX);
        
        

/*     fprintf(stderr, "fixing up false jump\n"); */
        if (TclFixupForwardJumpToHere(lframe->envPtr,
                                      lframe->jumpFalseFixupArrayPtr->fixup + JUMP_IF_FALSE_INDEX,
                                      127))
            {
            }
    }
    /* if we're ending the final block of the if, there's no else clause to
       jump over. */ 
        
/*         TclFreeJumpFixupArray(lframe->jumpFalseFixupArrayPtr); */
/*         ckfree(lframe->jumpFalseFixupArrayPtr); */
/*         L_frame_pop(); */
/*     } */
}

void 
L_if_end(int elseClause) 
{
/*     fprintf(stderr, "also fixing up false jump\n"); */
    if (elseClause) {
        TclFixupForwardJumpToHere(lframe->envPtr,
                                  /* this should actually be more like:
                                     lframe->jumpFalseFixupArrayPtr->fixup+jumpIndex,  */
                                  lframe->jumpFalseFixupArrayPtr->fixup + JUMP_IF_END_INDEX,
                                  127);
    } else {
        TclFixupForwardJumpToHere(lframe->envPtr,
                                  /* this should actually be more like:
                                     lframe->jumpFalseFixupArrayPtr->fixup+jumpIndex,  */
                                  lframe->jumpFalseFixupArrayPtr->fixup + JUMP_IF_FALSE_INDEX,
                                  127);
    }


    TclFreeJumpFixupArray(lframe->jumpFalseFixupArrayPtr);
    ckfree((char *)lframe->jumpFalseFixupArrayPtr);
    L_frame_pop();
}

void
L_push_str(ltoken *str)
{
    TclEmitPush(TclRegisterNewNSLiteral(lframe->envPtr, 
                                        str->v.s, strlen(str->v.s)), 
                lframe->envPtr);
}

void
L_push_int(ltoken *i)
{
    TclEmitPush(TclAddLiteralObj(lframe->envPtr, 
                                 Tcl_NewIntObj(i->v.i), NULL), 
                lframe->envPtr);
}

void
L_push_id(ltoken *id)
{
    TclEmitPush(TclRegisterNewNSLiteral(lframe->envPtr, 
                                        id->v.s, strlen(id->v.s)), 
                lframe->envPtr);
    TclEmitOpcode(INST_LOAD_SCALAR_STK, lframe->envPtr);
}

void 
L_pass_parameter(ltoken *parameter) 
{
}

void
L_lhs_assignment(ltoken *lvalue)
{
    TclEmitPush(TclRegisterNewNSLiteral(lframe->envPtr, lvalue->v.s,
                                        strlen(lvalue->v.s)), 
                lframe->envPtr);
}

void
L_rhs_assignment(ltoken *rvalue)
{
    TclEmitOpcode(INST_STORE_SCALAR_STK, lframe->envPtr);
}

/* void */
/* L_end_stmt() { */
/*     TclEmitOpcode(INST_POP, lframe->envPtr); */
/* } */

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
    L_compile_frame *new_frame = (L_compile_frame *)ckalloc(sizeof(L_compile_frame));
    new_frame->interp = interp;
    new_frame->envPtr = envPtr;
    new_frame->prevFrame = lframe;
    lframe = new_frame;
}

void 
L_frame_pop() 
{
    L_compile_frame *prev = lframe->prevFrame;
    ckfree((char *)lframe);
    lframe = prev;
}

/* Give up the ghost. */
void 
L_bomb(const char *format, ...) 
{
    va_list va;

    va_start(va, format);
    vfprintf(stderr, format, va);
    va_end(va);
    fprintf(stderr, "\n");
    exit(1);
}

/* L_error is yyerror */
void
L_error(char *s)
{
    int len = strlen(s) + 1;

    if (L_parse_errors != NULL) {
        L_bomb("L_error is only able to report one parse error at a time");
    } else {
        L_parse_errors = ckalloc(len); 
        strncpy(L_parse_errors, s, len);
    }
}


/*
 * Local Variables:
 * mode: c
 * c-basic-offset: 4
 * fill-column: 78
 * End:
 */


