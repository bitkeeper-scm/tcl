/* This is an automatically generated file, please do not edit */
#ifndef L_AST_H
#define L_AST_H

/* Typedefs */
typedef struct L_ast_node L_ast_node;
typedef struct L_program L_program;
typedef struct L_variable_declaration L_variable_declaration;
typedef struct L_function_declaration L_function_declaration;
typedef struct L_statement L_statement;
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
	L_EXPRESSION_FLOAT
} L_expression_kind;

typedef enum L_statement_kind {
	L_STATEMENT_EXP,
	L_STATEMENT_IF_UNLESS,
	L_STATEMENT_LOOP
} L_statement_kind;

typedef enum L_type_kind {
	L_TYPE_INT,
	L_TYPE_STRING,
	L_TYPE_FLOAT,
	L_TYPE_HASH,
	L_TYPE_POLY,
	L_TYPE_VAR,
	L_TYPE_VOID
} L_type_kind;

typedef enum L_loop_kind {
	L_LOOP_FOR,
	L_LOOP_FOREACH,
	L_LOOP_WHILE
} L_loop_kind;

typedef enum L_node_type {
	L_NODE_STATEMENT,
	L_NODE_TYPE,
	L_NODE_LOOP,
	L_NODE_FUNCTION_DECLARATION,
	L_NODE_VARIABLE_DECLARATION,
	L_NODE_EXPRESSION,
	L_NODE_IF_UNLESS,
	L_NODE_PROGRAM
} L_node_type;

/* Struct declarations */
struct L_ast_node {
	int line_no;
	L_node_type type;
	void *next;
};

struct L_expression {
	L_ast_node node;
	L_expression_kind kind;
	int op;
	L_expression *a;
	L_expression *b;
	L_expression *c;
	union {
		int i;
		char *s;
		double d;
	} u;
};

struct L_function_declaration {
	L_ast_node node;
	L_variable_declaration *statement;
	L_function_declaration *next;
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

struct L_program {
	L_ast_node node;
	L_variable_declaration *vars;
	L_function_declaration *funcs;
};

struct L_statement {
	L_ast_node node;
	L_statement_kind kind;
	L_statement *next;
	union {
		L_expression *expr;
		L_if_unless *cond;
		L_loop *loop;
	} u;
};

struct L_type {
	L_ast_node node;
	L_type_kind kind;
	int array_dim;
	L_type *next;
};

struct L_variable_declaration {
	L_ast_node node;
	L_type *type;
	char *name;
	L_expression *expr;
	L_variable_declaration *next;
};


/* Prototypes */
L_statement *mk_statement(L_statement_kind kind,L_statement *next);
L_type *mk_type(L_type_kind kind,int array_dim,L_type *next);
L_loop *mk_loop(L_loop_kind kind,L_expression *pre,L_expression *condition,L_expression *post,L_statement *body);
L_function_declaration *mk_function_declaration(L_variable_declaration *statement,L_function_declaration *next);
L_variable_declaration *mk_variable_declaration(L_type *type,char *name,L_expression *expr,L_variable_declaration *next);
L_expression *mk_expression(L_expression_kind kind,int op,L_expression *a,L_expression *b,L_expression *c);
L_if_unless *mk_if_unless(L_expression *condition,L_statement *if_body,L_statement *else_body);
L_program *mk_program(L_variable_declaration *vars,L_function_declaration *funcs);

#endif /* L_AST_H */
