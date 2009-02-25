/*
 * used to be: tclsh gen-l-ast2.tcl to regenerate
 * As of Feb 2008 it is maintained by hand.
 */
#ifndef L_AST_H
#define L_AST_H

#define	unless(p)	if (!(p))
#define	private		static

/* Argument type for type_mk* functions. */
enum typemk_k {
	PERSIST,	// persist type descriptor across all interps
	PER_INTERP,	// type descriptor is freed when interp is freed
};

typedef struct Ast	Ast;
typedef struct Block	Block;
typedef struct VarDecl	VarDecl;
typedef struct FnDecl	FnDecl;
typedef struct Stmt	Stmt;
typedef struct TopLev	TopLev;
typedef struct Cond	Cond;
typedef struct Loop	Loop;
typedef struct ForEach	ForEach;
typedef struct Expr	Expr;
typedef struct Type	Type;
typedef struct Sym	Sym;

typedef enum {
	L_LOOP_DO,
	L_LOOP_FOR,
	L_LOOP_WHILE,
} Loop_k;

typedef enum {
	L_STMT_BLOCK,
	L_STMT_BREAK,
	L_STMT_COND,
	L_STMT_CONTINUE,
	L_STMT_DECL,
	L_STMT_EXPR,
	L_STMT_FOREACH,
	L_STMT_LOOP,
	L_STMT_RETURN,
} Stmt_k;

typedef enum {
	L_TOPLEVEL_FUN,
	L_TOPLEVEL_GLOBAL,
	L_TOPLEVEL_STMT,
} Toplv_k;

typedef enum {
	L_NODE_BLOCK,
	L_NODE_EXPR,
	L_NODE_FOREACH_LOOP,
	L_NODE_FUNCTION_DECL,
	L_NODE_IF_UNLESS,
	L_NODE_LOOP,
	L_NODE_STMT,
	L_NODE_TOPLEVEL,
	L_NODE_VAR_DECL,
} Node_k;

/*
 * An L type name is represented with exactly one instance of a
 * Type structure.  All references to the type name point to that
 * structure, so pointer comparison can be used to check for name
 * equivalence of types.
 *
 * L_int, L_float, etc are the global Type pointers for the
 * pre-defined types.  L_INT, L_FLOAT, etc are the type kinds
 * (enum) used in the type structure.
 *
 * L_NAMEOF is like an address in other languages.  An expression
 * of this type holds the name of an lvalue (e.g., &p has the value
 * "p").  The base_type is the type of the name.
 */

typedef enum {
	L_INT		= 0x0001,
	L_FLOAT		= 0x0002,
	L_STRING	= 0x0004,
	L_ARRAY		= 0x0008,
	L_HASH		= 0x0010,
	L_STRUCT	= 0x0020,
	L_LIST		= 0x0040,
	L_VOID		= 0x0080,
	L_VAR		= 0x0100,
	L_POLY		= 0x0200,
	L_NAMEOF	= 0x0400,
	L_FUNCTION	= 0x0800,
} Type_k;

struct Type {
	Type_k	kind;
	Type	*base_type;	// for array, hash, list, nameof, & fn ret type
	Type	*next;		// for linking list types
	union {
		struct {
			Expr	*size;
		} array;
		struct {
			Type	*idx_type;
		} hash;
		struct {
			char	*tag;
			VarDecl	*members;
		} struc;
		struct {
			VarDecl	*formals;
		} func;
	} u;
	Type	*list;  // links all type structures ever allocated
};

struct Ast {
	Node_k	type;
	Ast	*next;	// links all nodes in an AST
	char	*file;
	int	line;
	int	beg;
	int	end;
};

struct Block {
	Ast	node;
	Stmt	*body;
	VarDecl	*decls;
};

typedef enum {
	L_EXPR_ID,
	L_EXPR_CONST,
	L_EXPR_FUNCALL,
	L_EXPR_UNOP,
	L_EXPR_BINOP,
	L_EXPR_TRINOP,
	L_EXPR_RE,
} Expr_k;

typedef enum {
	L_OP_NONE,
	L_OP_CAST,
	L_OP_BANG,
	L_OP_ADDROF,
	L_OP_MINUS,
	L_OP_UMINUS,
	L_OP_PLUS,
	L_OP_UPLUS,
	L_OP_PLUSPLUS_PRE,
	L_OP_PLUSPLUS_POST,
	L_OP_MINUSMINUS_PRE,
	L_OP_MINUSMINUS_POST,
	L_OP_EQUALS,
	L_OP_EQPLUS,
	L_OP_EQMINUS,
	L_OP_EQSTAR,
	L_OP_EQSLASH,
	L_OP_EQPERC,
	L_OP_EQBITAND,
	L_OP_EQBITOR,
	L_OP_EQBITXOR,
	L_OP_EQLSHIFT,
	L_OP_EQRSHIFT,
	L_OP_EQTWID,
	L_OP_STAR,
	L_OP_SLASH,
	L_OP_PERC,
	L_OP_STR_EQ,
	L_OP_STR_NE,
	L_OP_STR_GT,
	L_OP_STR_LT,
	L_OP_STR_GE,
	L_OP_STR_LE,
	L_OP_EQUALEQUAL,
	L_OP_NOTEQUAL,
	L_OP_GREATER,
	L_OP_LESSTHAN,
	L_OP_GREATEREQ,
	L_OP_LESSTHANEQ,
	L_OP_ANDAND,
	L_OP_OROR,
	L_OP_LSHIFT,
	L_OP_RSHIFT,
	L_OP_BITOR,
	L_OP_BITAND,
	L_OP_BITXOR,
	L_OP_BITNOT,
	L_OP_DEFINED,
	L_OP_ARRAY_INDEX,
	L_OP_HASH_INDEX,
	L_OP_STRUCT_INDEX,
	L_OP_INTERP_STRING,
	L_OP_INTERP_RE,
	L_OP_LIST,
	L_OP_CONS,
	L_OP_KV,
	L_OP_COMMA,
} Op_k;

typedef enum {
	L_EXPR_RE_I	= 0x01,  // expr is an re with "i" qualifier
	L_EXPR_RE_G	= 0x02,  // expr is an re with "g" qualifier
} Expr_f;

struct Expr {
	Ast	node;
	Expr_k	kind;
	Op_k	op;
	Type	*type;
	Expr	*a;
	Expr	*b;
	Expr	*c;
	Expr_f	flags;
	Sym	*sym;  // for id, ptr to symbol table entry
	union {
		long	integer;
		double	flote;
		char	*string;  // for strlit/id/re/struct-index
	} u;
	Expr	*next;
};

struct ForEach {
	Ast	node;
	Expr	*expr;
	Expr	*key;
	Expr	*value;
	Stmt	*body;
};

struct FnDecl {
	Ast	node;
	Block	*body;
	VarDecl	*decl;
	int	pattern_p;
};

struct Cond {
	Ast	node;
	Expr	*cond;
	Stmt	*else_body;
	Stmt	*if_body;
};

struct Loop {
	Ast	node;
	Expr	*cond;
	Expr	*post;
	Expr	*pre;
	Loop_k	kind;
	Stmt	*body;
};

struct Stmt {
	Ast	node;
	Stmt	*next;
	Stmt_k	kind;
	union {
		Block	*block;
		Expr	*expr;
		ForEach	*foreach;
		Cond	*cond;
		Loop	*loop;
		VarDecl	*decl;
	} u;
};

struct TopLev {
	Ast	node;
	TopLev	*next;
	Toplv_k	kind;
	union {
		FnDecl	*fun;
		Stmt	*stmt;
		VarDecl	*global;
	} u;
};

struct VarDecl {
	Ast	node;
	Expr	*id;
	Expr	*initializer;
	Type	*type;
	VarDecl	*next;
	int	by_name;
	int	outer_p;
	int	extern_p;
	int	rest_p;
};

extern Expr	*ast_mkBinOp(Op_k op, Expr *e1, Expr *e2, int beg, int end);
extern Block	*ast_mkBlock(VarDecl *decls,Stmt *body, int beg, int end);
extern Expr	*ast_mkConst(Type *type, int beg, int end);
extern Expr	*ast_mkExpr(Expr_k kind, Op_k op, Expr *a, Expr *b, Expr *c,
			    int beg, int end);
extern Expr	*ast_mkFnCall(Expr *id, Expr *arg_list, int beg, int end);
extern FnDecl	*ast_mkFnDecl(VarDecl *decl, Block *body, int pattern_p,
			      int beg, int end);
extern ForEach	*ast_mkForeach(Expr *hash, Expr *key, Expr *value,
			       Stmt *body, int beg, int end);
extern Expr	*ast_mkId(char *name, int beg, int end);
extern Cond	*ast_mkIfUnless(Expr *expr, Stmt *if_body, Stmt *else_body,
				int beg, int end);
extern Loop	*ast_mkLoop(Loop_k kind, Expr *pre, Expr *cond, Expr *post,
			    Stmt *body, int beg, int end);
extern Expr	*ast_mkRegexp(char *re, int beg, int end);
extern Stmt	*ast_mkStmt(Stmt_k kind, Stmt *next, int beg, int end);
extern TopLev	*ast_mkTopLevel(Toplv_k kind, TopLev *next, int beg, int end);
extern Expr	*ast_mkTrinOp(Op_k op, Expr *e1, Expr *e2, Expr *e3,
			      int beg, int end);
extern Expr	*ast_mkUnOp(Op_k op, Expr *e1, int beg, int end);
extern VarDecl	*ast_mkVarDecl(Type *type, Expr *name, int beg, int end);
extern Type	*type_mkArray(Expr *size, Type *base_type,
			      enum typemk_k disposition);
extern Type	*type_mkFunc(Type *base_type, VarDecl *formals,
			     enum typemk_k disposition);
extern Type	*type_mkHash(Type *index_type, Type *base_type,
			     enum typemk_k disposition);
extern Type	*type_mkList(Type *a, enum typemk_k disposition);
extern Type	*type_mkNameOf(Type *base_type, enum typemk_k disposition);
extern Type	*type_mkScalar(Type_k kind, enum typemk_k disposition);
extern Type	*type_mkStruct(char *tag, VarDecl *members,
			       enum typemk_k disposition);

#endif /* L_AST_H */
