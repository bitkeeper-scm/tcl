/* This is an automatically generated file, please do not edit */
/* use: tclsh gen-l-ast2.tcl to regenerate */
#include "tclInt.h"
#include "Last.h"

extern void *ast_trace_root;
extern int L_line_number;
extern int L_token_offset;

char *L_expression_tostr[14] = {
	"L_EXPRESSION_ARRAY_INDEX",
	"L_EXPRESSION_BINARY",
	"L_EXPRESSION_FLOTE",
	"L_EXPRESSION_FUNCALL",
	"L_EXPRESSION_HASH_INDEX",
	"L_EXPRESSION_INTEGER",
	"L_EXPRESSION_INTERPOLATED_STRING",
	"L_EXPRESSION_POST",
	"L_EXPRESSION_PRE",
	"L_EXPRESSION_STRING",
	"L_EXPRESSION_STRUCT_INDEX",
	"L_EXPRESSION_TERTIARY",
	"L_EXPRESSION_UNARY",
	"L_EXPRESSION_VARIABLE"
};

char *L_loop_tostr[3] = {
	"L_LOOP_DO",
	"L_LOOP_FOR",
	"L_LOOP_WHILE"
};

char *L_statement_tostr[9] = {
	"L_STATEMENT_BLOCK",
	"L_STATEMENT_BREAK",
	"L_STATEMENT_COND",
	"L_STATEMENT_CONTINUE",
	"L_STATEMENT_DECL",
	"L_STATEMENT_EXPR",
	"L_STATEMENT_FOREACH",
	"L_STATEMENT_LOOP",
	"L_STATEMENT_RETURN"
};

char *L_toplevel_statement_tostr[5] = {
	"L_TOPLEVEL_STATEMENT_FUN",
	"L_TOPLEVEL_STATEMENT_GLOBAL",
	"L_TOPLEVEL_STATEMENT_STMT",
	"L_TOPLEVEL_STATEMENT_TYPE",
	"L_TOPLEVEL_STATEMENT_TYPEDEF"
};

char *L_type_tostr[9] = {
	"L_TYPE_ARRAY",
	"L_TYPE_FLOAT",
	"L_TYPE_HASH",
	"L_TYPE_INT",
	"L_TYPE_POLY",
	"L_TYPE_STRING",
	"L_TYPE_STRUCT",
	"L_TYPE_VAR",
	"L_TYPE_VOID"
};

char *L_node_type_tostr[11] = {
	"L_NODE_BLOCK",
	"L_NODE_EXPRESSION",
	"L_NODE_FOREACH_LOOP",
	"L_NODE_FUNCTION_DECLARATION",
	"L_NODE_IF_UNLESS",
	"L_NODE_INITIALIZER",
	"L_NODE_LOOP",
	"L_NODE_STATEMENT",
	"L_NODE_TOPLEVEL_STATEMENT",
	"L_NODE_TYPE",
	"L_NODE_VARIABLE_DECLARATION"
};


/* constructors for the L language */
L_block *mk_block(L_variable_declaration *decls,L_statement *body) 
{
	L_block *block;

	block = (L_block *)ckalloc(sizeof(L_block));
	memset(block, 0, sizeof(L_block));
	block->body = body;
	block->decls = decls;
	((L_ast_node *)block)->_trace = ast_trace_root;
	ast_trace_root = (void *)block;
	((L_ast_node *)block)->line_no = L_line_number;
	((L_ast_node *)block)->offset = L_token_offset;
	((L_ast_node *)block)->type = L_NODE_BLOCK;
	return block;
}

L_expression *mk_expression(L_expression_kind kind,int op,L_expression *a,L_expression *b,L_expression *c,L_expression *indices,L_expression *next) 
{
	L_expression *expression;

	expression = (L_expression *)ckalloc(sizeof(L_expression));
	memset(expression, 0, sizeof(L_expression));
	expression->a = a;
	expression->b = b;
	expression->c = c;
	expression->indices = indices;
	expression->next = next;
	expression->kind = kind;
	expression->op = op;
	((L_ast_node *)expression)->_trace = ast_trace_root;
	ast_trace_root = (void *)expression;
	((L_ast_node *)expression)->line_no = L_line_number;
	((L_ast_node *)expression)->offset = L_token_offset;
	((L_ast_node *)expression)->type = L_NODE_EXPRESSION;
	return expression;
}

L_foreach_loop *mk_foreach_loop(L_expression *hash,L_expression *key,L_expression *value,L_statement *body) 
{
	L_foreach_loop *foreach_loop;

	foreach_loop = (L_foreach_loop *)ckalloc(sizeof(L_foreach_loop));
	memset(foreach_loop, 0, sizeof(L_foreach_loop));
	foreach_loop->hash = hash;
	foreach_loop->key = key;
	foreach_loop->value = value;
	foreach_loop->body = body;
	((L_ast_node *)foreach_loop)->_trace = ast_trace_root;
	ast_trace_root = (void *)foreach_loop;
	((L_ast_node *)foreach_loop)->line_no = L_line_number;
	((L_ast_node *)foreach_loop)->offset = L_token_offset;
	((L_ast_node *)foreach_loop)->type = L_NODE_FOREACH_LOOP;
	return foreach_loop;
}

L_function_declaration *mk_function_declaration(L_expression *name,L_variable_declaration *params,L_type *return_type,L_block *body) 
{
	L_function_declaration *function_declaration;

	function_declaration = (L_function_declaration *)ckalloc(sizeof(L_function_declaration));
	memset(function_declaration, 0, sizeof(L_function_declaration));
	function_declaration->body = body;
	function_declaration->name = name;
	function_declaration->return_type = return_type;
	function_declaration->params = params;
	((L_ast_node *)function_declaration)->_trace = ast_trace_root;
	ast_trace_root = (void *)function_declaration;
	((L_ast_node *)function_declaration)->line_no = L_line_number;
	((L_ast_node *)function_declaration)->offset = L_token_offset;
	((L_ast_node *)function_declaration)->type = L_NODE_FUNCTION_DECLARATION;
	return function_declaration;
}

L_if_unless *mk_if_unless(L_expression *condition,L_statement *if_body,L_statement *else_body) 
{
	L_if_unless *if_unless;

	if_unless = (L_if_unless *)ckalloc(sizeof(L_if_unless));
	memset(if_unless, 0, sizeof(L_if_unless));
	if_unless->condition = condition;
	if_unless->else_body = else_body;
	if_unless->if_body = if_body;
	((L_ast_node *)if_unless)->_trace = ast_trace_root;
	ast_trace_root = (void *)if_unless;
	((L_ast_node *)if_unless)->line_no = L_line_number;
	((L_ast_node *)if_unless)->offset = L_token_offset;
	((L_ast_node *)if_unless)->type = L_NODE_IF_UNLESS;
	return if_unless;
}

L_initializer *mk_initializer(L_expression *key,L_expression *value,L_initializer *next_dim,L_initializer *next) 
{
	L_initializer *initializer;

	initializer = (L_initializer *)ckalloc(sizeof(L_initializer));
	memset(initializer, 0, sizeof(L_initializer));
	initializer->key = key;
	initializer->value = value;
	initializer->next = next;
	initializer->next_dim = next_dim;
	((L_ast_node *)initializer)->_trace = ast_trace_root;
	ast_trace_root = (void *)initializer;
	((L_ast_node *)initializer)->line_no = L_line_number;
	((L_ast_node *)initializer)->offset = L_token_offset;
	((L_ast_node *)initializer)->type = L_NODE_INITIALIZER;
	return initializer;
}

L_loop *mk_loop(L_loop_kind kind,L_expression *pre,L_expression *condition,L_expression *post,L_statement *body) 
{
	L_loop *loop;

	loop = (L_loop *)ckalloc(sizeof(L_loop));
	memset(loop, 0, sizeof(L_loop));
	loop->condition = condition;
	loop->post = post;
	loop->pre = pre;
	loop->kind = kind;
	loop->body = body;
	((L_ast_node *)loop)->_trace = ast_trace_root;
	ast_trace_root = (void *)loop;
	((L_ast_node *)loop)->line_no = L_line_number;
	((L_ast_node *)loop)->offset = L_token_offset;
	((L_ast_node *)loop)->type = L_NODE_LOOP;
	return loop;
}

L_statement *mk_statement(L_statement_kind kind,L_statement *next) 
{
	L_statement *statement;

	statement = (L_statement *)ckalloc(sizeof(L_statement));
	memset(statement, 0, sizeof(L_statement));
	statement->next = next;
	statement->kind = kind;
	((L_ast_node *)statement)->_trace = ast_trace_root;
	ast_trace_root = (void *)statement;
	((L_ast_node *)statement)->line_no = L_line_number;
	((L_ast_node *)statement)->offset = L_token_offset;
	((L_ast_node *)statement)->type = L_NODE_STATEMENT;
	return statement;
}

L_toplevel_statement *mk_toplevel_statement(L_toplevel_statement_kind kind,L_toplevel_statement *next) 
{
	L_toplevel_statement *toplevel_statement;

	toplevel_statement = (L_toplevel_statement *)ckalloc(sizeof(L_toplevel_statement));
	memset(toplevel_statement, 0, sizeof(L_toplevel_statement));
	toplevel_statement->next = next;
	toplevel_statement->kind = kind;
	((L_ast_node *)toplevel_statement)->_trace = ast_trace_root;
	ast_trace_root = (void *)toplevel_statement;
	((L_ast_node *)toplevel_statement)->line_no = L_line_number;
	((L_ast_node *)toplevel_statement)->offset = L_token_offset;
	((L_ast_node *)toplevel_statement)->type = L_NODE_TOPLEVEL_STATEMENT;
	return toplevel_statement;
}

L_type *mk_type(L_type_kind kind,L_expression *array_dim,L_expression *struct_tag,L_type *next_dim,L_variable_declaration *members,int typedef_p) 
{
	L_type *type;

	type = (L_type *)ckalloc(sizeof(L_type));
	memset(type, 0, sizeof(L_type));
	type->array_dim = array_dim;
	type->struct_tag = struct_tag;
	type->next_dim = next_dim;
	type->kind = kind;
	type->members = members;
	type->typedef_p = typedef_p;
	((L_ast_node *)type)->_trace = ast_trace_root;
	ast_trace_root = (void *)type;
	((L_ast_node *)type)->line_no = L_line_number;
	((L_ast_node *)type)->offset = L_token_offset;
	((L_ast_node *)type)->type = L_NODE_TYPE;
	return type;
}

L_variable_declaration *mk_variable_declaration(L_type *type,L_expression *name,L_initializer *initial_value,int by_name,int extern_p,L_variable_declaration *next) 
{
	L_variable_declaration *variable_declaration;

	variable_declaration = (L_variable_declaration *)ckalloc(sizeof(L_variable_declaration));
	memset(variable_declaration, 0, sizeof(L_variable_declaration));
	variable_declaration->name = name;
	variable_declaration->initial_value = initial_value;
	variable_declaration->type = type;
	variable_declaration->next = next;
	variable_declaration->by_name = by_name;
	variable_declaration->extern_p = extern_p;
	((L_ast_node *)variable_declaration)->_trace = ast_trace_root;
	ast_trace_root = (void *)variable_declaration;
	((L_ast_node *)variable_declaration)->line_no = L_line_number;
	((L_ast_node *)variable_declaration)->offset = L_token_offset;
	((L_ast_node *)variable_declaration)->type = L_NODE_VARIABLE_DECLARATION;
	return variable_declaration;
}

