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
    struct L_compile_frame *prevFrame;
} L_compile_frame;

/* L_symbols are used to represent variables. */
typedef struct L_symbol {
    char *name;
    L_type *type;
    int localIndex;
} L_symbol;


int LCompileScript(Tcl_Interp *interp, CONST char *str, int numBytes, 
                    CompileEnv *envPtr, void *ast);
int LParseScript(Tcl_Interp *interp, CONST char *str, int numBytes, L_ast_node **ast);
void L_push_variable(L_expression *name);
void L_return(int value_on_stack_p);
void maybeFixupEmptyCode(L_compile_frame *frame);
void L_frame_push(Tcl_Interp *interp, CompileEnv *compEnv);
void L_frame_pop();
void L_bomb(const char *format, ...);
void L_trace(const char *format, ...);
void L_errorf(void *node, const char *format, ...);
L_symbol *L_get_symbol(L_expression *name, int error_p);
L_symbol *L_make_symbol(L_expression *name, int base_type, L_ast_node *array_type, int localIndex);
void L_compile_function_decls(L_function_declaration *fun);
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

/* L_error is yyerror (for parse errors) */
void L_error(char *s);

/* L_parse is generated by yacc... not sure where the prototype is
   actually meant to be found. --timjr 2006.2.23  */
int L_parse(void);

/* This is the type that Yacc will use for all semantic values. */ 
#define YYSTYPE void *

/* AST convenience macros */
#define MK_STRING_NODE(var,str) do {\
        var = mk_expression(L_EXPRESSION_STRING, -1, NULL, NULL, NULL, NULL, NULL);\
        ((L_expression *)var)->u.s = ckalloc(strlen(str) + 1);\
        strcpy(((L_expression *)var)->u.s, str);\
} while(0);

#define MK_INT_NODE(var,int) do {\
        var = mk_expression(L_EXPRESSION_INT, -1, NULL, NULL, NULL, NULL, NULL);\
        ((L_expression *)var)->u.i = int;\
} while(0);

#define MK_DOUBLE_NODE(var,double) do {\
        var = mk_expression(L_EXPRESSION_DOUBLE, -1, NULL, NULL, NULL, NULL, NULL);\
        ((L_expression *)var)->u.d = double;\
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


#endif /* L_COMPILE_H */

/*
 * Local Variables:
 * mode: c
 * c-basic-offset: 4
 * fill-column: 78
 * End:
 */
