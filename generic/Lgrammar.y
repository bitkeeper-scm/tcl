%{
#include <stdio.h>
#include "Lcompile.h"
#include "tclInt.h"
#include "tclCompile.h"

/* L_lex is generated by lex */
int L_lex (void);

extern int L_interactive;
extern void *L_current_ast;

#define YYERROR_VERBOSE
%}

%token T_LPAREN "("
%token T_RPAREN ")"
%token T_LBRACE "{"
%token T_RBRACE "}"
%token T_LBRACKET "["
%token T_RBRACKET "]"
%token T_ANDAND "&&"
%token T_OROR "||"
%token T_SEMI ";"
%token T_BANGTWID "!~"
%token T_EQTWID "=~"
%token T_IF "if"
%token T_UNLESS "unless"
%nonassoc T_ELSE "else"
%token T_RETURN "return"

%token T_COMMA ","

%right T_EQUALS "="

%token T_EQ "eq"
%token T_NE "ne"
%token T_LT "lt"
%token T_LE "le"
%token T_GT "gt"
%token T_GE "ge"
%token T_ARROW "=>"
%token T_EQUALEQUAL "=="
%token T_NOTEQUAL "!="
%token T_GREATER ">"
%token T_GREATEREQ ">="
%token T_LESSTHAN "<"
%token T_LESSTHANEQ "<="

%token T_ID T_STR_LITERAL T_RE T_INT_LITERAL T_FLOAT_LITERAL
%token T_HASH T_POLY T_VOID T_VAR T_STRING T_INT T_FLOAT

%left T_OROR
%left T_ANDAND
%nonassoc T_EQ T_NE T_EQUALEQUAL T_NOTEQUAL T_EQTWID T_BANGTWID
%nonassoc T_GT T_GE T_LT T_LE T_GREATER T_GREATEREQ T_LESSTHAN T_LESSTHANEQ
%left T_PLUS T_MINUS
%left T_STAR T_SLASH T_PERC
%right T_BANG T_PLUSPLUS T_MINUSMINUS UMINUS

%%

start:	  funclist	{ L_current_ast = $1; }
	;

funclist: 
          funclist function_declaration	
        { 
                ((L_function_declaration*)$2)->next = $1;
                $$ = $2;
        }
	| /* epsilon */         { $$ = NULL; }
	;

function_declaration:
          return_type_specifier T_ID "(" parameter_list ")" compound_statement 
        {  
                $$ = mk_function_declaration($2, $4, $1, 
                                             ((L_statement *)$6)->u.block,
                                             NULL);
        }
	;


stmt:
          single_statement      { $$ = $1; if (L_interactive) YYACCEPT; }
        | compound_statement    { $$ = $1; if (L_interactive) YYACCEPT; }
        ;

single_statement:
          selection_statement   
        {
                $$ = mk_statement(L_STATEMENT_IF_UNLESS, NULL);
                ((L_statement *)$$)->u.cond = $1;
        }
	| expr ";"              
        { 
                $$ = mk_statement(L_STATEMENT_EXPR, NULL);
                ((L_statement *)$$)->u.expr = $1;
        }
        | T_RETURN ";"                  
        {  
                $$ = mk_statement(L_STATEMENT_RETURN, NULL);
                ((L_statement *)$$)->u.expr = NULL;
        }
        | T_RETURN expr ";"
        {  
                $$ = mk_statement(L_STATEMENT_RETURN, NULL);
                ((L_statement *)$$)->u.expr = $2;
        }
	;

selection_statement:
          T_IF "(" expr ")" compound_statement optional_else
        {  
                $$ = mk_if_unless($3, $5, $6);
        }
        /* if you have no curly braces, you get no else. */
        | T_IF "(" expr ")" single_statement
        {
                $$ = mk_if_unless($3, $5, NULL);
        }
        /* analogous to the if statements. the unless statements
           differ only by the true value passed to L_if_condition */
        | T_UNLESS "(" expr ")" compound_statement optional_else 
        {  
                $$ = mk_if_unless($3, $6, $5);
        }
        | T_UNLESS "(" expr ")" single_statement        
        {  
                $$ = mk_if_unless($3, NULL, $5);
        }
        ;

optional_else:
        /* else clauses must either have curly braces or be another
           if/unless */
          T_ELSE compound_statement     { $$ = $2; }
        | T_ELSE selection_statement    
        { 
                $$ = mk_statement(L_STATEMENT_IF_UNLESS, NULL);
                ((L_statement *)$$)->u.cond = $2;
        }
        | /* epsilon */                 { $$ = NULL; }
        ;

stmt_list:
          stmt
 	| stmt_list stmt          { ((L_statement *)$2)->next = $1; $$ = $2; }
	;


parameter_list:
          parameter_declaration_list    
        { 
                REVERSE(L_variable_declaration, next, $1);
                $$ = $1;
        }
        | T_VOID                        { $$ = NULL; }
        | /* epsilon */                 { $$ = NULL; }
        ;

parameter_declaration_list:
          parameter_declaration
        | parameter_declaration_list "," parameter_declaration
        {
                ((L_variable_declaration *)$3)->next = $1;
                $$ = $3;
        }
        ;

parameter_declaration:
          type_specifier declarator
        { 
                ((L_variable_declaration *)$2)->type = $1;
                $$ = $2;
        }
        ;

argument_expression_list:
          expr
        | argument_expression_list "," expr
        { 
                ((L_expression *)$3)->next = $1; 
                $$ = $3;
        }
	| /* epsilon */         { $$ = NULL }
        ;

expr:
          "(" expr ")"          { $$ = $2; }
/* 	| "!" expr		{ } */
/* 	| "-" expr %prec UMINUS	{ } */
        | T_PLUSPLUS T_ID
        {   
                $$ = mk_expression(L_EXPRESSION_PRE, T_PLUSPLUS, $2, NULL, NULL, NULL, NULL);
        }
	| T_MINUSMINUS T_ID
        {   
                $$ = mk_expression(L_EXPRESSION_PRE, T_MINUSMINUS, $2, NULL, NULL, NULL, NULL);
        }
	| T_ID T_PLUSPLUS
        {
                $$ = mk_expression(L_EXPRESSION_POST, T_PLUSPLUS, $2, NULL, NULL, NULL, NULL);
        }
	| T_ID T_MINUSMINUS
        {
                $$ = mk_expression(L_EXPRESSION_POST, T_MINUSMINUS, $2, NULL, NULL, NULL, NULL);
        }
	| expr T_STAR expr
        {
                $$ = mk_expression(L_EXPRESSION_BINARY, T_STAR, $1, $3, NULL, NULL, NULL);
        }
	| expr T_SLASH expr
        {
                $$ = mk_expression(L_EXPRESSION_BINARY, T_SLASH, $1, $3, NULL, NULL, NULL);
        }
	| expr T_PERC expr
        {
                $$ = mk_expression(L_EXPRESSION_BINARY, T_PERC, $1, $3, NULL, NULL, NULL);
        }
	| expr T_PLUS expr
        {
                $$ = mk_expression(L_EXPRESSION_BINARY, T_PLUS, $1, $3, NULL, NULL, NULL);
        }
	| expr T_MINUS expr
        {
                $$ = mk_expression(L_EXPRESSION_BINARY, T_MINUS, $1, $3, NULL, NULL, NULL);
        }

/* 	| expr "lt" expr	{ } */
/* 	| expr "le" expr	{ } */
/* 	| expr "gt" expr	{ } */
/* 	| expr "ge" expr	{ } */
/* 	| expr "eq" expr	{ } */
/* 	| expr "ne" expr	{ } */
/* 	| expr "==" expr	{ } */
/* 	| expr "!=" expr	{ } */
/* 	| expr ">" expr		{ } */
/* 	| expr ">=" expr	{ } */
/* 	| expr "<" expr		{ } */
/* 	| expr "<=" expr	{ } */
/* 	| expr "=~" T_RE	{ } */
/* 	| expr "!~" T_RE	{ } */
/* 	| expr "&&" expr	{ } */
/* 	| expr "||" expr	{ } */
/*         |  */
        | T_STR_LITERAL
        | T_INT_LITERAL
        | T_FLOAT_LITERAL
	| lvalue
        {
                REVERSE(L_expression, indices, $1);
                $$ = $1;
        }
        | T_ID "(" argument_expression_list ")"         
        { 
                REVERSE(L_expression, next, $3);
                $$ = mk_expression(L_EXPRESSION_FUNCALL, -1, $1, $3, NULL, NULL, NULL);
        }
	| lvalue T_EQUALS expr
        { 
                REVERSE(L_expression, indices, $1);
                $$ = mk_expression(L_EXPRESSION_BINARY, T_EQUALS, $1, $3, NULL, NULL, NULL);
        }
	;

lvalue:
          T_ID
        {
                $$ = mk_expression(L_EXPRESSION_VARIABLE, -1, $1, NULL, NULL, NULL, NULL);
        }
        | lvalue "[" expr "]"
        {
                $$ = mk_expression(L_EXPRESSION_INDEX, -1, $3, NULL, NULL, $1, NULL);
        }
        ;

compound_statement:
	  "{" "}"               
        { 
                $$ = mk_statement(L_STATEMENT_BLOCK, NULL);
                ((L_statement *)$$)->u.block = mk_block(NULL, NULL); 
        }
	| "{" stmt_list "}"                     
        { 
                REVERSE(L_statement, next, $2);
                $$ = mk_statement(L_STATEMENT_BLOCK, NULL);
                ((L_statement *)$$)->u.block = mk_block(NULL, $2); 
        }
	| "{" declaration_list "}"              
        { 
                REVERSE(L_variable_declaration, next, $2);
                $$ = mk_statement(L_STATEMENT_BLOCK, NULL);
                ((L_statement *)$$)->u.block = mk_block($2, NULL); 
        }
	| "{" declaration_list stmt_list "}"    
        { 
                REVERSE(L_variable_declaration, next, $2);
                REVERSE(L_statement, next, $3);
                $$ = mk_statement(L_STATEMENT_BLOCK, NULL);
                ((L_statement *)$$)->u.block = mk_block($2, $3); 
        }
	;

declaration_list:
	  declaration
	| declaration_list declaration
        {
                L_variable_declaration *i;
                for (i = $2; i->next; i = i->next);
                i->next = $1;
                $$ = $2;
        }
	;

declaration:
	  init_declarator_list ";"
        {
                $$ = $1;
        }
	;

init_declarator_list:
	  type_specifier init_declarator
        {
                L_type *array_type = ((L_variable_declaration *)$2)->type;

                REVERSE(L_type, next, array_type);
                ((L_type *)$1)->next = array_type;
                ((L_variable_declaration *)$2)->type = $1;
                $$ = $2;
        }
	| init_declarator_list "," init_declarator
        {
                L_type_kind base_type =
                        ((L_variable_declaration *)$1)->type->kind;
                L_type *array_type = ((L_variable_declaration *)$3)->type;

                REVERSE(L_type, next, array_type);
                /* we have to copy the base type, because each
                   declarator can have its own array type */
                ((L_variable_declaration *)$3)->type = 
                        mk_type(base_type, NULL, array_type);
                ((L_variable_declaration *)$3)->next = $1;
                $$ = $3;
        }
	;

init_declarator:
	  declarator
	| declarator T_EQUALS initializer
        {
                ((L_variable_declaration *)$1)->initial_value = $3;
                $$ = $1;
        }
	;

declarator:
          T_ID
        {
                $$ = mk_variable_declaration(NULL, $1, NULL, NULL);
        }
	| declarator "[" constant_expression "]"
        {
                L_type *type = mk_type(-1, $3,
                                       ((L_variable_declaration *)$1)->type);
                ((L_variable_declaration *)$1)->type = type;
                $$ = $1;
        }
	| declarator "[" "]"
        {
                L_expression *zero;

                MK_INT_NODE(zero, 0);
                ((L_variable_declaration *)$1)->type =
                        mk_type(-1, zero,
                                ((L_variable_declaration *)$1)->type);
                $$ = $1;
        }
        ;

return_type_specifier:
          type_specifier
        | T_VOID        { $$ = mk_type(L_TYPE_VOID, NULL, NULL); }
        | /* epsilon */ { $$ = mk_type(L_TYPE_VOID, NULL, NULL); }
        ;

type_specifier:
	  T_STRING      { $$ = mk_type(L_TYPE_STRING, NULL, NULL); }
	| T_INT         { $$ = mk_type(L_TYPE_INT, NULL, NULL); }
	| T_FLOAT       { $$ = mk_type(L_TYPE_FLOAT, NULL, NULL); }
	| T_HASH        { $$ = mk_type(L_TYPE_HASH, NULL, NULL); }
	| T_POLY        { $$ = mk_type(L_TYPE_POLY, NULL, NULL); }
	| T_VAR         { $$ = mk_type(L_TYPE_VAR, NULL, NULL); }
	;

initializer:
          expr
        | "(" hash_initializer_list ")"         { $$ = $2; }
        ;

hash_initializer_list:
        /* XXX these need work */
          hash_initializer
        {
                MK_STRING_NODE($$, ""); 
        }
        | hash_initializer_list "," hash_initializer
        {
                MK_STRING_NODE($$, ""); 
        }
        ;

hash_initializer:
          constant_expression "=>" constant_expression
        ;

constant_expression:
          expr
        ;
%%


/*
 * Local Variables:
 * mode: c
 * c-basic-offset: 4
 * fill-column: 78
 * End:
 */
