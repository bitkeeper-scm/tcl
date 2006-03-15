%option	noyywrap
%x glob_re
%x comment
%x str_double
%x str_single
ID	[a-zA-Z_][0-9a-zA-Z_.]*
REV	[0-9]+(\.[0-9]+)*
TAG	[a-zA-Z_][0-9a-zA-Z_.]*
%{
#include <string.h>
#include "Ltokens.h"
#include "Lgrammar.h"
static char *str;
/* XXX string collection buffer; change to arb len string soon */
static char strbuf[1024];

extern int L_line_number;

/**
 * Count the newlines in a string and add the number to L_line_number.
 */
void 
tally_newlines(
        char *s,        /* the string with the newlines */
        int len)        /* the length of the string */
{
    char *p, *end;

    for (p = s, end = p + len; p < end; p++) {
        if (*p == '\n') {
            L_line_number++;
        } else if ((*p == '\r') && (p+1 < end) && (*(p+1) != '\n')) {
            /* mac line endings */
            L_line_number++;
        }
    }  
}

%}
%%
"("		return T_LPAREN;
")"		return T_RPAREN;
"{"		return T_LBRACE;
"}"		return T_RBRACE;
","		return T_COMMA;
"!"		return T_BANG;
"+"		return T_PLUS;
"-"		return T_MINUS;
"*"		return T_STAR;
"/"		return T_SLASH;
"%"		return T_PERC;
"++"		return T_PLUSPLUS;
"--"		return T_MINUSMINUS;
"&&"		return T_ANDAND;
"||"		return T_OROR;
"="		return T_EQUALS;
";"		return T_SEMI;
"!~"[ \t]*"/"	BEGIN(glob_re); str = strbuf; return T_BANGTWID;
"=~"[ \t]*"/"	BEGIN(glob_re); str = strbuf; return T_EQTWID;
<glob_re>{
	\\(.|\n)	*str++ = yytext[1];
	[^\\\n/]+	{ char * y = yytext; while (*y) *str++ = *y++; }
	"/"		{
				BEGIN(INITIAL);
				*str++ = 0;
                                L_lval.type = LTOKEN_STRING;
				L_lval.v.s = malloc(strlen(strbuf)+1);
				strcpy(L_lval.v.s, strbuf);
				return T_RE;
			}
}
"if"		return T_IF;
"else"		return T_ELSE;
"unless"	return T_UNLESS;
"eq"		return T_EQ;
"ne"		return T_NE;
"lt"		return T_LT;
"le"		return T_LE;
"gt"		return T_GT;
"ge"		return T_GE;
"=="		return T_EQUALEQUAL;
"!="		return T_NOTEQUAL;
">"		return T_GREATER;
">="		return T_GREATEREQ;
"<"		return T_LESSTHAN;
"<="		return T_LESSTHANEQ;
{ID}		{
                        L_lval.type = LTOKEN_ID;
			L_lval.v.s = malloc(yyleng+1);
			strcpy(L_lval.v.s, yytext);
			return T_ID;
}
[0-9]*		L_lval.type = LTOKEN_INT; L_lval.v.i = atoi(yytext); return T_INT;
[0-9]+\.[0-9]+	L_lval.type = LTOKEN_FLOAT; L_lval.v.f = atof(yytext); return T_FLOAT;
\"		BEGIN(str_double); str = strbuf;
<str_double>{
	\\n		*str++ = '\n';
	\\t		*str++ = '\t';
	\\(.|\n)	*str++ = yytext[1];
	[^\\\n\"]+	{ char * y = yytext; while (*y) *str++ = *y++; }
	\"		{
				BEGIN(INITIAL);
				*str++ = 0;
                                L_lval.type = LTOKEN_STRING;
				L_lval.v.s = malloc(strlen(strbuf)+1);
				strcpy(L_lval.v.s, strbuf);
				return T_STR;
			}
}
\'		BEGIN(str_single); str = strbuf;
<str_single>{
	\\n		*str++ = '\n';
	\\t		*str++ = '\t';
	\\(.|\n)	*str++ = yytext[1];
	[^\\\n\']+	{ char * y = yytext; while (*y) *str++ = *y++; }
	\'		{
				BEGIN(INITIAL);
				*str++ = 0;
                                L_lval.type = LTOKEN_STRING;
				L_lval.v.s = malloc(strlen(strbuf)+1);
				strcpy(L_lval.v.s, strbuf);
				return T_STR;
			}
}
"/*"		BEGIN(comment);
<comment>{
	[^*]+           tally_newlines(yytext, yyleng);
        "*"
	"*/"		BEGIN(INITIAL);
}
[ \t\n\r]+              tally_newlines(yytext, yyleng);
.		{
			fprintf(stderr, "illegal character %c\n", *yytext);
			exit(1);
		}
