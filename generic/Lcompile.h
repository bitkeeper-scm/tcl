/*
 * Copyright (c) 2006-2008 BitMover, Inc.
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

/* L options, stored in the options field of the Frame. */
typedef enum {
	L_OPT_POLY	= 0x0001,
	L_OPT_NOWARN	= 0x0002,
} Lopt_f;

/* For jump fix-ups. */
typedef struct Jmp Jmp;
struct Jmp {
	int	op;	// jmp instruction bytecode (e.g., INST_JUMP1)
	int	size;	// size of jmp instruction (1 or 4 bytes)
	int	offset;	// bytecode offset of jmp instruction
	Jmp	*next;
};

/* Semantic stack frame. */
typedef struct Frame {
	Tcl_Interp	*interp;
	CompileEnv	*envPtr;
	Tcl_HashTable	*symtab;

	// When a compile frame corresponds to a block in the code, we
	// store the AST node of the block here.
	Ast		*block;

	// We collect jump fix-ups for all of the jumps emitted for break and
	// continue statements, so that we can stuff in the correct jump targets
	// once we're done compiling the loops.
	Jmp		*continue_jumps;
	Jmp		*break_jumps;
	int		outer_p;	// True if frame is outer-most.
	int		toplevel_p;	// True if frame is for top levels.
	Lopt_f		options;
	struct Frame	*prevFrame;
} Frame;

/* Per-scope tables. Scopes are opened and close at parse time. */
typedef struct scope Scope;
struct scope {
	Tcl_HashTable	*structs;
	Tcl_HashTable	*typedefs;
	Scope		*prev;
};

/*
 * Per-interp L global state.  When an interp is created, one of these
 * is allocated for each interp and associated with the interp.
 * Whenever the compiler is entered, it is extracted from the interp.
 */
typedef struct {
	Frame	*frame;		// current semantic stack frame
	Scope	*curr_scope;
	Ast	*ast_list;	// list of all AST nodes
	Type	*type_list;	// list of all type descriptors
	void	*ast;		// ptr to AST root, set by parser
	Tcl_Obj	*errs;
	int	interactive;
	char	*file;
	int	line;
	int	prev_token_len;
	int	token_offset;	// offset of curr token from start of input
	char	*script;	// src of script being compiled
	int	script_len;
	FnDecl	*enclosing_func;
	Ast	*mains_ast;	// root of AST when main() last seen
	Tcl_HashTable	*include_table;
	Tcl_Interp	*interp;
} Lglobal;

/*
 * Symbol table entry, for variables and functions (typedef and struct
 * names have their own tables).  The tclname can be different from
 * the L name if we have to mangle the name as we do for L globals.
 * The decl pointer is used to get line# info for error messages.
 */
typedef enum {
	L_SYM_LVAR	= 0x0001,	// a local variable
	L_SYM_GVAR	= 0x0002,	// a global variable
	L_SYM_LSHADOW	= 0x0004,	// a global upvar shadow (these
					// are also locals)
	L_SYM_FN	= 0x0008,	// a function
	L_SYM_FNBODY	= 0x0010,	// function body has been declared
} Sym_k;
struct Sym {
	Sym_k	kind;
	char	*name;		// the L name
	char	*tclname;	// the tcl name (can be same as L name)
	Type	*type;
	int	idx;		// slot# for local var
	int	used_p;		// TRUE iff var has been referenced
	VarDecl	*decl;
};

/*
 * Flags for L deep-dive bytecodes.  Bits are used for simplicity even
 * though some of these are mutually exclusive.
 */
typedef enum {
	L_DEEP_HASH_FIRST = 0x01,
	L_DEEP_VAL        = 0x02,
	L_DEEP_PTR        = 0x04,
	L_DEEP_VAL_PTR    = 0x08,
	L_DEEP_PTR_VAL    = 0x10,
	L_DEEP_NEW        = 0x20,
	L_DEEP_OLD        = 0x40,
} Deep_f;

extern char	*ckstrdup(const char *str);
extern char	*ckstrndup(const char *str, int len);
extern void	L_bomb(const char *format, ...);
extern Tcl_Obj	**L_deepDive(Tcl_Interp *interp, Tcl_Obj *valuePtr,
			     Tcl_Obj **idxPtr, Tcl_Obj *countPtr, Deep_f flags);
extern void	L_err(const char *s, ...);	// yyerror
extern void	L_errf(void *node, const char *format, ...);
extern void	L_lex_begReArg();
extern void	L_lex_endReArg();
extern void	L_lex_start(void);
extern int	L_parse(void);			// yyparse
extern void	L_scope_enter();
extern void	L_scope_leave();
extern void	L_set_baseType(Type *type, Type *base_type);
extern void	L_set_declBaseType(VarDecl *decl, Type *base_type);
extern Tcl_Obj	*L_split(Tcl_Interp *interp, Tcl_Obj *strobj, Tcl_Obj *reobj,
			 Tcl_Obj *limobj);
extern Type	*L_struct_lookup(char *tag, int local);
extern Type	*L_struct_store(char *tag, VarDecl *members);
extern void	L_trace(const char *format, ...);
extern void	L_typeck_init();
extern void	L_typeck_assign(Expr *lhs, Expr *rhs);
extern int	L_typeck_compat(Type *lhs, Type *rhs);
extern void	L_typeck_deny(Type_k deny, Expr *expr);
extern void	L_typeck_expect(Type_k want, Expr *expr, char *msg);
extern void	L_typeck_fncall(VarDecl *formals, Expr *call);
extern int	L_typeck_same(Type *a, Type *b);
extern Type	*L_typedef_lookup(char *name);
extern void	L_typedef_store(VarDecl *decl);
extern void	L_warn(char *s);
extern void	L_warnf(void *node, const char *format, ...);

extern Lglobal	*L;
extern Tcl_ObjType L_undefType;
extern Tcl_ObjType L_deepPtrType;
extern Type	*L_int;
extern Type	*L_float;
extern Type	*L_string;
extern Type	*L_void;
extern Type	*L_var;
extern Type	*L_widget;
extern Type	*L_poly;

static inline int
isarray(Expr *expr)
{
	return (expr->type && (expr->type->kind == L_ARRAY));
}
static inline int
ishash(Expr *expr)
{
	return (expr->type && (expr->type->kind == L_HASH));
}
static inline int
isstruct(Expr *expr)
{
	return (expr->type && (expr->type->kind == L_STRUCT));
}
static inline int
isint(Expr *expr)
{
	return (expr->type && (expr->type->kind == L_INT));
}
static inline int
isfloat(Expr *expr)
{
	return (expr->type && (expr->type->kind == L_FLOAT));
}
static inline int
isstring(Expr *expr)
{
	return (expr->type && (expr->type->kind == L_STRING));
}
static inline int
isvoid(Expr *expr)
{
	return (expr->type && (expr->type->kind == L_VOID));
}
static inline int
ispoly(Expr *expr)
{
	return (expr->type && (expr->type->kind == L_POLY));
}
static inline int
isdeepdive(Expr *expr)
{
	return ((expr->kind == L_EXPR_BINOP) &&
		((expr->op == L_OP_ARRAY_INDEX) ||
		 (expr->op == L_OP_HASH_INDEX)  ||
		 (expr->op == L_OP_STRUCT_INDEX)));
}
static inline int
isscalar(Expr *expr)
{
	return (expr->type && (expr->type->kind & (L_INT |
						   L_FLOAT |
						   L_STRING |
						   L_WIDGET |
						   L_POLY)));
}
static inline int
islist(Expr *expr)
{
	return (expr->type && (expr->type->kind == L_LIST));
}
static inline int
isnameof(Expr *expr)
{
	return (expr->type && (expr->type->kind == L_NAMEOF));
}
static inline int
isfntype(Type *type)
{
	return (type->kind == L_FUNCTION);
}
static inline int
isvoidtype(Type *type)
{
	return (type->kind == L_VOID);
}
static inline void
emit_load_scalar(int idx)
{
	/*
	 * The next line is a hack so we can generate disassemblable
	 * code even in the presence of obscure compilation errors
	 * that cause the value of a function name to be attempted to
	 * be loaded.  Without this, tcl will die trying to output a
	 * disassembly since the local # (-1) would be invalid.
	 */
	if (idx == -1) idx = 0;

	if (idx <= 255) {
		TclEmitInstInt1(INST_LOAD_SCALAR1, idx, L->frame->envPtr);
	} else {
		TclEmitInstInt4(INST_LOAD_SCALAR4, idx, L->frame->envPtr);
	}
}
static inline void
emit_store_scalar(int idx)
{
	if (idx <= 255) {
		TclEmitInstInt1(INST_STORE_SCALAR1, idx, L->frame->envPtr);
	} else {
		TclEmitInstInt4(INST_STORE_SCALAR4, idx, L->frame->envPtr);
	}
}
static inline void
push_str(const char *str)
{
	TclEmitPush(TclRegisterNewLiteral(L->frame->envPtr, str, strlen(str)),
		    L->frame->envPtr);
}
static inline void
push_cstr(const char *str, int len)
{
	TclEmitPush(TclRegisterNewLiteral(L->frame->envPtr, str, len),
		    L->frame->envPtr);
}
static inline void
push_obj(Tcl_Obj *objPtr)
{
	Tcl_IncrRefCount(objPtr);
	TclEmitPush(TclAddLiteralObj(L->frame->envPtr, objPtr, NULL),
		    L->frame->envPtr);
	Tcl_DecrRefCount(objPtr);
}
static inline void
emit_invoke(int size)
{
	if (size < 256) {
		TclEmitInstInt1(INST_INVOKE_STK1, size, L->frame->envPtr);
	} else {
		TclEmitInstInt4(INST_INVOKE_STK4, size, L->frame->envPtr);
	}
}
static inline void
emit_pop()
{
	TclEmitOpcode(INST_POP, L->frame->envPtr);
}
static inline int
mk_singleTemp(char **p)
{
	static char *nm = "%% L: single tempvar for non-conflicting usage";
	*p = nm;
	return (TclFindCompiledLocal(nm, strlen(nm), 1,
				     L->frame->envPtr->procPtr));
}
static inline int
currOffset(CompileEnv *envPtr)
{
	/* Offset of the next instruction to be generated. */
	return (envPtr->codeNext - envPtr->codeStart);
}

/*
 * REVERSE() assumes that l is a singly linked list of type type with
 * forward pointers named ptr.  The last element in the list becomes
 * the first and is stored back into l.
 */
#define REVERSE(type,ptr,l)						\
    do {								\
	type *a, *b, *c;						\
	for (a = NULL, b = l, c = (l ? ((type *)l)->ptr : NULL);	\
	     b != NULL;							\
	     b->ptr = a, a = b, b = c, c = (c ? c->ptr : NULL)) ;	\
	*(type **)&(l) = a;						\
    } while (0)

/*
 * APPEND() starts at a, walks ptr until the end, and then attaches b
 * to a.  (Note that it's actually NCONC).
 */
#define APPEND(type,ptr,a,b)						\
    do {								\
	    type *runner;						\
	    for (runner = a; runner->ptr; runner = runner->ptr) ;	\
	    runner->ptr = b;						\
    } while (0)

/*
 * These are for maintaining source-file offsets of tokens and
 * nonterminals.  The YYLOC_DEFAULT macro is used by the
 * bison-generated parser to update locations before each reduction.
 */
typedef struct {
	int	beg;
	int	end;
} L_YYLTYPE;
#define YYLTYPE L_YYLTYPE
extern YYLTYPE yylloc;
#define YYLLOC_DEFAULT(c,r,n)				\
	do {						\
		if (n) {				\
			(c).beg = YYRHSLOC(r,1).beg;	\
			(c).end = YYRHSLOC(r,n).end;	\
		} else {				\
			(c).beg = YYRHSLOC(r,0).beg;	\
			(c).end = YYRHSLOC(r,0).end;	\
		}					\
	} while (0)

#ifdef TCL_COMPILE_DEBUG
#define ASSERT(c)  unless (c) \
	L_bomb("Assertion failed: %s:%d: %s\n", __FILE__, __LINE__, #c)
#else
#define ASSERT(c)  do {} while(0)
#endif

#endif /* L_COMPILE_H */
