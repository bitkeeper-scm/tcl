%{
#include <stdio.h>
#include "Lcompile.h"
#include "tclInt.h"
#include "tclCompile.h"

/* L_lex is generated by lex */
int L_lex (void);

#define YYERROR_VERBOSE
%}

%token T_LPAREN "("
%token T_RPAREN ")"
%token T_LBRACE "{"
%token T_RBRACE "}"
%token T_LBRACKET "["
%token T_RBRACKET "]"
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
%token T_UNLESS "unless"
%nonassoc T_ELSE "else"


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
%token T_COMMA ","

%token T_ID T_STR_LITERAL T_RE T_INT_LITERAL T_FLOAT_LITERAL
%token T_HASH T_POLY T_VOID T_VAR T_STRING T_INT T_FLOAT

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
          return_type_specifier T_ID { L_begin_function_decl($2); } "(" parameter_list ")" 
                compound_statement { L_end_function_decl($2); }
	;

stmt:   
          single_statement
        | compound_statement
        ;

single_statement:     
          selection_statement
	| expr ";"
	;

selection_statement:
          T_IF "(" expr ")"             { L_if_condition(0); } 
                compound_statement      { L_if_consequent_end(); }
                optional_else           { L_if_end($8->v.i); }
        /* if you have no curly braces, you get no else. */
        | T_IF "(" expr ")"             { L_if_condition(0); } 
                single_statement        { L_if_consequent_end(); L_if_end(0); }
        /* analogous to the if statements, the unless statements
           differ only by the true value passed to L_if_condition */
        | T_UNLESS "(" expr ")"         { L_if_condition(1); } 
                compound_statement      { L_if_consequent_end(); }
                optional_else           { L_if_end($8->v.i); }
        | T_UNLESS "(" expr ")"         { L_if_condition(1); } 
                single_statement        { L_if_consequent_end(); L_if_end(0); }
        ;

optional_else:
        /* else clauses must either have curly braces or be another
           if/unless */
          T_ELSE                { L_if_alternative_end(); 
                                  $$ = L_make_node(L_NODE_INT, LNIL, 1); }
                compound_statement
        | T_ELSE                { L_if_alternative_end(); 
                                  $$ = L_make_node(L_NODE_INT, LNIL, 0); }
                selection_statement
        | /* epsilon */         { $$ = L_make_node(L_NODE_INT, LNIL, 0); }
        ;
        
stmt_list: 
          stmt
 	| stmt_list stmt       
	;


parameter_list: 
          parameter_declaration_list
        | T_VOID
        | /* epsilon */
        ;

parameter_declaration_list:
          parameter_declaration
        | parameter_declaration_list "," parameter_declaration
        ;

parameter_declaration:
          type_specifier declarator
        ;

argument_expression_list: 
          argument_expression_list "," expr     { $$->v.i = $1->v.i + 1; }
	| expr			{ $$ = L_make_node(L_NODE_INT, LNIL, 1); }
	| /* epsilon */         { $$ = L_make_node(L_NODE_INT, LNIL, 0); }
        ;

expr:	/* "(" expr ")"		{ $$ = 1; } */
/* 	| "!" expr		{ $$ = 1; } */
/* 	| "-" expr %prec UMINUS	{ $$ = 1; } */
	  "++" T_ID		{ L_op_pre_incdec($2, '+'); }
	| "--" T_ID		{ L_op_pre_incdec($2, '-'); }
	| T_ID "++"		{ L_op_post_incdec($1, '+'); }
	| T_ID "--"		{ L_op_post_incdec($1, '-'); } 
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
        | T_STR_LITERAL         {L_push_str($1);}
        | T_INT_LITERAL         {L_push_int($1);}
        | T_FLOAT_LITERAL       { $$ = $1; }
	| T_ID			{L_push_id($1);}
        | T_ID                  { L_begin_function_call($1); } 
                "(" argument_expression_list ")" 
                                { L_end_function_call($1, $4->v.i); }
	| T_ID "=" expr         { L_assignment($1); }
	;


compound_statement:
	  "{" "}"
	| "{" stmt_list "}"
	| "{" declaration_list "}"
	| "{" declaration_list stmt_list "}"    
	;

declaration_list:
	  declaration   
	| declaration_list declaration  
	;

declaration:
	  init_declarator_list ";"  
	;

init_declarator_list:
	  type_specifier init_declarator                
                { $$ = $1; L_declare_variable($2->next, $1->v.i, $2->v.i); }
	| init_declarator_list "," init_declarator  
                { $$ = $1; L_declare_variable($3->next, $1->v.i, $3->v.i); }
	;

init_declarator:
	  declarator                    
                { $$ = L_make_node(L_NODE_INT, $1, 0); }
	| declarator "=" initializer    
                { $$ = L_make_node(L_NODE_INT, $1, 1); }
	;

declarator:
          T_ID
	| declarator "[" constant_expression "]"        
                { $$ = L_make_node(L_NODE_NODE, $1, 
                                   L_make_node(L_NODE_INT, $3, L_TYPE_ARRAY));
                }
	| declarator "[" "]" 
                { $$ = L_make_node(L_NODE_NODE, $1, 
                                   L_make_node(L_NODE_INT, LNIL, L_TYPE_ARRAY));
                }
        ;

return_type_specifier:
          type_specifier        
        | T_VOID        { $$ = L_make_node(L_NODE_INT, LNIL, L_TYPE_VOID); }
        | /* epsilon */ { $$ = L_make_node(L_NODE_INT, LNIL, L_TYPE_VOID); }
        ;

type_specifier:
	  T_STRING      { $$ = L_make_node(L_NODE_INT, LNIL, L_TYPE_STRING); }
	| T_INT         { $$ = L_make_node(L_NODE_INT, LNIL, L_TYPE_INT); }
	| T_FLOAT       { $$ = L_make_node(L_NODE_INT, LNIL, L_TYPE_FLOAT); }
	| T_HASH        { $$ = L_make_node(L_NODE_INT, LNIL, L_TYPE_HASH); }
	| T_POLY        { $$ = L_make_node(L_NODE_INT, LNIL, L_TYPE_POLY); }
	| T_VAR         { $$ = L_make_node(L_NODE_INT, LNIL, L_TYPE_VAR); }
	;

initializer:
          expr  
        | "(" hash_initializer_list ")"
        ;

hash_initializer_list:
          hash_initializer
        | hash_initializer_list "," hash_initializer
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
