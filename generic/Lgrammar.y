%{
#include <stdio.h>
#include "Ltokens.h"
#include "tclInt.h"
#include "tclCompile.h"

static	Tcl_Interp	*L_interp;
static	CompileEnv	*L_envPtr;
%}

%union {
	val	v;
	int	i;
}

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

%token <v> T_ID T_STR T_RE
%token <v> T_INT
%token <v> T_FLOAT

%left T_OROR
%left T_ANDAND
%nonassoc T_EQ T_NE T_EQUALEQUAL T_NOTEQUAL T_EQTWID T_BANGTWID
%nonassoc T_GT T_GE T_LT T_LE T_GREATER T_GREATEREQ T_LESSTHAN T_LESSTHANEQ
%left T_PLUS T_MINUS
%left T_STAR T_SLASH T_PERC
%right T_BANG T_PLUSPLUS T_MINUSMINUS UMINUS
%nonassoc T_LPAREN T_RPAREN

%type <i> expr exprlist

%%

start:	  funclist	{ }
	;

funclist: funclist func	{ }
	|		{ }
	;

func:	  T_ID "(" T_ID ")" "{" sl "}"
			{ }
	;

sl:	  sl stmt	{ }
	|		{ }
	;

stmt:	  "if" "(" expr ")" "{" sl "}"
	| "if" "(" expr ")" "{" sl "}" "else" "{" sl "}"
	| "unless" "(" expr ")" "{" sl "}"
	| "unless" "(" expr ")" "{" sl "}" "else" "{" sl "}"
	| T_ID {
		TclEmitPush(
	    	    TclRegisterNewLiteral(L_envPtr, $1.s, strlen($1.s)),
	    	    L_envPtr);
	 } "(" exprlist ")" ";" {
	    	TclEmitInstInt4(INST_INVOKE_STK4, $4+1, L_envPtr);
	 }
	| T_ID "=" expr ";"	{ }
	;

exprlist: exprlist "," expr	{ $$ = $3 + 1; }
	| expr			{ $$ = 1; }
	|			{ $$ = 0; }
	;

expr:	  "(" expr ")"		{ $$ = 1; }
	| "!" expr		{ $$ = 1; }
	| "-" expr %prec UMINUS	{ $$ = 1; }
	| "++" expr		{ $$ = 1; }
	| "--" expr		{ $$ = 1; }
	| expr "++"		{ $$ = 1; }
	| expr "--"		{ $$ = 1; }
	| expr "*" expr		{ $$ = 1; }
	| expr "/" expr		{ $$ = 1; }
	| expr "%" expr		{ $$ = 1; }
	| expr "+" expr		{ $$ = 1; }
	| expr "-" expr		{ $$ = 1; }
	| expr "lt" expr	{ $$ = 1; }
	| expr "le" expr	{ $$ = 1; }
	| expr "gt" expr	{ $$ = 1; }
	| expr "ge" expr	{ $$ = 1; }
	| expr "eq" expr	{ $$ = 1; }
	| expr "ne" expr	{ $$ = 1; }
	| expr "==" expr	{ $$ = 1; }
	| expr "!=" expr	{ $$ = 1; }
	| expr ">" expr		{ $$ = 1; }
	| expr ">=" expr	{ $$ = 1; }
	| expr "<" expr		{ $$ = 1; }
	| expr "<=" expr	{ $$ = 1; }
	| expr "=~" T_RE	{ $$ = 1; }
	| expr "!~" T_RE	{ $$ = 1; }
	| expr "&&" expr	{ $$ = 1; }
	| expr "||" expr	{ $$ = 1; }
	| T_STR			{
		TclEmitPush(
		    TclRegisterNewNSLiteral(L_envPtr, $1.s, strlen($1.s)),
		    L_envPtr);
		$$ = 1;
	}
	| T_INT			{
		TclEmitInt4($1.i, L_envPtr);
		$$ = 1;
	}
	| T_FLOAT		{ }
	| T_ID			{ }
	;
%%

void
LCompileScript(
	Tcl_Interp *interp,
	CONST char *str,
	int numBytes,
	CompileEnv *envPtr
)
{
	void		*lex_buffer = (void *)L__scan_bytes(str, numBytes);
	Tcl_Interp	*svinterp = L_interp;
	CompileEnv	*svenvPtr = L_envPtr;

	/*
	 * Save arguments in global variables so the parser can see them,
	 * then restore previous values so the parser is re-entrant.
	 */
	L_interp = interp;
	L_envPtr = envPtr;

	L_parse();
	L__delete_buffer(lex_buffer);

	L_interp = svinterp;
	L_envPtr = svenvPtr;
}

int
L_error(char *s)
{
	fprintf(stderr, "syntax error: %s\n", s);
	return 0;
}
