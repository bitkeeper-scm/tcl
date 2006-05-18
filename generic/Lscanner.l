%option	noyywrap
%x glob_re
%x comment
%x str_double
%x str_single
ID	\.?[a-zA-Z_][0-9a-zA-Z_.]*
REV	[0-9]+(\.[0-9]+)*
TAG	[a-zA-Z_][0-9a-zA-Z_.]*
%{
#include <string.h>
#include "Lcompile.h"
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
"["		return T_LBRACKET;
"]"		return T_RBRACKET;
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
"&"		return T_BITAND;
"|"		return T_BITOR;
"^"		return T_BITXOR;
"~"		return T_BITNOT;
"<<"            return T_LSHIFT;
">>"            return T_RSHIFT;
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
                                MK_STRING_NODE(L_lval, strbuf);
				return T_RE;
			}
}
"return"          return T_RETURN;
"void"          return T_VOID;
"string"        return T_STRING;
"int"           return T_INT;
"float"         return T_FLOAT;
"hash"          return T_HASH;
"poly"          return T_POLY;
"var"           return T_VAR;
"if"		return T_IF;
"else"		return T_ELSE;
"unless"	return T_UNLESS;
"while"         return T_WHILE;
"do"            return T_DO;
"for"           return T_FOR;
"=>"		return T_ARROW;
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
                        MK_STRING_NODE(L_lval, yytext);
			return T_ID;
                }
[0-9]*		{       
                        MK_INT_NODE(L_lval, atoi(yytext)); 
                        return T_INT_LITERAL;   
                }
[0-9]*\.[0-9]+	{
                        MK_FLOAT_NODE(L_lval, atof(yytext));
                        return T_FLOAT_LITERAL;   
                }
\"		BEGIN(str_double); str = strbuf;
<str_double>{
	\\n		*str++ = '\n';
	\\t		*str++ = '\t';
	\\(.|\n)	*str++ = yytext[1];
	[^\\\n\"]+	{ char * y = yytext; while (*y) *str++ = *y++; }
	\"		{
				BEGIN(INITIAL);
				*str++ = 0;
                                MK_STRING_NODE(L_lval, strbuf);
				return T_STR_LITERAL;
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
                                MK_STRING_NODE(L_lval, strbuf);
				return T_STR_LITERAL;
			}
}
"/*"		BEGIN(comment);
<comment>{
	[^*]+           tally_newlines(yytext, yyleng);
        "*"
	"*/"		BEGIN(INITIAL);
}
"//".*("\r"|"\n"|"\r\n")        { tally_newlines(yytext, yyleng); }
[ \t\n\r]+              tally_newlines(yytext, yyleng);
.		{
			fprintf(stderr, "illegal character %c\n", *yytext);
			exit(1);
		}


