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
    CompileEnv	*compEnv;
    /* The "original code next" is where we save the compEnv->codeNext
     * pointer so we can check if any code was emitted in this frame.
     * Yikk.  --timjr 2006.2.23 */
    unsigned char *originalCodeNext;
    struct L_compile_frame *prevFrame;
} L_compile_frame;

void LCompileScript(Tcl_Interp *interp, CONST char *str, int numBytes, 
                    CompileEnv *envPtr);
void L_assignment(ltoken *lvalue, ltoken *rvalue);
void L_begin_function_decl(ltoken *name);
void L_end_function_decl(ltoken *name);
void L_begin_function_call(ltoken *name);
void L_end_function_call(ltoken *name, int param_count);
void L_pass_parameter(ltoken *parameter);
void maybeFixupEmptyCode(L_compile_frame *frame);
void L_frame_push(Tcl_Interp *interp, CompileEnv *compEnv);
void L_frame_pop();
void L_bomb(const char *msg);

#endif /* L_COMPILE_H */
