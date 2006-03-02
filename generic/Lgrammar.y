%{
#include <stdio.h>
#include "Ltokens.h"
#include "Lcompile.h"
#include "tclInt.h"
#include "tclCompile.h"

%}

%token T_LPAREN "("
%token T_RPAREN ")"
%token T_LBRACE "{"
%token T_RBRACE "}"
%token T_BANG "!"
%token T_PLUS "+"
%token T_MINUS "-"
%token T_STAR "*"
%token T_SLASH "/"
%token T_PERC "%"
%token T_PLUSPLUS "++"
%token T_MINUSMINUS "--"
%token T_ANDAND "&&"
%token T_OROR "||"
%token T_EQUALS "="
%token T_SEMI ";"
%token T_BANGTWID "!~"
%token T_EQTWID "=~"
%token T_IF "if"
%token T_ELSE "else"
%token T_UNLESS "unless"
%token T_EQ "eq"
%token T_NE "ne"
%token T_LT "lt"
%token T_LE "le"
%token T_GT "gt"
%token T_GE "ge"
%token T_EQUALEQUAL "=="
%token T_NOTEQUAL "!="
%token T_GREATER ">"
%token T_GREATEREQ ">="
%token T_LESSTHAN "<"
%token T_LESSTHANEQ "<="
%token T_COMMA ","

%token T_ID T_STR T_RE
%token T_INT
%token T_FLOAT

%left T_OROR
%left T_ANDAND
%nonassoc T_EQ T_NE T_EQUALEQUAL T_NOTEQUAL T_EQTWID T_BANGTWID
%nonassoc T_GT T_GE T_LT T_LE T_GREATER T_GREATEREQ T_LESSTHAN T_LESSTHANEQ
%left T_PLUS T_MINUS
%left T_STAR T_SLASH T_PERC
%right T_BANG T_PLUSPLUS T_MINUSMINUS UMINUS
%nonassoc T_LPAREN T_RPAREN

%%

start:	  funclist	{ }
	;

funclist: funclist function_declaration	{ }
	|		{ }
	;

function_declaration:	
        T_ID { L_begin_function_decl(&$1); } "(" formal_parameter_list ")" "{" stmt_list "}"
                                { L_end_function_decl(&$1); }
	;

stmt_list: stmt_list stmt       { }
 	|		        { }
	;

stmt:	  "if" "(" expr ")" "{" stmt_list "}"
	| "if" "(" expr ")" "{" stmt_list "}" "else" "{" stmt_list "}"
	| "unless" "(" expr ")" "{" stmt_list "}"
	| "unless" "(" expr ")" "{" stmt_list "}" "else" "{" stmt_list "}"
        | T_ID { L_begin_function_call(&$1); } "(" actual_parameter_list ")" ";" 
                        { L_end_function_call(&$1, $4.v.i); }
	| T_ID "=" expr ";"	{ L_assignment(&$1, &$3); }
	;

formal_parameter_list: 
        formal_parameter_list "," T_ID { }
        | T_ID                  { $$ = $1 }
        |                       { }
        ;

actual_parameter_list: 
        actual_parameter_list "," expr	{ L_pass_parameter(&$3); $$.type = LTOKEN_INT; $$.v.i = $1.v.i + 1; }
	| expr			{ L_pass_parameter(&$1); $$.type = LTOKEN_INT; $$.v.i = 1; }
	|			{ $$.type = LTOKEN_INT; $$.v.i = 0; }
	;

expr:	/* "(" expr ")"		{ $$ = 1; } */
/* 	| "!" expr		{ $$ = 1; } */
/* 	| "-" expr %prec UMINUS	{ $$ = 1; } */
/* 	| "++" expr		{ $$ = 1; } */
/* 	| "--" expr		{ $$ = 1; } */
/* 	| expr "++"		{ $$ = 1; } */
/* 	| expr "--"		{ $$ = 1; } */
/* 	| expr "*" expr		{ $$ = 1; } */
/* 	| expr "/" expr		{ $$ = 1; } */
/* 	| expr "%" expr		{ $$ = 1; } */
/* 	| expr "+" expr		{ $$ = 1; } */
/* 	| expr "-" expr		{ $$ = 1; } */
/* 	| expr "lt" expr	{ $$ = 1; } */
/* 	| expr "le" expr	{ $$ = 1; } */
/* 	| expr "gt" expr	{ $$ = 1; } */
/* 	| expr "ge" expr	{ $$ = 1; } */
/* 	| expr "eq" expr	{ $$ = 1; } */
/* 	| expr "ne" expr	{ $$ = 1; } */
/* 	| expr "==" expr	{ $$ = 1; } */
/* 	| expr "!=" expr	{ $$ = 1; } */
/* 	| expr ">" expr		{ $$ = 1; } */
/* 	| expr ">=" expr	{ $$ = 1; } */
/* 	| expr "<" expr		{ $$ = 1; } */
/* 	| expr "<=" expr	{ $$ = 1; } */
/* 	| expr "=~" T_RE	{ $$ = 1; } */
/* 	| expr "!~" T_RE	{ $$ = 1; } */
/* 	| expr "&&" expr	{ $$ = 1; } */
/* 	| expr "||" expr	{ $$ = 1; } */
/*         |  */
        T_STR                 { $$ = $1; }
        | T_INT                 { $$ = $1; }
        | T_FLOAT               { $$ = $1; }
	| T_ID			{ $$ = $1; }
	;

%%

int
L_error(char *s)
{
	fprintf(stderr, "syntax error: %s\n", s);
	return 0;
}
