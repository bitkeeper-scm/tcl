/* This is an automatically generated file, please do not edit */
/* use: tclsh gen-l-ast2.tcl to regenerate */
#ifndef L_AST_H
#define L_AST_H

/* Typedefs */
typedef struct L_ast_node L_ast_node;
typedef struct L_block L_block;
typedef struct L_variable_declaration L_variable_declaration;
typedef struct L_function_declaration L_function_declaration;
typedef struct L_statement L_statement;
typedef struct L_toplevel_statement L_toplevel_statement;
typedef struct L_if_unless L_if_unless;
typedef struct L_loop L_loop;
typedef struct L_expression L_expression;
typedef struct L_type L_type;

/* Enums */
typedef enum L_expression_kind {
	L_EXPRESSION_UNARY,
	L_EXPRESSION_BINARY,
	L_EXPRESSION_TERTIARY,
	L_EXPRESSION_PRE,
	L_EXPRESSION_POST,
	L_EXPRESSION_INT,
	L_EXPRESSION_STRING,
	L_EXPRESSION_DOUBLE,
	L_EXPRESSION_VARIABLE,
	L_EXPRESSION_FUNCALL,
	L_EXPRESSION_ARRAY_INDEX,
	L_EXPRESSION_STRUCT_INDEX,
	L_EXPRESSION_HASH_INDEX,
	L_EXPRESSION_INTERPOLATED_STRING
} L_expression_kind;

extern char *L_expression_tostr[14];
typedef enum L_statement_kind {
	L_STATEMENT_EXPR,
	L_STATEMENT_IF_UNLESS,
	L_STATEMENT_LOOP,
	L_STATEMENT_RETURN,
	L_STATEMENT_BLOCK
} L_statement_kind;

extern char *L_statement_tostr[5];
typedef enum L_type_kind {
	L_TYPE_INT,
	L_TYPE_STRING,
	L_TYPE_DOUBLE,
	L_TYPE_HASH,
	L_TYPE_POLY,
	L_TYPE_VAR,
	L_TYPE_VOID,
	L_TYPE_STRUCT
} L_type_kind;

extern char *L_type_tostr[8];
typedef enum L_loop_kind {
	L_LOOP_FOR,
	L_LOOP_FOREACH,
	L_LOOP_WHILE,
	L_LOOP_DO
} L_loop_kind;

extern char *L_loop_tostr[4];
typedef enum L_toplevel_statement_kind {
	L_TOPLEVEL_STATEMENT_FUNCTION_DECLARATION,
	L_TOPLEVEL_STATEMENT_TYPE,
	L_TOPLEVEL_STATEMENT_GLOBAL
} L_toplevel_statement_kind;

extern char *L_toplevel_statement_tostr[3];
typedef enum L_node_type {
	L_NODE_STATEMENT,
	L_NODE_TYPE,
	L_NODE_LOOP,
	L_NODE_TOPLEVEL_STATEMENT,
	L_NODE_FUNCTION_DECLARATION,
	L_NODE_VARIABLE_DECLARATION,
	L_NODE_BLOCK,
	L_NODE_EXPRESSION,
	L_NODE_IF_UNLESS
} L_node_type;
extern char *L_node_type_tostr[9];

/* Struct declarations */
struct L_ast_node {
	int line_no;
	L_node_type type;
	L_ast_node *_trace;
};

struct L_block {
	L_ast_node node;
	L_variable_declaration *decls;
	L_statement *body;
};

struct L_expression {
	L_ast_node node;
	L_expression_kind kind;
	int op;
	L_expression *a;
	L_expression *b;
	L_expression *c;
	L_expression *indices;
	L_expression *next;
	union {
		int i;
		char *s;
		double d;
	} u;
};

struct L_function_declaration {
	L_ast_node node;
	L_expression *name;
	L_variable_declaration *params;
	L_type *return_type;
	L_block *body;
};

struct L_if_unless {
	L_ast_node node;
	L_expression *condition;
	L_statement *if_body;
	L_statement *else_body;
};

struct L_loop {
	L_ast_node node;
	L_loop_kind kind;
	L_expression *pre;
	L_expression *condition;
	L_expression *post;
	L_statement *body;
};

struct L_statement {
	L_ast_node node;
	L_statement_kind kind;
	L_statement *next;
	union {
		L_expression *expr;
		L_if_unless *cond;
		L_loop *loop;
		L_variable_declaration *decl;
		L_block *block;
	} u;
};

struct L_toplevel_statement {
	L_ast_node node;
	L_toplevel_statement_kind kind;
	L_toplevel_statement *next;
	union {
		L_function_declaration *fun;
		L_type *type;
		L_variable_declaration *global;
	} u;
};

struct L_type {
	L_ast_node node;
	L_type_kind kind;
	L_expression *array_dim;
	L_expression *struct_tag;
	L_type *next_dim;
	L_variable_declaration *members;
};

struct L_variable_declaration {
	L_ast_node node;
	L_type *type;
	L_expression *name;
	L_expression *initial_value;
	L_variable_declaration *next;
};


/* Prototypes */
L_statement *mk_statement(L_statement_kind kind,L_statement *next);
L_type *mk_type(L_type_kind kind,L_expression *array_dim,L_expression *struct_tag,L_type *next_dim,L_variable_declaration *members);
L_loop *mk_loop(L_loop_kind kind,L_expression *pre,L_expression *condition,L_expression *post,L_statement *body);
L_toplevel_statement *mk_toplevel_statement(L_toplevel_statement_kind kind,L_toplevel_statement *next);
L_function_declaration *mk_function_declaration(L_expression *name,L_variable_declaration *params,L_type *return_type,L_block *body);
L_variable_declaration *mk_variable_declaration(L_type *type,L_expression *name,L_expression *initial_value,L_variable_declaration *next);
L_block *mk_block(L_variable_declaration *decls,L_statement *body);
L_expression *mk_expression(L_expression_kind kind,int op,L_expression *a,L_expression *b,L_expression *c,L_expression *indices,L_expression *next);
L_if_unless *mk_if_unless(L_expression *condition,L_statement *if_body,L_statement *else_body);

#endif /* L_AST_H */
