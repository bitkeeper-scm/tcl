/* This is an automatically generated file, please do not edit */
/* use: tclsh gen-l-ast2.tcl to regenerate */
#include "tclInt.h"
#include "Last.h"

extern void *ast_trace_root;
extern int L_line_number;

char *L_expression_tostr[13] = {
	"L_EXPRESSION_UNARY",
	"L_EXPRESSION_BINARY",
	"L_EXPRESSION_TERTIARY",
	"L_EXPRESSION_PRE",
	"L_EXPRESSION_POST",
	"L_EXPRESSION_INT",
	"L_EXPRESSION_STRING",
	"L_EXPRESSION_DOUBLE",
	"L_EXPRESSION_VARIABLE",
	"L_EXPRESSION_FUNCALL",
	"L_EXPRESSION_ARRAY_INDEX",
	"L_EXPRESSION_STRUCT_INDEX",
	"L_EXPRESSION_HASH_INDEX"
};

char *L_statement_tostr[5] = {
	"L_STATEMENT_EXPR",
	"L_STATEMENT_IF_UNLESS",
	"L_STATEMENT_LOOP",
	"L_STATEMENT_RETURN",
	"L_STATEMENT_BLOCK"
};

char *L_type_tostr[8] = {
	"L_TYPE_INT",
	"L_TYPE_STRING",
	"L_TYPE_DOUBLE",
	"L_TYPE_HASH",
	"L_TYPE_POLY",
	"L_TYPE_VAR",
	"L_TYPE_VOID",
	"L_TYPE_STRUCT"
};

char *L_loop_tostr[4] = {
	"L_LOOP_FOR",
	"L_LOOP_FOREACH",
	"L_LOOP_WHILE",
	"L_LOOP_DO"
};

char *L_toplevel_statement_tostr[2] = {
	"L_TOPLEVEL_STATEMENT_FUNCTION_DECLARATION",
	"L_TOPLEVEL_STATEMENT_TYPE"
};

char *L_node_type_tostr[9] = {
	"L_NODE_STATEMENT",
	"L_NODE_TYPE",
	"L_NODE_LOOP",
	"L_NODE_TOPLEVEL_STATEMENT",
	"L_NODE_FUNCTION_DECLARATION",
	"L_NODE_VARIABLE_DECLARATION",
	"L_NODE_BLOCK",
	"L_NODE_EXPRESSION",
	"L_NODE_IF_UNLESS"
};


/* constructors for the L language */
L_statement *mk_statement(L_statement_kind kind,L_statement *next) 
{
	L_statement *statement;

	statement = (L_statement *)ckalloc(sizeof(L_statement));
	statement->kind = kind;
	statement->next = next;
	((L_ast_node *)statement)->_trace = ast_trace_root;
	ast_trace_root = (void *)statement;
	((L_ast_node *)statement)->line_no = L_line_number;
	((L_ast_node *)statement)->type = L_NODE_STATEMENT;
	return statement;
}

L_type *mk_type(L_type_kind kind,L_expression *array_dim,L_expression *struct_tag,L_type *next_dim,L_variable_declaration *members) 
{
	L_type *type;

	type = (L_type *)ckalloc(sizeof(L_type));
	type->kind = kind;
	type->array_dim = array_dim;
	type->struct_tag = struct_tag;
	type->next_dim = next_dim;
	type->members = members;
	((L_ast_node *)type)->_trace = ast_trace_root;
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
	((L_ast_node *)loop)->_trace = ast_trace_root;
	ast_trace_root = (void *)loop;
	((L_ast_node *)loop)->line_no = L_line_number;
	((L_ast_node *)loop)->type = L_NODE_LOOP;
	return loop;
}

L_toplevel_statement *mk_toplevel_statement(L_toplevel_statement_kind kind,L_toplevel_statement *next) 
{
	L_toplevel_statement *toplevel_statement;

	toplevel_statement = (L_toplevel_statement *)ckalloc(sizeof(L_toplevel_statement));
	toplevel_statement->kind = kind;
	toplevel_statement->next = next;
	((L_ast_node *)toplevel_statement)->_trace = ast_trace_root;
	ast_trace_root = (void *)toplevel_statement;
	((L_ast_node *)toplevel_statement)->line_no = L_line_number;
	((L_ast_node *)toplevel_statement)->type = L_NODE_TOPLEVEL_STATEMENT;
	return toplevel_statement;
}

L_function_declaration *mk_function_declaration(L_expression *name,L_variable_declaration *params,L_type *return_type,L_block *body) 
{
	L_function_declaration *function_declaration;

	function_declaration = (L_function_declaration *)ckalloc(sizeof(L_function_declaration));
	function_declaration->name = name;
	function_declaration->params = params;
	function_declaration->return_type = return_type;
	function_declaration->body = body;
	((L_ast_node *)function_declaration)->_trace = ast_trace_root;
	ast_trace_root = (void *)function_declaration;
	((L_ast_node *)function_declaration)->line_no = L_line_number;
	((L_ast_node *)function_declaration)->type = L_NODE_FUNCTION_DECLARATION;
	return function_declaration;
}

L_variable_declaration *mk_variable_declaration(L_type *type,L_expression *name,L_expression *initial_value,L_variable_declaration *next) 
{
	L_variable_declaration *variable_declaration;

	variable_declaration = (L_variable_declaration *)ckalloc(sizeof(L_variable_declaration));
	variable_declaration->type = type;
	variable_declaration->name = name;
	variable_declaration->initial_value = initial_value;
	variable_declaration->next = next;
	((L_ast_node *)variable_declaration)->_trace = ast_trace_root;
	ast_trace_root = (void *)variable_declaration;
	((L_ast_node *)variable_declaration)->line_no = L_line_number;
	((L_ast_node *)variable_declaration)->type = L_NODE_VARIABLE_DECLARATION;
	return variable_declaration;
}

L_block *mk_block(L_variable_declaration *decls,L_statement *body) 
{
	L_block *block;

	block = (L_block *)ckalloc(sizeof(L_block));
	block->decls = decls;
	block->body = body;
	((L_ast_node *)block)->_trace = ast_trace_root;
	ast_trace_root = (void *)block;
	((L_ast_node *)block)->line_no = L_line_number;
	((L_ast_node *)block)->type = L_NODE_BLOCK;
	return block;
}

L_expression *mk_expression(L_expression_kind kind,int op,L_expression *a,L_expression *b,L_expression *c,L_expression *indices,L_expression *next) 
{
	L_expression *expression;

	expression = (L_expression *)ckalloc(sizeof(L_expression));
	expression->kind = kind;
	expression->op = op;
	expression->a = a;
	expression->b = b;
	expression->c = c;
	expression->indices = indices;
	expression->next = next;
	((L_ast_node *)expression)->_trace = ast_trace_root;
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
	((L_ast_node *)if_unless)->_trace = ast_trace_root;
	ast_trace_root = (void *)if_unless;
	((L_ast_node *)if_unless)->line_no = L_line_number;
	((L_ast_node *)if_unless)->type = L_NODE_IF_UNLESS;
	return if_unless;
}

