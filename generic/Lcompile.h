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

typedef enum L_operator_name {
    L_OP_PLUS,
    L_OP_MINUS,
    L_OP_MULTIPLY,
    L_OP_DIVIDE,
    L_OP_MODULUS
} L_operator_name;

/**
 * An L_compile_frame is just a stack that lets the semantic actions
 * track state as the parser does its thing.
 */
typedef struct L_compile_frame {
    Tcl_Interp	*interp;
    CompileEnv	*envPtr;
    Tcl_HashTable *symtab;
    /* The "original code next" is where we save the compEnv->codeNext
     * pointer so we can check if any code was emitted in this frame.
     * Yikk.  --timjr 2006.2.23 */
    unsigned char *originalCodeNext;
    /* Jump fixups allow you to conveniently set the target of a jump that has
       been previously emitted. */
    JumpFixupArray *jumpFixupArrayPtr;
    struct L_compile_frame *prevFrame;
} L_compile_frame;

int LCompileScript(Tcl_Interp *interp, CONST char *str, int numBytes, 
                    CompileEnv *envPtr);
/* void L_assignment(L_node *lvalue, L_node *rvalue); */
void L_begin_function_decl(L_node *name);
void L_end_function_decl(L_node *name);
void L_begin_function_call(L_node *name);
void L_end_function_call(L_node *name, int param_count);
void L_if_condition(int unless_p);
void L_if_end(int elseClause);
void L_if_alternative_end();
void L_if_consequent_end();
void L_op_post_incdec(L_node *lvalue, char op);
void L_op_pre_incdec(L_node *lvalue, char op);
/* void L_lhs_assignment(L_node *rvalue); */
/* void L_rhs_assignment(L_node *rvalue); */
void L_assignment(L_node *rvalue);
void L_op_binop(L_operator_name op);
/* void L_push_str(L_node *str); */
/* void L_push_int(L_node *i); */
void L_push_literal(L_node *literal);
void L_push_id(L_node *id);
void L_return(int value_on_stack_p);
void maybeFixupEmptyCode(L_compile_frame *frame);
void L_frame_push(Tcl_Interp *interp, CompileEnv *compEnv);
void L_frame_pop();
void L_bomb(const char *format, ...);
void L_trace(const char *format, ...);
void L_errorf(const char *format, ...);
void L_declare_variable(L_node *name, int base_type, int initialize_p);
void L_declare_parameter(L_node *name, int base_type);
L_symbol *L_get_symbol(char *name, int error_p);
L_symbol *L_make_symbol(char *name, int base_type, L_node *array_type, int localIndex);


/* L_error is yyerror (for parse errors) */
void L_error(char *s);

/* L_parse is generated by yacc... not sure where the prototype is
   actually meant to be found. --timjr 2006.2.23  */
int L_parse(void);

/* This is the type that Yacc will use for all semantic values. */ 
#define YYSTYPE L_node *


#endif /* L_COMPILE_H */

/*
 * Local Variables:
 * mode: c
 * c-basic-offset: 4
 * fill-column: 78
 * End:
 */
