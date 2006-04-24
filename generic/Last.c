/* This is an automatically generated file, please do not edit */
#include "tclInt.h"
#include "Last.h"

extern void *ast_trace_root;
extern int L_line_number;

char *L_expression_tostr[8] = {
	"L_EXPRESSION_UNARY",
	"L_EXPRESSION_BINARY",
	"L_EXPRESSION_TERTIARY",
	"L_EXPRESSION_PRE",
	"L_EXPRESSION_POST",
	"L_EXPRESSION_INT",
	"L_EXPRESSION_STRING",
	"L_EXPRESSION_FLOAT"
};

char *L_statement_tostr[3] = {
	"L_STATEMENT_EXP",
	"L_STATEMENT_IF_UNLESS",
	"L_STATEMENT_LOOP"
};

char *L_type_tostr[7] = {
	"L_TYPE_INT",
	"L_TYPE_STRING",
	"L_TYPE_FLOAT",
	"L_TYPE_HASH",
	"L_TYPE_POLY",
	"L_TYPE_VAR",
	"L_TYPE_VOID"
};

char *L_loop_tostr[3] = {
	"L_LOOP_FOR",
	"L_LOOP_FOREACH",
	"L_LOOP_WHILE"
};


/* constructors for the L language */
L_statement *mk_statement(L_statement_kind kind,L_statement *next) 
{
	L_statement *statement;

	statement = (L_statement *)ckalloc(sizeof(L_statement));
	statement->kind = kind;
	statement->next = next;
	ast_trace_root = (void *)statement;
	((L_ast_node *)statement)->line_no = L_line_number;
	((L_ast_node *)statement)->type = L_NODE_STATEMENT;
	return statement;
}

L_type *mk_type(L_type_kind kind,int array_dim,L_type *next) 
{
	L_type *type;

	type = (L_type *)ckalloc(sizeof(L_type));
	type->kind = kind;
	type->array_dim = array_dim;
	type->next = next;
	ast_trace_root = (void *)type;
	((L_ast_node *)type)->line_no = L_line_number;
	((L_ast_node *)type)->type = L_NODE_TYPE;
	return type;
}

L_loop *mk_loop(L_loop_kind kind,L_expression *pre,L_expression *condition,L_expression *post,L_statement *body) 
{
	L_loop *loop;

	loop = (L_loop *)ckalloc(sizeof(L_loop));
	loop->kind = kind;
	loop->pre = pre;
	loop->condition = condition;
	loop->post = post;
	loop->body = body;
	ast_trace_root = (void *)loop;
	((L_ast_node *)loop)->line_no = L_line_number;
	((L_ast_node *)loop)->type = L_NODE_LOOP;
	return loop;
}

L_function_declaration *mk_function_declaration(L_variable_declaration *statement,L_function_declaration *next) 
{
	L_function_declaration *function_declaration;

	function_declaration = (L_function_declaration *)ckalloc(sizeof(L_function_declaration));
	function_declaration->statement = statement;
	function_declaration->next = next;
	ast_trace_root = (void *)function_declaration;
	((L_ast_node *)function_declaration)->line_no = L_line_number;
	((L_ast_node *)function_declaration)->type = L_NODE_FUNCTION_DECLARATION;
	return function_declaration;
}

L_variable_declaration *mk_variable_declaration(L_type *type,char *name,L_expression *expr,L_variable_declaration *next) 
{
	L_variable_declaration *variable_declaration;

	variable_declaration = (L_variable_declaration *)ckalloc(sizeof(L_variable_declaration));
	variable_declaration->type = type;
	variable_declaration->name = name;
	variable_declaration->expr = expr;
	variable_declaration->next = next;
	ast_trace_root = (void *)variable_declaration;
	((L_ast_node *)variable_declaration)->line_no = L_line_number;
	((L_ast_node *)variable_declaration)->type = L_NODE_VARIABLE_DECLARATION;
	return variable_declaration;
}

L_expression *mk_expression(L_expression_kind kind,int op,L_expression *a,L_expression *b,L_expression *c) 
{
	L_expression *expression;

	expression = (L_expression *)ckalloc(sizeof(L_expression));
	expression->kind = kind;
	expression->op = op;
	expression->a = a;
	expression->b = b;
	expression->c = c;
	ast_trace_root = (void *)expression;
	((L_ast_node *)expression)->line_no = L_line_number;
	((L_ast_node *)expression)->type = L_NODE_EXPRESSION;
	return expression;
}

L_if_unless *mk_if_unless(L_expression *condition,L_statement *if_body,L_statement *else_body) 
{
	L_if_unless *if_unless;

	if_unless = (L_if_unless *)ckalloc(sizeof(L_if_unless));
	if_unless->condition = condition;
	if_unless->if_body = if_body;
	if_unless->else_body = else_body;
	ast_trace_root = (void *)if_unless;
	((L_ast_node *)if_unless)->line_no = L_line_number;
	((L_ast_node *)if_unless)->type = L_NODE_IF_UNLESS;
	return if_unless;
}

L_program *mk_program(L_variable_declaration *vars,L_function_declaration *funcs) 
{
	L_program *program;

	program = (L_program *)ckalloc(sizeof(L_program));
	program->vars = vars;
	program->funcs = funcs;
	ast_trace_root = (void *)program;
	((L_ast_node *)program)->line_no = L_line_number;
	((L_ast_node *)program)->type = L_NODE_PROGRAM;
	return program;
}

