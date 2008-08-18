%{
/*
 * Copyright (c) 2006-2007 BitMover, Inc.
 */
#include <stdio.h>
#include "Lcompile.h"
#include "tclInt.h"
#include "tclCompile.h"

/* L_lex is generated by lex */
int	L_lex (void);

extern int L_interactive;
extern void *L_current_ast;

extern	Tcl_Obj *stringBuf;

#define YYERROR_VERBOSE

private L_var_decl *
finish_decl(L_type *base_type, L_var_decl *decl)
{
	REVERSE(L_type, next_dim, decl->type);

	/* In cases where there are multiple variables declared like so:
	 *
	 *	int foo[2], bar;
	 *
	 * the parser gets the type of bar from foo.  So the "base
	 * type" of bar can have array dimensions, even though you
	 * would expect it to be just "int".  We step over the array
	 * dimensions to get to the true base type.
	 *
	 * (Note that we /do/ want to copy typedef dimensions.  This
	 * works because the typedef dimensions will always come after
	 * dimensions that don't come from a typedef).
	 */
	while ((base_type->kind == L_TYPE_ARRAY) && !base_type->typedef_p) {
		base_type = base_type->next_dim;
	}
	if (decl->type) {
		APPEND(L_type, next_dim, decl->type, base_type);
	} else {
		decl->type = base_type;
	}
	return (decl);
}

private void
pattern_funcall_rewrite(L_expr *funcall)
{
	L_expr	*newName, *firstArg;

	/* If the function call matches a pattern function, call the
	 * pattern function, passing the part of the function name
	 * after the underscore as the first parameter. */
	if (L_lookup_pattern_func(funcall->a->u.string, &newName, &firstArg)) {
		funcall->a = newName;
		firstArg->next = funcall->b;
		funcall->b = firstArg;
	}
}

%}

/*
 * We need a GLR parser because of a shift/reduce conflict introduced
 * by hash-element types.  This production is the culprit:
 *
 * fundecl_hasharray: "{" scalar_type_specifier "}"
 *
 * This introduced a shift/reduce conflict on "{" due to "{" being in
 * the FOLLOW set of scalar_type_specifier because "{" can follow
 * type_specifier in function_declaration.  For example, after you
 * have seen
 *
 *    struct s
 *
 * and "{" is the next token, the parser can't tell whether to shift
 * and proceed to parse a struct_specifier that declares a struct:
 *
 *    struct s { int x,y; }
 *
 * or whether to reduce and proceed in to a fundecl_hasharray:
 *
 *    struct s { int } f() {}
 *
 * To make this grammar LALR(1) seemed difficult.  The grammar seems
 * to want to be LALR(3) perhaps(?).  The best we could do was to extend
 * the language by pushing the fundecl_hasharray syntax down into
 * scalar_type_specifier and struct_specifier.  This would allow
 * inputs that should be syntax errors, so extra checking would have
 * been needed to detect these cases.
 *
 * The GLR parser has no problem with this type of conflict and keeps
 * the grammar nice.
 *
 */
%glr-parser
%expect 1

%token T_LPAREN "("
%token T_RPAREN ")"
%token T_LBRACE "{"
%token T_RBRACE "}"
%token T_LBRACKET "["
%token T_RBRACKET "]"
%token T_SEMI ";"
%token T_EQTWID "=~"
%token T_IF "if"
%token T_UNLESS "unless"
%nonassoc T_ELSE "else"
%token T_RETURN "return"
%token T_EXTERN
%token T_COMMA ","

%right T_EQUALS T_EQPLUS T_EQMINUS T_EQSTAR T_EQSLASH T_EQPERC
       T_EQBITAND T_EQBITOR T_EQBITXOR T_EQLSHIFT T_EQRSHIFT

%token T_ARROW "=>" T_LEFT_INTERPOL T_RIGHT_INTERPOL T_KEYWORD
%token T_WHILE T_FOR T_DO T_STRUCT T_TYPEDEF T_TYPE T_DEFINED
%token T_ID T_STR_LITERAL T_INT_LITERAL T_FLOAT_LITERAL
%token T_POLY T_VOID T_VAR T_STRING T_INT T_FLOAT T_WIDGET
%token T_FOREACH T_IN T_BREAK T_CONTINUE T_ELLIPSIS T_CLASS
%token T_INCLUDE T_PATTERN T_PUSH T_SPLIT

%token T_RE T_SUBST T_RE_MODIFIER

%left T_OROR
%left T_ANDAND
%left T_BITOR
%left T_BITXOR
%left T_BITAND
%left T_EQ T_NE T_EQUALEQUAL T_NOTEQUAL T_EQTWID
%left T_GT T_GE T_LT T_LE T_GREATER T_GREATEREQ T_LESSTHAN T_LESSTHANEQ
%left T_LSHIFT T_RSHIFT
%left T_PLUS T_MINUS
%left T_STAR T_SLASH T_PERC
%right T_BANG T_PLUSPLUS T_MINUSMINUS UMINUS UPLUS T_BITNOT ADDRESS
%right T_STRING_CAST T_TCL_CAST T_FLOAT_CAST T_INT_CAST T_HASH_CAST
%right T_WIDGET_CAST
%left T_DOT

%%

start:	  toplevel_code
	{
		REVERSE(L_toplevel, next, $1);
		L_current_ast = $1;
	}
	;

toplevel_code:
	  toplevel_code function_decl
	{
		$$ = mk_toplevel(L_TOPLEVEL_FUN, $1);
		((L_toplevel *)$$)->u.fun = $2;
	}
	| toplevel_code struct_specifier ";"
	{
		$$ = mk_toplevel(L_TOPLEVEL_TYPE, $1);
		((L_toplevel *)$$)->u.type = $2;
	}
	| toplevel_code T_TYPEDEF type_specifier declarator ";"
	{
		L_var_decl *typedecl = finish_decl($3, $4);
		L_store_typedef(typedecl->name, typedecl->type);
		$$ = mk_toplevel(L_TOPLEVEL_TYPEDEF, $1);
	}
	| toplevel_code declaration
	{
		// Global variables
		$$ = mk_toplevel(L_TOPLEVEL_GLOBAL, $1);
		((L_toplevel *)$$)->u.global = $2;
	}
	| toplevel_code stmt
	{
		// regular code that does stuff instead of just declaring it
		$$ = mk_toplevel(L_TOPLEVEL_STMT, $1);
		((L_toplevel *)$$)->u.stmt = $2;
	}
	| toplevel_code T_INCLUDE "(" T_STR_LITERAL ")" ";"
	{
		$$ = mk_toplevel(L_TOPLEVEL_INC, $1);
		((L_toplevel *)$$)->u.inc = $4;

	}
	| /* epsilon */		{ $$ = NULL; }
	;

function_decl:
	  type_specifier fundecl_hasharray fundecl_tail
	{
		((L_type *)$2)->next_dim = $1;
		((L_function_decl *)$3)->return_type = $2;
		$$ = $3;
	}
	| type_specifier fundecl_tail
	{
		((L_function_decl *)$2)->return_type = $1;
		$$ = $2;
	}
	| T_VOID fundecl_tail
	{
		((L_function_decl *)$2)->return_type =
		    mk_type(L_TYPE_VOID, NULL, NULL, NULL, NULL, FALSE);
		$$ = $2;
	}
	| fundecl_tail
	{
		((L_function_decl *)$1)->return_type =
		    mk_type(L_TYPE_VOID, NULL, NULL, NULL, NULL, FALSE);
		$$ = $1;
	}
	;

fundecl_hasharray:
	  fundecl_hasharray "[" "]"
	{
		L_expr *zero;

		MK_INT_NODE(zero, 0);
		$$ = mk_type(L_TYPE_ARRAY, zero, NULL, $1, NULL, FALSE);
	}
	| "[" "]"
	{
		L_expr *zero;

		MK_INT_NODE(zero, 0);
		$$ = mk_type(L_TYPE_ARRAY, zero, NULL, NULL, NULL, FALSE);
	}
	| fundecl_hasharray "{" scalar_type_specifier "}"
	{
		$$ = mk_type(L_TYPE_HASH, $3, NULL, $1, NULL, FALSE);
	}
	| "{" scalar_type_specifier "}"
	{
		$$ = mk_type(L_TYPE_HASH, $2, NULL, NULL, NULL, FALSE);
	}
	;

fundecl_tail:
	  T_ID fundecl_tail1
	{
		((L_function_decl *)$2)->name = $1;
		L_pattern_store_name($1);
		$$ = $2;
	}
	| T_PATTERN fundecl_tail1
	{
		L_function_decl *f = (L_function_decl *)$2;
		L_var_decl *param;
		L_type *t = mk_type(L_TYPE_STRING, NULL, NULL, NULL, NULL, FALSE);
		L_expr *param_name;

		f->pattern_p = TRUE;
		f->name = $1;
		L_pattern_store_name($1);
		$$ = f;
		/* tack on the first parameter, named "$1", which will get the
		 * value of the glob match */
		MK_STRING_NODE(param_name, "$1");
		param = mk_var_decl(t, param_name, NULL, FALSE, FALSE, FALSE, f->params);
		f->params = param;
	}

fundecl_tail1:
	  "(" parameter_list ")" compound_stmt
	{
		$$ = mk_function_decl(NULL, $2, NULL, ((L_stmt *)$4)->u.block, FALSE);
	}
	| "(" ")" compound_stmt
	{
		$$ = mk_function_decl(NULL, NULL, NULL, ((L_stmt *)$3)->u.block, FALSE);
	}

stmt:
	  single_stmt	{ $$ = $1; if (L_interactive) YYACCEPT; }
	| compound_stmt	{ $$ = $1; if (L_interactive) YYACCEPT; }
	;

single_stmt:
	  selection_stmt
	{
		$$ = mk_stmt(L_STMT_COND, NULL);
		((L_stmt *)$$)->u.cond = $1;
	}
	| iteration_stmt
	{
		$$ = mk_stmt(L_STMT_LOOP, NULL);
		((L_stmt *)$$)->u.loop = $1;
	}
	| foreach_stmt
	{
		$$ = mk_stmt(L_STMT_FOREACH, NULL);
		((L_stmt *)$$)->u.foreach = $1;
	}
	| push_stmt
	{
		$$ = mk_stmt(L_STMT_PUSH, NULL);
		((L_stmt *)$$)->u.expr = $1;
	}
	| expr ";"
	{
		$$ = mk_stmt(L_STMT_EXPR, NULL);
		((L_stmt *)$$)->u.expr = $1;
	}
	| T_BREAK ";"
	{
		$$ = mk_stmt(L_STMT_BREAK, NULL);
	}
	| T_CONTINUE ";"
	{
		$$ = mk_stmt(L_STMT_CONTINUE, NULL);
	}
	| T_RETURN ";"
	{
		$$ = mk_stmt(L_STMT_RETURN, NULL);
	}
	| T_RETURN expr ";"
	{
		$$ = mk_stmt(L_STMT_RETURN, NULL);
		((L_stmt *)$$)->u.expr = $2;
	}
	| ";"	{ $$ = NULL; }
	;

selection_stmt:
	  T_IF "(" expr ")" compound_stmt optional_else
	{
		$$ = mk_if_unless($3, $5, $6);
	}
	/* if you have no curly braces, you get no else. */
	| T_IF "(" expr ")" single_stmt
	{
		$$ = mk_if_unless($3, $5, NULL);
	}
	/* analogous to the if statements. the unless statements
	   differ only by the true value passed to L_if_condition */
	| T_UNLESS "(" expr ")" compound_stmt optional_else
	{
		$$ = mk_if_unless($3, $6, $5);
	}
	| T_UNLESS "(" expr ")" single_stmt
	{
		$$ = mk_if_unless($3, NULL, $5);
	}
	;


optional_else:
	/* else clauses must either have curly braces or be another
	   if/unless */
	  T_ELSE compound_stmt	{ $$ = $2; }
	| T_ELSE selection_stmt
	{
		$$ = mk_stmt(L_STMT_COND, NULL);
		((L_stmt *)$$)->u.cond = $2;
	}
	| /* epsilon */			{ $$ = NULL; }
	;

iteration_stmt:
	  T_WHILE "(" expr ")" stmt
	{
		$$ = mk_loop(L_LOOP_WHILE, NULL, $3, NULL, $5);
	}
	| T_DO stmt T_WHILE "(" expr ")" ";"
	{
		$$ = mk_loop(L_LOOP_DO, NULL, $5, NULL, $2);
	}
	| T_FOR "(" expression_stmt expression_stmt ")" stmt
	{
		$$ = mk_loop(L_LOOP_FOR, $3, $4, NULL, $6);
	}
	| T_FOR "(" expression_stmt expression_stmt expr ")" stmt
	{
		$$ = mk_loop(L_LOOP_FOR, $3, $4, $5, $7);
	}
	;

foreach_stmt:
	  T_FOREACH "(" T_ID T_ARROW T_ID T_IN expr ")" stmt
	{
		$$ = mk_foreach_loop($7, $3, $5, $9);
	}
	| T_FOREACH "(" id_list T_IN expr ")" stmt
	{
		$$ = mk_foreach_loop($5, $3, NULL, $7);
	}
	;


push_stmt:
	  T_PUSH "(" T_BITAND T_ID "," expr ")" ";"
	{
		$$ = mk_expr(L_EXPR_PUSH, -1, $4, $6, NULL, NULL,
					NULL);
	}
	;


expression_stmt
	: ";"			{ $$ = NULL; }
	| expr ";"
	;

stmt_list:
	  stmt
	| stmt_list stmt	{ ((L_stmt *)$2)->next = $1; $$ = $2; }
	;


parameter_list:
	  parameter_decl_list
	{
		REVERSE(L_var_decl, next, $1);
		$$ = $1;
	}
	| T_VOID			{ $$ = NULL; }
	;

parameter_decl_list:
	  parameter_decl
	| parameter_decl_list "," parameter_decl
	{
		((L_var_decl *)$3)->next = $1;
		$$ = $3;
	}
	;

parameter_decl:
	  type_specifier declarator
	{
		$$ = finish_decl($1, $2);
	}
	| type_specifier T_BITAND declarator
	{
		$$ = finish_decl($1, $3);
		((L_var_decl *)$$)->by_name = TRUE;
	}
	| T_ELLIPSIS T_ID
	{
		L_expr *zero;
		L_type *type;

		MK_INT_NODE(zero, 0);
		type = mk_type(L_TYPE_ARRAY, zero, NULL,
		    mk_type(L_TYPE_POLY, NULL, NULL, NULL, NULL, FALSE), NULL, FALSE);
		$$ = mk_var_decl(type, $2, NULL, FALSE, FALSE, TRUE, NULL);
	}
	;

argument_expr_list:
	  expr
	| regexp_literal	{ REVERSE(L_expr, c, $1); }
	| T_KEYWORD
	| T_KEYWORD expr
	{
		((L_expr *)$2)->next = $1;
		$$ = $2;
	}
	| argument_expr_list "," expr
	{
		((L_expr *)$3)->next = $1;
		$$ = $3;
	}
	| argument_expr_list "," regexp_literal
	{
		REVERSE(L_expr, c, $3);
		((L_expr *)$3)->next = $1;
		$$ = $3;
	}
	| argument_expr_list "," T_KEYWORD
	{
		((L_expr *)$3)->next = $1;
		$$ = $3;
	}
	| argument_expr_list "," T_KEYWORD expr
	{
		((L_expr *)$4)->next = $3;
		((L_expr *)$3)->next = $1;
		$$ = $4;
	}
	;

expr:
	  "(" expr ")"		{ $$ = $2; }
	| T_STRING_CAST expr
	{
		$$ = mk_expr(L_EXPR_UNARY, T_STRING_CAST, $2,
				   NULL, NULL, NULL, NULL);
	}
	| T_TCL_CAST expr
	{
		$$ = mk_expr(L_EXPR_UNARY, T_TCL_CAST, $2,
				   NULL, NULL, NULL, NULL);
	}
	| T_FLOAT_CAST expr
	{
		$$ = mk_expr(L_EXPR_UNARY, T_FLOAT_CAST, $2,
				   NULL, NULL, NULL, NULL);
	}
	| T_HASH_CAST expr
	{
		$$ = mk_expr(L_EXPR_UNARY, T_HASH_CAST, $2,
				   NULL, NULL, NULL, NULL);
	}
	| T_INT_CAST expr
	{
		$$ = mk_expr(L_EXPR_UNARY, T_INT_CAST, $2,
				   NULL, NULL, NULL, NULL);
	}
	| T_WIDGET_CAST expr
	{
		$$ = mk_expr(L_EXPR_UNARY, T_WIDGET_CAST, $2,
				   NULL, NULL, NULL, NULL);
	}
	| T_BANG expr
	{
		$$ = mk_expr(L_EXPR_UNARY, T_BANG, $2, NULL, NULL, NULL, NULL);
	}
	| T_BITNOT expr
	{
		$$ = mk_expr(L_EXPR_UNARY, T_BITNOT, $2, NULL, NULL, NULL, NULL);
	}
	| T_BITAND lvalue %prec ADDRESS
	{
		REVERSE(L_expr, indices, $2);
		$$ = mk_expr(L_EXPR_UNARY, T_BITAND, $2, NULL, NULL, NULL, NULL);
	}
	| T_MINUS expr %prec UMINUS
	{
		$$ = mk_expr(L_EXPR_UNARY, T_MINUS, $2, NULL, NULL, NULL, NULL);
	}
	| T_PLUS expr %prec UPLUS
	{
		$$ = mk_expr(L_EXPR_UNARY, T_PLUS, $2, NULL, NULL, NULL, NULL);
	}
	| T_PLUSPLUS lvalue
	{
		REVERSE(L_expr, indices, $2);
		$$ = mk_expr(L_EXPR_PRE, T_PLUSPLUS, $2, NULL, NULL, NULL, NULL);
	}
	| T_MINUSMINUS lvalue
	{
		REVERSE(L_expr, indices, $2);
		$$ = mk_expr(L_EXPR_PRE, T_MINUSMINUS, $2, NULL, NULL, NULL, NULL);
	}
	| lvalue T_PLUSPLUS
	{
		REVERSE(L_expr, indices, $1);
		$$ = mk_expr(L_EXPR_POST, T_PLUSPLUS, $1, NULL, NULL, NULL, NULL);
	}
	| lvalue T_MINUSMINUS
	{
		REVERSE(L_expr, indices, $1);
		$$ = mk_expr(L_EXPR_POST, T_MINUSMINUS, $1, NULL, NULL, NULL, NULL);
	}
	| expr T_EQTWID regexp_literal T_RE_MODIFIER
	{
		L_expr *regexp;

		REVERSE(L_expr, c, $3);
		regexp = mk_expr(L_EXPR_REGEXP, -1, $3, NULL, $4, NULL, NULL);
		MK_BINOP_NODE($$, T_EQTWID, $1, regexp);
	}
	| expr T_EQTWID regexp_literal subst_literal T_RE_MODIFIER
	{
		L_expr *regexp;

		REVERSE(L_expr, c, $3);
		regexp = mk_expr(L_EXPR_REGEXP, -1, $3, $4, $5, NULL, NULL);
		MK_BINOP_NODE($$, T_EQTWID, $1, regexp);
	}
	| expr T_STAR expr	{ MK_BINOP_NODE($$, T_STAR, $1, $3); }
	| expr T_SLASH expr	{ MK_BINOP_NODE($$, T_SLASH, $1, $3); }
	| expr T_PERC expr	{ MK_BINOP_NODE($$, T_PERC, $1, $3); }
	| expr T_PLUS expr	{ MK_BINOP_NODE($$, T_PLUS, $1, $3); }
	| expr T_MINUS expr	{ MK_BINOP_NODE($$, T_MINUS, $1, $3); }
	| expr T_EQ expr	{ MK_BINOP_NODE($$, T_EQ, $1, $3); }
	| expr T_NE expr	{ MK_BINOP_NODE($$, T_NE, $1, $3); }
	| expr T_LT expr	{ MK_BINOP_NODE($$, T_LT, $1, $3); }
	| expr T_LE expr	{ MK_BINOP_NODE($$, T_LE, $1, $3); }
	| expr T_GT expr	{ MK_BINOP_NODE($$, T_GT, $1, $3); }
	| expr T_GE expr	{ MK_BINOP_NODE($$, T_GE, $1, $3); }
	| expr T_EQUALEQUAL expr	{ MK_BINOP_NODE($$, T_EQUALEQUAL, $1, $3); }
	| expr T_NOTEQUAL expr	{ MK_BINOP_NODE($$, T_NOTEQUAL, $1, $3); }
	| expr T_GREATER expr	{ MK_BINOP_NODE($$, T_GREATER, $1, $3); }
	| expr T_GREATEREQ expr { MK_BINOP_NODE($$, T_GREATEREQ, $1, $3); }
	| expr T_LESSTHAN expr	{ MK_BINOP_NODE($$, T_LESSTHAN, $1, $3); }
	| expr T_LESSTHANEQ expr	{ MK_BINOP_NODE($$, T_LESSTHANEQ, $1, $3); }
	| expr T_ANDAND expr	{ MK_BINOP_NODE($$, T_ANDAND, $1, $3); }
	| expr T_OROR expr	{ MK_BINOP_NODE($$, T_OROR, $1, $3); }
	| expr T_LSHIFT expr	{ MK_BINOP_NODE($$, T_LSHIFT, $1, $3); }
	| expr T_RSHIFT expr	{ MK_BINOP_NODE($$, T_RSHIFT, $1, $3); }
	| expr T_BITOR expr	{ MK_BINOP_NODE($$, T_BITOR, $1, $3); }
	| expr T_BITAND expr	{ MK_BINOP_NODE($$, T_BITAND, $1, $3); }
	| expr T_BITXOR expr	{ MK_BINOP_NODE($$, T_BITXOR, $1, $3); }
	| string_literal	{ REVERSE(L_expr, c, $1); $$ = $1; }
	| T_INT_LITERAL
	| T_FLOAT_LITERAL
	| lvalue		{ REVERSE(L_expr, indices, $1); $$ = $1; }
	| T_ID "(" argument_expr_list ")"
	{
		REVERSE(L_expr, next, $3);
		$$ = mk_expr(L_EXPR_FUNCALL, -1, $1, $3, NULL, NULL, NULL);
		pattern_funcall_rewrite($$);
	}
	| T_STRING "(" argument_expr_list ")"
	{
		L_expr *id;
		MK_STRING_NODE(id, "string")
		REVERSE(L_expr, next, $3);
		$$ = mk_expr(L_EXPR_FUNCALL, -1, id, $3, NULL, NULL, NULL);
	}
	| T_ID "(" ")"
	{
		$$ = mk_expr(L_EXPR_FUNCALL, -1, $1, NULL, NULL, NULL, NULL);
		pattern_funcall_rewrite($$);
	}
	/*
	 * L_lex_start_re_arg() and L_lex_end_re_arg() tell the
	 * scanner to start or stop recognizing a regexp.
	 */
	| T_SPLIT "(" expr
	  { L_lex_start_re_arg(); }
	  "," re_or_string
	  { L_lex_end_re_arg(); }
	  opt_arg ")"
	{
		((L_expr *)$3)->next = $6;
		((L_expr *)$6)->next = $8;
		$$ = mk_expr(L_EXPR_FUNCALL, -1, $1, $3, NULL, NULL, NULL);
	}
	| T_SPLIT "(" expr ")"
	{
		$$ = mk_expr(L_EXPR_FUNCALL, -1, $1, $3, NULL, NULL, NULL);
	}
	/* this is to allow calling Tk widget functions */
	| dotted_id "(" argument_expr_list ")"
	{
		REVERSE(L_expr, next, $3);
		$$ = mk_expr(L_EXPR_FUNCALL, -1, $1, $3, NULL, NULL, NULL);
	}
	| dotted_id "(" ")"
	{
		$$ = mk_expr(L_EXPR_FUNCALL, -1, $1, NULL, NULL, NULL, NULL);
	}
	| lvalue T_EQUALS expr
	{
		REVERSE(L_expr, indices, $1);
		$$ = mk_expr(L_EXPR_BINARY, T_EQUALS, $1, $3, NULL, NULL, NULL);
	}
	| lvalue T_EQPLUS expr
	{
		REVERSE(L_expr, indices, $1);
		$$ = mk_expr(L_EXPR_BINARY, T_EQPLUS, $1, $3, NULL, NULL, NULL);
	}
	| lvalue T_EQMINUS expr
	{
		REVERSE(L_expr, indices, $1);
		$$ = mk_expr(L_EXPR_BINARY, T_EQMINUS, $1, $3, NULL, NULL, NULL);
	}
	| lvalue T_EQSTAR expr
	{
		REVERSE(L_expr, indices, $1);
		$$ = mk_expr(L_EXPR_BINARY, T_EQSTAR, $1, $3, NULL, NULL, NULL);
	}
	| lvalue T_EQSLASH expr
	{
		REVERSE(L_expr, indices, $1);
		$$ = mk_expr(L_EXPR_BINARY, T_EQSLASH, $1, $3, NULL, NULL, NULL);
	}
	| lvalue T_EQPERC expr
	{
		REVERSE(L_expr, indices, $1);
		$$ = mk_expr(L_EXPR_BINARY, T_EQPERC, $1, $3, NULL, NULL, NULL);
	}
	| lvalue T_EQBITAND expr
	{
		REVERSE(L_expr, indices, $1);
		$$ = mk_expr(L_EXPR_BINARY, T_EQBITAND, $1, $3, NULL, NULL, NULL);
	}
	| lvalue T_EQBITOR expr
	{
		REVERSE(L_expr, indices, $1);
		$$ = mk_expr(L_EXPR_BINARY, T_EQBITOR, $1, $3, NULL, NULL, NULL);
	}
	| lvalue T_EQBITXOR expr
	{
		REVERSE(L_expr, indices, $1);
		$$ = mk_expr(L_EXPR_BINARY, T_EQBITXOR, $1, $3, NULL, NULL, NULL);
	}
	| lvalue T_EQLSHIFT expr
	{
		REVERSE(L_expr, indices, $1);
		$$ = mk_expr(L_EXPR_BINARY, T_EQLSHIFT, $1, $3, NULL, NULL, NULL);
	}
	| lvalue T_EQRSHIFT expr
	{
		REVERSE(L_expr, indices, $1);
		$$ = mk_expr(L_EXPR_BINARY, T_EQRSHIFT, $1, $3, NULL, NULL, NULL);
	}
	| T_DEFINED "(" expr ")"
	{
		$$ = mk_expr(L_EXPR_UNARY, T_DEFINED, $3, NULL, NULL, NULL, NULL);
	}
	;

opt_arg:
	 "," expr	{ $$ = $2; }
	|		{ $$ = NULL; }
	;

re_or_string:
	  regexp_literal	{ REVERSE(L_expr, c, $1); $$ = $1; }
	| string_literal	{ REVERSE(L_expr, c, $1); $$ = $1; }
	;

lvalue:
	  T_ID
	{
		$$ = mk_expr(L_EXPR_VAR, -1, $1, NULL, NULL, NULL, NULL);
	}
	| lvalue T_LBRACKET expr T_RBRACKET
	{
		$$ = mk_expr(L_EXPR_ARRAY_INDEX, -1, $3, NULL, NULL, $1, NULL);
	}
	| lvalue T_LBRACE expr T_RBRACE
	{
		$$ = mk_expr(L_EXPR_HASH_INDEX, -1, $3, NULL, NULL, $1, NULL);
	}
	| lvalue T_DOT T_ID
	{
		$$ = mk_expr(L_EXPR_STRUCT_INDEX, -1, $3, NULL, NULL, $1, NULL);
	}
	;

id_list:
	T_ID
	| T_ID "," id_list
	{
		((L_expr *)$1)->next = $3;
	}

compound_stmt:
	  "{" "}"
	{
		$$ = mk_stmt(L_STMT_BLOCK, NULL);
		((L_stmt *)$$)->u.block = mk_block(NULL, NULL);
	}
	| "{" stmt_list "}"
	{
		REVERSE(L_stmt, next, $2);
		$$ = mk_stmt(L_STMT_BLOCK, NULL);
		((L_stmt *)$$)->u.block = mk_block(NULL, $2);
	}
	| "{" declaration_list "}"
	{
		REVERSE(L_var_decl, next, $2);
		$$ = mk_stmt(L_STMT_BLOCK, NULL);
		((L_stmt *)$$)->u.block = mk_block($2, NULL);
	}
	| "{" declaration_list stmt_list "}"
	{
		REVERSE(L_var_decl, next, $2);
		REVERSE(L_stmt, next, $3);
		$$ = mk_stmt(L_STMT_BLOCK, NULL);
		((L_stmt *)$$)->u.block = mk_block($2, $3);
	}
	;

declaration_list:
	  declaration
	| declaration_list declaration
	{
	    /* Each declaration is a list of declarators.  Here we append
	       the lists. */
	    APPEND(L_var_decl, next, $2, $1);
	    $$ = $2;
	}
	;

declaration:
	  init_declarator_list ";"
	| T_EXTERN init_declarator_list ";"
	{
		L_var_decl *v;
		for (v = $2; v; v = v->next) {
			v->extern_p = TRUE;
		}
		$$ = $2;
	}
	;

init_declarator_list:
	  type_specifier init_declarator
	{
		$$ = finish_decl($1, $2);
	}
	| init_declarator_list "," init_declarator
	{
		$$ = finish_decl(((L_var_decl *)$1)->type, $3);
		((L_var_decl *)$$)->next = $1;
	}
	;

init_declarator:
	  declarator
	| declarator T_EQUALS initializer
	{
		((L_var_decl *)$1)->initial_value = $3;
		$$ = $1;
	}
	;

declarator:
	  T_ID
	{
		$$ = mk_var_decl(NULL, $1, NULL, FALSE, FALSE, FALSE, NULL);
	}
	| T_TYPE
	{
		$$ = mk_var_decl(NULL, $1, NULL, FALSE, FALSE, FALSE, NULL);
	}
	| declarator "[" constant_expr "]"
	{
		L_type *type =
			mk_type(L_TYPE_ARRAY, $3, NULL,
				((L_var_decl *)$1)->type, NULL,
				FALSE);
		((L_var_decl *)$1)->type = type;
		$$ = $1;
	}
	| declarator "[" "]"
	{
		L_expr *zero;

		MK_INT_NODE(zero, 0);
		((L_var_decl *)$1)->type =
		    mk_type(L_TYPE_ARRAY, zero, NULL,
			    ((L_var_decl *)$1)->type, NULL,
			    FALSE);
		$$ = $1;
	}
	| declarator "{" scalar_type_specifier "}"
        {
                ((L_var_decl *)$1)->type =
                    mk_type(L_TYPE_HASH, $3, NULL,
                            ((L_var_decl *)$1)->type, NULL,
                            FALSE);
                $$ = $1;
        }
	;

type_specifier:
	  scalar_type_specifier
        | struct_specifier
	;

scalar_type_specifier:
	  T_STRING	{ $$ = mk_type(L_TYPE_STRING, NULL, NULL, NULL, NULL, FALSE); }
	| T_INT		{ $$ = mk_type(L_TYPE_INT, NULL, NULL, NULL, NULL, FALSE); }
	| T_FLOAT	{ $$ = mk_type(L_TYPE_FLOAT, NULL, NULL, NULL, NULL, FALSE); }
	| T_POLY	{ $$ = mk_type(L_TYPE_POLY, NULL, NULL, NULL, NULL, FALSE); }
	| T_VAR		{ $$ = mk_type(L_TYPE_VAR, NULL, NULL, NULL, NULL, FALSE); }
	| T_WIDGET	{ $$ = mk_type(L_TYPE_WIDGET, NULL, NULL, NULL, NULL, FALSE); }
	| T_TYPE	{ $$ = L_lookup_typedef($1, TRUE); }
	;

struct_specifier:
	  T_STRUCT T_ID "{" struct_decl_list "}"
	{
		REVERSE(L_var_decl, next, $4);
		$$ = mk_type(L_TYPE_STRUCT, NULL, $2, NULL, $4, FALSE);
	}
	| T_STRUCT "{" struct_decl_list "}"
	{
		REVERSE(L_var_decl, next, $3);
		$$ = mk_type(L_TYPE_STRUCT, NULL, NULL, NULL, $3, FALSE);
	}
	| T_STRUCT T_ID
	{
		$$ = mk_type(L_TYPE_STRUCT, NULL, $2, NULL, NULL, FALSE);
	}
	;

struct_decl_list:
	  struct_decl
	| struct_decl_list struct_decl
	{
	    APPEND(L_var_decl, next, $2, $1);
	    $$ = $2;
	}
	;

struct_decl:
	  struct_declarator_list ";"
	;

struct_declarator_list:
	  type_specifier declarator
	{
		$$ = finish_decl($1, $2);
	}
	| struct_declarator_list "," declarator
	{
		$$ = finish_decl(((L_var_decl *)$1)->type, $3);
		((L_var_decl *)$$)->next = $1;
	}
	;

initializer:
	  expr		{ $$ = mk_initializer(NULL, $1, NULL, NULL); }
	| "{" initializer_list "}"
	{
		REVERSE(L_initializer, next, $2);
		$$ = mk_initializer(NULL, $2, NULL, NULL);
	}
	| "{" "}"	{ $$ = NULL; }
	;

initializer_list:
	  initializer_list_element
	| initializer_list T_COMMA initializer_list_element
	{
		((L_initializer *)$3)->next = $1;
		$$ = $3;
	}
	;

initializer_list_element:
	  initializer
	| expr "=>" initializer
	{
		$$ = mk_initializer($1, NULL, $3, NULL);
	}
	;

constant_expr:
	  expr
	;

string_literal:
	  T_STR_LITERAL
	| interpolated_expr T_STR_LITERAL
	{
		((L_expr *)$2)->c = $1;
		$$ = $2;
	}

regexp_literal:
	  T_RE
	| interpolated_expr T_RE
	{
		((L_expr *)$2)->c = $1;
		$$ = $2;
	}

subst_literal:
	  T_SUBST
	| interpolated_expr T_SUBST
	{
		((L_expr *)$2)->c = $1;
		$$ = $2;
	}

interpolated_expr:
	  T_LEFT_INTERPOL expr T_RIGHT_INTERPOL
	{
		$$ = mk_expr(L_EXPR_INTERPOLATED_STRING, -1, $1, $2,
				   NULL, NULL, NULL);
	}
	| interpolated_expr T_LEFT_INTERPOL expr T_RIGHT_INTERPOL
	{
		$$ = mk_expr(L_EXPR_INTERPOLATED_STRING, -1, $2, $3,
				   $1, NULL, NULL);
	}

dotted_id:
	  T_DOT
	{
		L_expr *id;
		MK_STRING_NODE(id, ".")
		$$ = id;
	}

	| dotted_id_1
	;


dotted_id_1:
	  T_DOT T_ID
	{
		L_expr *name = mk_expr(L_EXPR_STRING, -1,
						   NULL, NULL, NULL, NULL, NULL);
		char *id = ((L_expr *)$2)->u.string;

		name->u.string = ckalloc(strlen(id) + 2);
		*name->u.string = '.';
		strcpy(name->u.string + 1, id);
		$$ = name;
	}
	| dotted_id_1 T_DOT T_ID
	{
		char *id1 = ((L_expr *)$1)->u.string;
		char *id2 = ((L_expr *)$3)->u.string;
		int len1 = strlen(id1);
		L_expr *name = mk_expr(L_EXPR_STRING, -1,
						   NULL, NULL, NULL, NULL, NULL);

		name->u.string = ckalloc(len1 + 2 + strlen(id2));
		strcpy(name->u.string, id1);
		*(name->u.string + len1) = '.';
		strcpy(name->u.string + len1 + 1, id2);
		$$ = name;
	}
	;
%%
