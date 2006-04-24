/* THIS IS A GENERATED FILE -- DO NOT EDIT! */
#include "tclInt.h"
#include "Last.h"

extern void *ast_trace_root;

extern int L_line_number;

char *L_statement_tostr[5] = {
	"L_STATEMENT_EXPR",
	"L_STATEMENT_IF_UNLESS",
	"L_STATEMENT_LOOP",
	"L_STATEMENT_RETURN_STMT",
	"L_STATEMENT_VARIABLE_DECLARATION"};

char *L_loop_tostr[3] = {
	"L_LOOP_FOR",
	"L_LOOP_FOREACH",
	"L_LOOP_WHILE"};

char *L_expression_tostr[9] = {
	"L_EXPRESSION_UNARY",
	"L_EXPRESSION_BINARY",
	"L_EXPRESSION_TERTIARY",
	"L_EXPRESSION_PRE",
	"L_EXPRESSION_POST",
	"L_EXPRESSION_INT",
	"L_EXPRESSION_STRING",
	"L_EXPRESSION_FLOAT",
	"L_EXPRESSION_FUNCALL"};

char *L_type_tostr[7] = {
	"L_TYPE_INT",
	"L_TYPE_STRING",
	"L_TYPE_FLOAT",
	"L_TYPE_HASH",
	"L_TYPE_POLY",
	"L_TYPE_VAR",
	"L_TYPE_VOID"};


/* constructor for program */
L_program *mk_program(L_variable_declaration *vars, L_function_declaration *funcs)
{
	L_program *program;

	program = (L_program *)ckalloc(sizeof(L_program));
	program->vars = vars;
	program->funcs = funcs;
	program->node.next = ast_trace_root;
	ast_trace_root = (void *)program;
	((L_ast_node *)program)->line_no = L_line_number;
	((L_ast_node *)program)->type = L_NODE_PROGRAM;
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
	((L_ast_node *)variable_declaration)->line_no = L_line_number;
	((L_ast_node *)variable_declaration)->type = L_NODE_VARIABLE_DECLARATION;
	return variable_declaration;
}
/* constructor for function_declaration */
L_function_declaration *mk_function_declaration(L_expression *name, L_type *return_type, L_variable_declaration *params, L_statement *body, L_function_declaration *next)
{
	L_function_declaration *function_declaration;

	function_declaration = (L_function_declaration *)ckalloc(sizeof(L_function_declaration));
	function_declaration->name = name;
	function_declaration->return_type = return_type;
	function_declaration->params = params;
	function_declaration->body = body;
	function_declaration->next = next;
	function_declaration->node.next = ast_trace_root;
	ast_trace_root = (void *)function_declaration;
	((L_ast_node *)function_declaration)->line_no = L_line_number;
	((L_ast_node *)function_declaration)->type = L_NODE_FUNCTION_DECLARATION;
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
	((L_ast_node *)statement)->line_no = L_line_number;
	((L_ast_node *)statement)->type = L_NODE_STATEMENT;
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
	((L_ast_node *)if_unless)->line_no = L_line_number;
	((L_ast_node *)if_unless)->type = L_NODE_IF_UNLESS;
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
	((L_ast_node *)loop)->line_no = L_line_number;
	((L_ast_node *)loop)->type = L_NODE_LOOP;
	return loop;
}
/* constructor for expression */
L_expression *mk_expression(int op, L_expression *a, L_expression *b, L_expression *c, L_expression *next)
{
	L_expression *expression;

	expression = (L_expression *)ckalloc(sizeof(L_expression));
	expression->op = op;
	expression->a = a;
	expression->b = b;
	expression->c = c;
	expression->next = next;
	expression->node.next = ast_trace_root;
	ast_trace_root = (void *)expression;
	((L_ast_node *)expression)->line_no = L_line_number;
	((L_ast_node *)expression)->type = L_NODE_EXPRESSION;
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
	((L_ast_node *)type)->line_no = L_line_number;
	((L_ast_node *)type)->type = L_NODE_TYPE;
	return type;
}

