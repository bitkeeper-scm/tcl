/* This is an automatically generated file, please do not edit */
/* use: tclsh gen-l-ast2.tcl to regenerate */
#ifndef L_AST_H
#define L_AST_H

/* Defines */
#define	L_WALK_CONTINUE		0x00000
#define	L_WALK_PRE		0x00001
#define	L_WALK_POST		0x00002
#define	L_WALK_SKIP_CHILDREN	0x00004
#define	L_WALK_SKIP_POST	0x00008
#define	L_WALK_BREAK		0x0000C
#define	L_WALK_ERROR		0x8000C

/* Typedefs */
typedef struct L_ast_node L_ast_node;
typedef struct L_block L_block;
typedef struct L_variable_declaration L_variable_declaration;
typedef struct L_function_declaration L_function_declaration;
typedef struct L_statement L_statement;
typedef struct L_toplevel_statement L_toplevel_statement;
typedef struct L_if_unless L_if_unless;
typedef struct L_loop L_loop;
typedef struct L_foreach_loop L_foreach_loop;
typedef struct L_expression L_expression;
typedef struct L_type L_type;
typedef struct L_initializer L_initializer;

/* Enums */
typedef enum L_expression_kind {
	L_EXPRESSION_ARRAY_INDEX,
	L_EXPRESSION_BINARY,
	L_EXPRESSION_FLOTE,
	L_EXPRESSION_FUNCALL,
	L_EXPRESSION_HASH_INDEX,
	L_EXPRESSION_INTEGER,
	L_EXPRESSION_INTERPOLATED_STRING,
	L_EXPRESSION_POST,
	L_EXPRESSION_PRE,
	L_EXPRESSION_STRING,
	L_EXPRESSION_STRUCT_INDEX,
	L_EXPRESSION_TERTIARY,
	L_EXPRESSION_UNARY,
	L_EXPRESSION_VARIABLE
} L_expression_kind;

extern char *L_expression_tostr[14];
typedef enum L_loop_kind {
	L_LOOP_DO,
	L_LOOP_FOR,
	L_LOOP_WHILE
} L_loop_kind;

extern char *L_loop_tostr[3];
typedef enum L_statement_kind {
	L_STATEMENT_BLOCK,
	L_STATEMENT_BREAK,
	L_STATEMENT_COND,
	L_STATEMENT_CONTINUE,
	L_STATEMENT_DECL,
	L_STATEMENT_EXPR,
	L_STATEMENT_FOREACH,
	L_STATEMENT_LOOP,
	L_STATEMENT_RETURN
} L_statement_kind;

extern char *L_statement_tostr[9];
typedef enum L_toplevel_statement_kind {
	L_TOPLEVEL_STATEMENT_FUN,
	L_TOPLEVEL_STATEMENT_GLOBAL,
	L_TOPLEVEL_STATEMENT_TYPE,
	L_TOPLEVEL_STATEMENT_TYPEDEF
} L_toplevel_statement_kind;

extern char *L_toplevel_statement_tostr[4];
typedef enum L_type_kind {
	L_TYPE_ARRAY,
	L_TYPE_FLOAT,
	L_TYPE_HASH,
	L_TYPE_INT,
	L_TYPE_POLY,
	L_TYPE_STRING,
	L_TYPE_STRUCT,
	L_TYPE_VAR,
	L_TYPE_VOID
} L_type_kind;

extern char *L_type_tostr[9];
typedef enum L_node_type {
	L_NODE_BLOCK,
	L_NODE_EXPRESSION,
	L_NODE_FOREACH_LOOP,
	L_NODE_FUNCTION_DECLARATION,
	L_NODE_IF_UNLESS,
	L_NODE_INITIALIZER,
	L_NODE_LOOP,
	L_NODE_STATEMENT,
	L_NODE_TOPLEVEL_STATEMENT,
	L_NODE_TYPE,
	L_NODE_VARIABLE_DECLARATION
} L_node_type;
extern char *L_node_type_tostr[11];

/* Struct declarations */
struct L_ast_node {
	L_ast_node *_trace;
	L_node_type type;
	int line_no;
};

struct L_block {
	L_ast_node node;
	L_statement *body;
	L_variable_declaration *decls;
};

struct L_expression {
	L_ast_node node;
	L_expression *a;
	L_expression *b;
	L_expression *c;
	L_expression *indices;
	L_expression *next;
	L_expression_kind kind;
	int op;
	union {
		char *string;
		double flote;
		int integer;
	} u;
};

struct L_foreach_loop {
	L_ast_node node;
	L_expression *hash;
	L_expression *key;
	L_expression *value;
	L_statement *body;
};

struct L_function_declaration {
	L_ast_node node;
	L_block *body;
	L_expression *name;
	L_type *return_type;
	L_variable_declaration *params;
};

struct L_if_unless {
	L_ast_node node;
	L_expression *condition;
	L_statement *else_body;
	L_statement *if_body;
};

struct L_initializer {
	L_ast_node node;
	L_expression *key;
	L_expression *value;
	L_initializer *next;
	L_initializer *next_dim;
};

struct L_loop {
	L_ast_node node;
	L_expression *condition;
	L_expression *post;
	L_expression *pre;
	L_loop_kind kind;
	L_statement *body;
};

struct L_statement {
	L_ast_node node;
	L_statement *next;
	L_statement_kind kind;
	union {
		L_block *block;
		L_expression *expr;
		L_foreach_loop *foreach;
		L_if_unless *cond;
		L_loop *loop;
		L_variable_declaration *decl;
	} u;
};

struct L_toplevel_statement {
	L_ast_node node;
	L_toplevel_statement *next;
	L_toplevel_statement_kind kind;
	union {
		L_function_declaration *fun;
		L_type *type;
		L_variable_declaration *global;
	} u;
};

struct L_type {
	L_ast_node node;
	L_expression *array_dim;
	L_expression *struct_tag;
	L_type *next_dim;
	L_type_kind kind;
	L_variable_declaration *members;
	int typedef_p;
};

struct L_variable_declaration {
	L_ast_node node;
	L_expression *name;
	L_initializer *initial_value;
	L_type *type;
	L_variable_declaration *next;
	int by_name;
};


/* Prototypes */
typedef int (*LWalkFunc)(L_ast_node *node, void *data, int order);
L_block *mk_block(L_variable_declaration *decls,L_statement *body);
int L_walk_block(L_block* node, int order, LWalkFunc func, void *data);
L_expression *mk_expression(L_expression_kind kind,int op,L_expression *a,L_expression *b,L_expression *c,L_expression *indices,L_expression *next);
int L_walk_expression(L_expression* node, int order, LWalkFunc func, void *data);
L_foreach_loop *mk_foreach_loop(L_expression *hash,L_expression *key,L_expression *value,L_statement *body);
int L_walk_foreach_loop(L_foreach_loop* node, int order, LWalkFunc func, void *data);
L_function_declaration *mk_function_declaration(L_expression *name,L_variable_declaration *params,L_type *return_type,L_block *body);
int L_walk_function_declaration(L_function_declaration* node, int order, LWalkFunc func, void *data);
L_if_unless *mk_if_unless(L_expression *condition,L_statement *if_body,L_statement *else_body);
int L_walk_if_unless(L_if_unless* node, int order, LWalkFunc func, void *data);
L_initializer *mk_initializer(L_expression *key,L_expression *value,L_initializer *next_dim,L_initializer *next);
int L_walk_initializer(L_initializer* node, int order, LWalkFunc func, void *data);
L_loop *mk_loop(L_loop_kind kind,L_expression *pre,L_expression *condition,L_expression *post,L_statement *body);
int L_walk_loop(L_loop* node, int order, LWalkFunc func, void *data);
L_statement *mk_statement(L_statement_kind kind,L_statement *next);
int L_walk_statement(L_statement* node, int order, LWalkFunc func, void *data);
L_toplevel_statement *mk_toplevel_statement(L_toplevel_statement_kind kind,L_toplevel_statement *next);
int L_walk_toplevel_statement(L_toplevel_statement* node, int order, LWalkFunc func, void *data);
L_type *mk_type(L_type_kind kind,L_expression *array_dim,L_expression *struct_tag,L_type *next_dim,L_variable_declaration *members,int typedef_p);
int L_walk_type(L_type* node, int order, LWalkFunc func, void *data);
L_variable_declaration *mk_variable_declaration(L_type *type,L_expression *name,L_initializer *initial_value,int by_name,L_variable_declaration *next);
int L_walk_variable_declaration(L_variable_declaration* node, int order, LWalkFunc func, void *data);
int L_walk_ast(L_ast_node *node, int order, LWalkFunc func, void *data);

#endif /* L_AST_H */
