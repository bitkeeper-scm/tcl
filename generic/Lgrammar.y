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

void *finish_declaration(L_type *type_specifier, L_variable_declaration *decl) {
        /* Reverse the array type and copy the base type for a variable
           declaration.  The base type gets copied because it can't be shared
           in cases like ``int foo, bar[5];��.  Returns the finished
           declaration. */
        L_type *array_type = decl->type;

        REVERSE(L_type, next_dim, array_type);
        decl->type = mk_type(type_specifier->kind, NULL,
                             type_specifier->struct_tag, array_type,
                             type_specifier->members);
        return decl;
}


%}

%token T_LPAREN "("
%token T_RPAREN ")"
%token T_LBRACE "{"
%token T_RBRACE "}"
%token T_LBRACKET "["
%token T_RBRACKET "]"
%token T_SEMI ";"
%token T_BANGTWID "!~"
%token T_EQTWID "=~"
%token T_IF "if"
%token T_UNLESS "unless"
%nonassoc T_ELSE "else"
%token T_RETURN "return"

%token T_COMMA ","

%right T_EQUALS "="

%token T_ARROW "=>"
%token T_WHILE T_FOR T_DO T_STRUCT
%token T_ID T_STR_LITERAL T_RE T_INT_LITERAL T_DOUBLE_LITERAL
%token T_HASH T_POLY T_VOID T_VAR T_STRING T_INT T_DOUBLE

%left T_OROR
%left T_ANDAND
%left T_BITOR
%left T_BITXOR
%left T_BITAND
%left T_EQ T_NE T_EQUALEQUAL T_NOTEQUAL T_EQTWID T_BANGTWID
%left T_GT T_GE T_LT T_LE T_GREATER T_GREATEREQ T_LESSTHAN T_LESSTHANEQ
%left T_LSHIFT T_RSHIFT
%left T_PLUS T_MINUS
%left T_STAR T_SLASH T_PERC
%right T_BANG T_PLUSPLUS T_MINUSMINUS UMINUS UPLUS T_BITNOT
%left T_DOT

%%

start:	  toplevel_code
        {
                REVERSE(L_toplevel_statement, next, $1);
                L_current_ast = $1;
        }
	;

toplevel_code:
          toplevel_code function_declaration
        { 
                $$ = mk_toplevel_statement(L_TOPLEVEL_STATEMENT_FUNCTION_DECLARATION, $1);
                ((L_toplevel_statement *)$$)->u.fun = $2;
        }
        | toplevel_code struct_specifier ";"
        {
                $$ = mk_toplevel_statement(L_TOPLEVEL_STATEMENT_TYPE, $1);
                ((L_toplevel_statement *)$$)->u.type = $2;
        }
	| /* epsilon */         { $$ = NULL; }
	;

function_declaration:
          return_type_specifier T_ID "(" parameter_list ")" compound_statement 
        {  
                $$ = mk_function_declaration($2, $4, $1, ((L_statement *)$6)->u.block);
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
        | iteration_statement
        {
                $$ = mk_statement(L_STATEMENT_LOOP, NULL);
                ((L_statement *)$$)->u.loop = $1;
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

iteration_statement:
          T_WHILE "(" expr ")" stmt
        {
                $$ = mk_loop(L_LOOP_WHILE, NULL, $3, NULL, $5);
        }
	| T_DO stmt T_WHILE "(" expr ")" ";"
        {
                $$ = mk_loop(L_LOOP_DO, NULL, $5, NULL, $2);
        }
	| T_FOR "(" expression_statement expression_statement ")" stmt
        {
                $$ = mk_loop(L_LOOP_FOR, $3, $4, NULL, $6);
        }
	| T_FOR "(" expression_statement expression_statement expr ")" stmt
        {
                $$ = mk_loop(L_LOOP_FOR, $3, $4, $5, $7);
        }
	;


expression_statement
	: ';'                   { $$ = NULL; }
	| expr ';'
	;

stmt_list:
          stmt
 	| stmt_list stmt        { ((L_statement *)$2)->next = $1; $$ = $2; }
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
                $$ = finish_declaration($1, $2);
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
 	| T_BANG expr
        {
                $$ = mk_expression(L_EXPRESSION_UNARY, T_BANG, $2, NULL, NULL, NULL, NULL);
        }
 	| T_BITNOT expr
        {
                $$ = mk_expression(L_EXPRESSION_UNARY, T_BITNOT, $2, NULL, NULL, NULL, NULL);
        }
 	| T_MINUS expr %prec UMINUS
        {
                $$ = mk_expression(L_EXPRESSION_UNARY, T_MINUS, $2, NULL, NULL, NULL, NULL);
        }
 	| T_PLUS expr %prec UPLUS
        {
                $$ = mk_expression(L_EXPRESSION_UNARY, T_PLUS, $2, NULL, NULL, NULL, NULL);
        }
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
        | expr T_EQTWID T_RE    { MK_BINOP_NODE($$, T_EQTWID, $1, $3); }
        | expr T_BANGTWID T_RE  { MK_BINOP_NODE($$, T_BANGTWID, $1, $3); }
	| expr T_STAR expr      { MK_BINOP_NODE($$, T_STAR, $1, $3); }
	| expr T_SLASH expr     { MK_BINOP_NODE($$, T_SLASH, $1, $3); }
	| expr T_PERC expr      { MK_BINOP_NODE($$, T_PERC, $1, $3); }
	| expr T_PLUS expr      { MK_BINOP_NODE($$, T_PLUS, $1, $3); }
	| expr T_MINUS expr     { MK_BINOP_NODE($$, T_MINUS, $1, $3); }
	| expr T_EQ expr        { MK_BINOP_NODE($$, T_EQ, $1, $3); }
	| expr T_NE expr        { MK_BINOP_NODE($$, T_NE, $1, $3); }
	| expr T_LT expr        { MK_BINOP_NODE($$, T_LT, $1, $3); }
	| expr T_LE expr        { MK_BINOP_NODE($$, T_LE, $1, $3); }
	| expr T_GT expr        { MK_BINOP_NODE($$, T_GT, $1, $3); }
	| expr T_GE expr        { MK_BINOP_NODE($$, T_GE, $1, $3); }
	| expr T_EQUALEQUAL expr        { MK_BINOP_NODE($$, T_EQUALEQUAL, $1, $3); }
	| expr T_NOTEQUAL expr  { MK_BINOP_NODE($$, T_NOTEQUAL, $1, $3); }
	| expr T_GREATER expr   { MK_BINOP_NODE($$, T_GREATER, $1, $3); }
	| expr T_GREATEREQ expr { MK_BINOP_NODE($$, T_GREATEREQ, $1, $3); }
	| expr T_LESSTHAN expr  { MK_BINOP_NODE($$, T_LESSTHAN, $1, $3); }
	| expr T_LESSTHANEQ expr        { MK_BINOP_NODE($$, T_LESSTHANEQ, $1, $3); }
	| expr T_ANDAND expr    { MK_BINOP_NODE($$, T_ANDAND, $1, $3); }
	| expr T_OROR expr      { MK_BINOP_NODE($$, T_OROR, $1, $3); }
	| expr T_LSHIFT expr    { MK_BINOP_NODE($$, T_LSHIFT, $1, $3); }
	| expr T_RSHIFT expr    { MK_BINOP_NODE($$, T_RSHIFT, $1, $3); }
	| expr T_BITOR expr     { MK_BINOP_NODE($$, T_BITOR, $1, $3); }
	| expr T_BITAND expr    { MK_BINOP_NODE($$, T_BITAND, $1, $3); }
	| expr T_BITXOR expr    { MK_BINOP_NODE($$, T_BITXOR, $1, $3); }
/* 	| expr "=~" T_RE	{ } */
/* 	| expr "!~" T_RE	{ } */
        | T_STR_LITERAL
        | T_INT_LITERAL
        | T_DOUBLE_LITERAL
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
        /* this is a special case, to allow calling Tk widget functions */
        | T_DOT T_ID "(" argument_expression_list ")"
        {
                L_expression *name = mk_expression(L_EXPRESSION_STRING, -1, NULL, NULL, NULL, NULL, NULL);
                name->u.s = ckalloc(strlen(((L_expression *)$2)->u.s + 2));
                *name->u.s = '.';
                strcpy(name->u.s + 1, ((L_expression *)$2)->u.s);
                REVERSE(L_expression, next, $4);
                $$ = mk_expression(L_EXPRESSION_FUNCALL, -1, name, $4, NULL, NULL, NULL);
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
        | lvalue T_LBRACKET expr T_RBRACKET
        {
                $$ = mk_expression(L_EXPRESSION_ARRAY_INDEX, -1, $3, NULL, NULL, $1, NULL);
        }
        | lvalue T_LBRACE expr T_RBRACE
        {
                $$ = mk_expression(L_EXPRESSION_HASH_INDEX, -1, $3, NULL, NULL, $1, NULL);
        }
        | lvalue T_DOT T_ID
        {
                $$ = mk_expression(L_EXPRESSION_STRUCT_INDEX, -1, $3, NULL, NULL, $1, NULL);
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
            /* Each declaration is a list of declarators.  Here we append
               the lists. */
            APPEND(L_variable_declaration, next, $2, $1);
            $$ = $2;
        }
	;

declaration:
	  init_declarator_list ";"
	;

init_declarator_list:
	  type_specifier init_declarator
        {
                $$ = finish_declaration($1, $2);
        }
	| init_declarator_list "," init_declarator
        {
                $$ = finish_declaration(((L_variable_declaration *)$1)->type, $3);
                ((L_variable_declaration *)$$)->next = $1;
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
                L_type *type =
                        mk_type(-1, $3, NULL, ((L_variable_declaration *)$1)->type, NULL);
                ((L_variable_declaration *)$1)->type = type;
                $$ = $1;
        }
	| declarator "[" "]"
        {
                L_expression *zero;

                MK_INT_NODE(zero, 0);
                ((L_variable_declaration *)$1)->type =
                    mk_type(-1, zero, NULL,
                            ((L_variable_declaration *)$1)->type, NULL);
                $$ = $1;
        }
        ;

return_type_specifier:
          type_specifier
        | T_VOID        { $$ = mk_type(L_TYPE_VOID, NULL, NULL, NULL, NULL); }
        | /* epsilon */ { $$ = mk_type(L_TYPE_VOID, NULL, NULL, NULL, NULL); }
        ;

type_specifier:
	  T_STRING      { $$ = mk_type(L_TYPE_STRING, NULL, NULL, NULL, NULL); }
	| T_INT         { $$ = mk_type(L_TYPE_INT, NULL, NULL, NULL, NULL); }
	| T_DOUBLE      { $$ = mk_type(L_TYPE_DOUBLE, NULL, NULL, NULL, NULL); }
	| T_HASH        { $$ = mk_type(L_TYPE_HASH, NULL, NULL, NULL, NULL); }
	| T_POLY        { $$ = mk_type(L_TYPE_POLY, NULL, NULL, NULL, NULL); }
	| T_VAR         { $$ = mk_type(L_TYPE_VAR, NULL, NULL, NULL, NULL); }
        | struct_specifier
	;

struct_specifier:
          T_STRUCT T_ID "{" struct_declaration_list "}"
        {
                REVERSE(L_variable_declaration, next, $4);
                $$ = mk_type(L_TYPE_STRUCT, NULL, $2, NULL, $4);
        }
	| T_STRUCT "{" struct_declaration_list "}"
        {
                REVERSE(L_variable_declaration, next, $3);
                $$ = mk_type(L_TYPE_STRUCT, NULL, NULL, NULL, $3);
        }
	| T_STRUCT T_ID
        {
                $$ = mk_type(L_TYPE_STRUCT, NULL, $2, NULL, NULL);
        }
        ;

struct_declaration_list:
          struct_declaration
        | struct_declaration_list struct_declaration
        {
            APPEND(L_variable_declaration, next, $2, $1);
            $$ = $2;
/*                 ((L_variable_declaration *)$2)->next = $1; */
/*                 $$ = $2; */
        }
        ;

struct_declaration:
          struct_declarator_list ";"
	;

struct_declarator_list:
	  type_specifier declarator
        {
                $$ = finish_declaration($1, $2);
        }
	| struct_declarator_list "," declarator
        {
                $$ = finish_declaration(((L_variable_declaration *)$1)->type, $3);
                ((L_variable_declaration *)$$)->next = $1;
        }
	;

initializer:
          expr
        | "{" initializer_list "}"         { $$ = $2; }
        ;

initializer_list:
        /* XXX these need work */
          initializer_list_element
        {
                MK_STRING_NODE($$, ""); 
        }
        | initializer_list T_COMMA initializer_list_element
        {
                MK_STRING_NODE($$, ""); 
        }
        ;

initializer_list_element:
          initializer
        | initializer "=>" initializer
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
