#include <stdio.h>
#include "tclInt.h"

#include "Lcompile.h"
#include "Ltokens.h"

static L_compile_frame *lframe = NULL;

/* LCompileScript() is the main entry point into the land of L. */
void
LCompileScript(
	Tcl_Interp *interp,
	CONST char *str,
	int numBytes,
	CompileEnv *compEnv
)
{
	void    *lex_buffer = (void *)L__scan_bytes(str, numBytes);

    L_frame_push(interp, compEnv);
    lframe->originalCodeNext = compEnv->codeNext;
	L_parse();        
	L__delete_buffer(lex_buffer);
    maybeFixupEmptyCode(lframe);
    L_frame_pop();
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
    CompileEnv *compEnv;

    compEnv = (CompileEnv *)ckalloc(sizeof(CompileEnv));
    L_frame_push(lframe->interp, compEnv);
    TclInitCompileEnv(lframe->interp, compEnv, "L Compiler", 
      strlen("L Compiler"));
    lframe->originalCodeNext = compEnv->codeNext;
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

    TclEmitPush( TclAddLiteralObj(lframe->compEnv, Tcl_NewObj(), NULL),
      lframe->compEnv);

    TclEmitOpcode(INST_DONE, lframe->compEnv);

    TclInitByteCodeObj(procPtr->bodyPtr, lframe->compEnv);
    bodyObjPtr = TclNewProcBodyObj(procPtr);
    if (bodyObjPtr == NULL) {
        L_bomb("failed to create a ProcBodyObj for some reason");
    }
    Tcl_IncrRefCount(bodyObjPtr);

    cmd = Tcl_CreateObjCommand(lframe->interp, name->v.s,
        TclObjInterpProc, (ClientData) procPtr, TclProcDeleteProc);
    procPtr->cmdPtr = (Command *) cmd;

    TclFreeCompileEnv(lframe->compEnv);
    L_frame_pop();
}


void 
L_begin_function_call(ltoken *name) 
{
    TclEmitPush(TclRegisterNewLiteral(lframe->compEnv, name->v.s, 
      strlen(name->v.s)), lframe->compEnv);
}

void 
L_end_function_call(ltoken *name, int param_count) 
{
    TclEmitInstInt4(INST_INVOKE_STK4, param_count+1, lframe->compEnv);
}

void
L_push_str(ltoken *str)
{
        TclEmitPush(TclRegisterNewNSLiteral(lframe->compEnv, 
          str->v.s, strlen(str->v.s)), lframe->compEnv);
}

void
L_push_int(ltoken *i)
{
        TclEmitPush(TclAddLiteralObj(lframe->compEnv, 
          Tcl_NewIntObj(i->v.i), NULL), lframe->compEnv);
}

void
L_push_id(ltoken *id)
{
	TclEmitPush(TclRegisterNewNSLiteral(lframe->compEnv, 
          id->v.s, strlen(id->v.s)), lframe->compEnv);
        TclEmitOpcode(INST_LOAD_SCALAR_STK, lframe->compEnv);
}

void 
L_pass_parameter(ltoken *parameter) 
{
}

void
L_lhs_assignment(ltoken *lvalue)
{
    TclEmitPush(TclRegisterNewNSLiteral(lframe->compEnv, lvalue->v.s,
      strlen(lvalue->v.s)), lframe->compEnv);
}

void
L_rhs_assignment(ltoken *rvalue)
{
    TclEmitOpcode(INST_STORE_SCALAR_STK, lframe->compEnv);
}

void
L_end_stmt() {
	TclEmitOpcode(INST_POP, lframe->compEnv);
}

/**
 * In case no bytecode was emitted, emit something, because
 * otherwise we'll get an error from TclExecuteByteCode.
 */
void 
maybeFixupEmptyCode(L_compile_frame *frame) 
{
    if (frame->compEnv->codeNext == frame->originalCodeNext) {
        TclEmitPush( TclAddLiteralObj(frame->compEnv, Tcl_NewObj(), NULL),
            frame->compEnv);
    }
}


/* Push and Pop the L_compile_frames. */

void 
L_frame_push(Tcl_Interp *interp, CompileEnv *compEnv) 
{
    L_compile_frame *new_frame = (L_compile_frame *)ckalloc(sizeof(L_compile_frame));
    new_frame->interp = interp;
    new_frame->compEnv = compEnv;
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
L_bomb(const char *msg) 
{
    fprintf(stderr, msg);
    fprintf(stderr, "\n");
    exit(1);
}
