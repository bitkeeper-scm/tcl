#ifndef L_COMPILE_H
#define L_COMPILE_H

#include "tclInt.h"
#include "tclCompile.h"
#include "Ltokens.h"

/**
 * An L_compile_frame is just a stack that lets the semantic actions
 * track state as the parser does its thing.
 */
typedef struct L_compile_frame {
    Tcl_Interp	*interp;
    CompileEnv	*envPtr;
    /* The "original code next" is where we save the compEnv->codeNext
     * pointer so we can check if any code was emitted in this frame.
     * Yikk.  --timjr 2006.2.23 */
    unsigned char *originalCodeNext;
    /* If statement relocs. */
    JumpFixupArray *jumpFalseFixupArrayPtr;
    struct L_compile_frame *prevFrame;
} L_compile_frame;

void LCompileScript(Tcl_Interp *interp, CONST char *str, int numBytes, 
                    CompileEnv *envPtr);
void L_assignment(ltoken *lvalue, ltoken *rvalue);
void L_begin_function_decl(ltoken *name);
void L_end_function_decl(ltoken *name);
void L_begin_function_call(ltoken *name);
void L_end_function_call(ltoken *name, int param_count);
void L_if_condition();
void L_if_end();
void L_pass_parameter(ltoken *parameter);
void L_lhs_assignment(ltoken *rvalue);
void L_rhs_assignment(ltoken *rvalue);
/* void L_end_stmt(); */
void L_push_str(ltoken *str);
void L_push_int(ltoken *i);
void L_push_id(ltoken *id);
void maybeFixupEmptyCode(L_compile_frame *frame);
void L_frame_push(Tcl_Interp *interp, CompileEnv *compEnv);
void L_frame_pop();
void L_bomb(const char *msg);

#endif /* L_COMPILE_H */

/*
 * Local Variables:
 * mode: c
 * c-basic-offset: 4
 * fill-column: 78
 * End:
 */
