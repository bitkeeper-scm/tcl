/*
 * Copyright (c) 2006-2007 BitMover, Inc.
 */
#ifndef L_COMPILE_H
#define L_COMPILE_H

#include "tclInt.h"
#include "tclCompile.h"
#include "Last.h"

#ifndef TRUE
#define TRUE 1
#endif
#ifndef FALSE
#define FALSE 0
#endif

/* A linked list of jump fixups. */
typedef struct Jumps Jumps;
struct Jumps {
	int	offset;		/* the code offset of the jump instruction */
	Jumps	*next;		/* the next offset in the list */
};

/*
 * An L_compile_frame is just a stack that lets the semantic actions
 * track state as the parser does its thing.
 */
typedef struct L_compile_frame {
	Tcl_Interp	*interp;
	CompileEnv	*envPtr;
	Tcl_HashTable	*symtab;

	// When a compile frame corresponds to a block in the code, we
	// store the AST node of the block here.
	Ast		*block;

	// The "original code next" is where we save the compEnv->codeNext
	// pointer so we can check if any code was emitted in this frame.
	// Yikk.  --timjr 2006.2.23
	unsigned char	*originalCodeNext;

	// We collect JumpFixups for all of the jumps emitted for break and
	// continue statements, so that we can stuff in the correct jump targets
	// once we're done compiling the loops.
	Jumps		*continue_jumps;
	Jumps		*break_jumps;
	int		toplevel_p;	// FALSE unless frame is toplevel. 
	int		options;	// A combination of L_OPT_* flags or 0
	struct L_compile_frame *prevFrame;
} L_compile_frame;

/* L options, stored in the options field of the L_compile_frame. */
#define L_OPT_POLY	(1 << 0) /* Typecheck disabled, no need to declare
				  * variables */
#define L_OPT_NOWARN	(1 << 1) /* Warnings disabled. */

/* L_symbols are used to represent variables. */
typedef struct L_symbol {
	char	*name;
	L_type	*type;
	int	localIndex;
	int	global_p;
	int	used_p;
	Ast	*node;
} L_symbol;

void	L_bomb(const char *format, ...);
void	L_trace(const char *format, ...);
void	L_warning(char *s);
void	L_warningf(void *node, const char *format, ...);
void	L_errorf(void *node, const char *format, ...);
L_symbol *L_get_symbol(L_expr *name, int error_p);
L_type	*L_lookup_typedef(L_expr *name, int error_p);
void	L_store_typedef(L_expr *name, L_type *type);
int	L_lookup_pattern_func(char *name, L_expr **newName, L_expr **firstArg);
void	L_pattern_store_name(L_expr *name);
L_var_decl *L_get_struct_member(L_type *t, L_expr *index, int *memberOffset);
char	*ckstrdup(const char *str);
char	*ckstrndup(const char *str, int len);

/* L_error is yyerror (for parse errors) */
void	L_error(const char *s);

/* in Ltypecheck.c */
void	L_check_expr_kind(L_type_kind want, L_expr *expr);
void	L_check_expr_type(L_type *want, L_expr *expr);
void	L_check_type(L_type *want, L_type *have, L_expr *expr);
void	L_check_arg_type(char *funcname, int pos, L_expr *expr);
void	L_check_arg_count(char *funcname, int count, L_expr *expr);
void	L_store_fun_type(L_function_decl *fun);
void	L_finish_typechecks();
L_type	*L_expr_type(L_expr *expr);
int	L_expr_is_void(L_expr *expr);

/* L_parse is generated by yacc... not sure where the prototype is
   actually meant to be found. --timjr 2006.2.23  */
int	L_parse(void);

void	L_start_lexer(void);

/* A special value that marks a pointer as having no offset.  */
#define LPOINTER_NO_OFFSET -1


/* This is the type that Yacc will use for all semantic values. */
#define YYSTYPE void *

/* AST convenience macros */
#define MK_STRING_NODE(var,str) do {\
    var = mk_expr(L_EXPR_STRING, -1, NULL, NULL, NULL, NULL, NULL);\
    ((L_expr *)var)->u.string = ckalloc(strlen(str) + 1);\
    strcpy(((L_expr *)var)->u.string, str);\
} while(0);

#define MK_INT_NODE(var,int) do {\
    var = mk_expr(L_EXPR_INTEGER, -1, NULL,NULL, NULL, NULL, NULL);\
    ((L_expr *)var)->u.integer = int;\
} while(0);

#define MK_FLOAT_NODE(var,float) do {\
    var = mk_expr(L_EXPR_FLOTE, -1, NULL, NULL, NULL, NULL, NULL);\
    ((L_expr *)var)->u.flote = float;\
} while(0);

#define MK_BINOP_NODE(var,op,e1,e2) do {\
    var = mk_expr(L_EXPR_BINARY, op, e1, e2, NULL, NULL, NULL);\
} while(0);

#define L_NODE_TYPE(node) ((Ast*)node)->node_type


/* REVERSE() assumes that node is a singly linked list of type type with
   forward pointers named ptr.  The last element in the list becomes the
   first and is stored back into node. */
#define REVERSE(type,ptr,node) { \
    type *a, *b, *c; \
    for (a = NULL, b = node, c = (node ? ((type *)node)->ptr : NULL); \
	 b != NULL; \
	 b->ptr = a, a = b, b = c, c = (c ? c->ptr : NULL)); \
    *(type **)&(node) = a; \
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
#define L_PUSH_STR(str) \
    TclEmitPush(TclRegisterNewLiteral(lframe->envPtr, (str), \
	    strlen(str)), lframe->envPtr)

#define L_PUSH_CSTR(str, len) \
    TclEmitPush(TclRegisterNewLiteral(lframe->envPtr, (str), (len)), \
		lframe->envPtr)

/* Emit code to push a Tcl_Obj on the stack, guarding against leaks if it has
 * 0 refCount. This sidesteps the literal sharing mechanism. */

#define L_PUSH_OBJ(objPtr) {			\
    Tcl_Obj	*newPtr = objPtr;\
    Tcl_IncrRefCount(newPtr);\
    TclEmitPush(TclAddLiteralObj(lframe->envPtr, newPtr,NULL), lframe->envPtr);\
    Tcl_DecrRefCount(newPtr);\
}

#define L_INVOKE(size0) {\
    int	size = (size0);\
    if ((size) < 256) {\
	TclEmitInstInt1(INST_INVOKE_STK1, (size), lframe->envPtr);\
    } else {\
	TclEmitInstInt4(INST_INVOKE_STK4, (size), lframe->envPtr);\
    }\
}

#define L_POP()	TclEmitOpcode(INST_POP, lframe->envPtr)


/*
 * A special function to handle deep structs/arrays/hashes in L. This function
 * is called from TclExecuteByteCode (INST_L_DEEP).
 */

#define L_FIRST_IS_HASH   1
#define L_DEEP_WRITE      2
#define L_DEEP_CREATE     4

/*
 * An L-specific type to represent the undefined value of array, hash,
 * or struct members when they dynamically are brought into life by an
 * array auto-extend.  We create one object of this type and dup it
 * as the value of all undefined objects.
 */
Tcl_ObjType L_UndefType;

MODULE_SCOPE Tcl_ObjType LdeepPtrType;
MODULE_SCOPE Tcl_Obj ** L_DeepDiveIntoStruct(Tcl_Interp *interp,
	Tcl_Obj *valuePtr, Tcl_Obj **idxPtr, Tcl_Obj *countPtr, int flags);

#endif /* L_COMPILE_H */
