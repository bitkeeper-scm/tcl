#include "Last.h"

extern void *ast_trace_root;

/* constructor for program */
L_program *mk_program(L_variable_declaration *vars, L_function_declaration *funcs)
{
	L_program *program;

	program = (L_program *)ckalloc(sizeof(L_program));
	program->vars = vars;
	program->funcs = funcs;
	program->node.next = ast_trace_root;
	ast_trace_root = (void *)program;
	return program;
}
/* constructor for variable_declaration */
L_variable_declaration *mk_variable_declaration(L_type *type, char* name, L_expression *expr, L_variable_declaration *next)
{
	L_variable_declaration *variable_declaration;

	variable_declaration = (L_variable_declaration *)ckalloc(sizeof(L_variable_declaration));
	variable_declaration->type = type;
	variable_declaration->name = name;
	variable_declaration->expr = expr;
	variable_declaration->next = next;
	variable_declaration->node.next = ast_trace_root;
	ast_trace_root = (void *)variable_declaration;
	return variable_declaration;
}
/* constructor for function_declaration */
L_function_declaration *mk_function_declaration(L_variable_declaration *statement, L_function_declaration *next)
{
	L_function_declaration *function_declaration;

	function_declaration = (L_function_declaration *)ckalloc(sizeof(L_function_declaration));
	function_declaration->statement = statement;
	function_declaration->next = next;
	function_declaration->node.next = ast_trace_root;
	ast_trace_root = (void *)function_declaration;
	return function_declaration;
}
/* constructor for statement */
L_statement *mk_statement(L_statement *next)
{
	L_statement *statement;

	statement = (L_statement *)ckalloc(sizeof(L_statement));
	statement->next = next;
	statement->node.next = ast_trace_root;
	ast_trace_root = (void *)statement;
	return statement;
}
/* constructor for if_unless */
L_if_unless *mk_if_unless(L_expression *condition, L_statement *if_body, L_statement *else_body)
{
	L_if_unless *if_unless;

	if_unless = (L_if_unless *)ckalloc(sizeof(L_if_unless));
	if_unless->condition = condition;
	if_unless->if_body = if_body;
	if_unless->else_body = else_body;
	if_unless->node.next = ast_trace_root;
	ast_trace_root = (void *)if_unless;
	return if_unless;
}
/* constructor for loop */
L_loop *mk_loop(L_expression *pre, L_expression *condition, L_expression *post, L_statement *body)
{
	L_loop *loop;

	loop = (L_loop *)ckalloc(sizeof(L_loop));
	loop->pre = pre;
	loop->condition = condition;
	loop->post = post;
	loop->body = body;
	loop->node.next = ast_trace_root;
	ast_trace_root = (void *)loop;
	return loop;
}
/* constructor for expression */
L_expression *mk_expression(int op, L_expression *a, L_expression *b, L_expression *c)
{
	L_expression *expression;

	expression = (L_expression *)ckalloc(sizeof(L_expression));
	expression->op = op;
	expression->a = a;
	expression->b = b;
	expression->c = c;
	expression->node.next = ast_trace_root;
	ast_trace_root = (void *)expression;
	return expression;
}
/* constructor for type */
L_type *mk_type(int array_dim, L_type *next)
{
	L_type *type;

	type = (L_type *)ckalloc(sizeof(L_type));
	type->array_dim = array_dim;
	type->next = next;
	type->node.next = ast_trace_root;
	ast_trace_root = (void *)type;
	return type;
}

