%option	noyywrap
%option stack
%x glob_re
%x comment
%x str_double
%x str_single
%x interpol
ID	[a-zA-Z_:][0-9a-zA-Z_:]*
%{
#include <string.h>
#include "Lcompile.h"
#include "Lgrammar.h"

/* String collection buffer */
Tcl_Obj *str;

#define STRBUF_START()  {       \
    str = Tcl_NewObj();         \
    Tcl_IncrRefCount(str);      \
}                               \

#define STRBUF_STRING()         Tcl_GetString(str)

#define STRBUF_ADD(s, len)      Tcl_AppendToObj(str, s, len)

#define STRBUF_STOP()  {        \
    Tcl_DecrRefCount(str);      \
    str = NULL;                 \
}                               \

extern int L_line_number;

/* In case of errors, the start condition stack will be left in an
   unknown state.  This function gives us a way to reset it. */
void L_start_lexer() { BEGIN(0); }

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
<INITIAL,interpol>{
        "("		return T_LPAREN;
        ")"		return T_RPAREN;
        "{"		return T_LBRACE;
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
        "."             return T_DOT;
        "return"        return T_RETURN;
        "void"          return T_VOID;
        "string"        return T_STRING;
        "int"           return T_INT;
        "double"        return T_DOUBLE;
        "hash"          return T_HASH;
        "poly"          return T_POLY;
        "var"           return T_VAR;
        "if"		return T_IF;
        "else"		return T_ELSE;
        "unless"	return T_UNLESS;
        "while"         return T_WHILE;
        "do"            return T_DO;
        "for"           return T_FOR;
        "struct"        return T_STRUCT;
        "typedef"       return T_TYPEDEF;
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
                                if (L_lookup_typedef(L_lval, FALSE)) {
                                        return T_TYPE;
                                } else {
                                        return T_ID;
                                }
                        }
        $[0-9]+         {
                                /* Regular expression submatches */
                                MK_STRING_NODE(L_lval, yytext);
                                return T_ID;
                        }
        [0-9]*		{
                                MK_INT_NODE(L_lval, atoi(yytext));
                                return T_INT_LITERAL;
                        }
        [0-9]*\.[0-9]+	{
                                MK_DOUBLE_NODE(L_lval, atof(yytext));
                                return T_DOUBLE_LITERAL;
                        }
        "//".*("\r"|"\n"|"\r\n") tally_newlines(yytext, yyleng);
        [ \t\n\r]+      tally_newlines(yytext, yyleng);
        \"		yy_push_state(str_double); STRBUF_START();
        \'		yy_push_state(str_single); STRBUF_START();
        "/*"		yy_push_state(comment);
        "!~"[ \t]*"/"	yy_push_state(glob_re); STRBUF_START(); return T_BANGTWID;
        "=~"[ \t]*"/"	yy_push_state(glob_re); STRBUF_START(); return T_EQTWID;
}

<INITIAL>{
        "}"		return T_RBRACE;
}

<interpol>{
        "}"             {
                                yy_pop_state();
                                STRBUF_START();
                                return T_RIGHT_INTERPOL;
                        }
        "\\}"           return T_RBRACE;
}

<str_double>{
	\\n		STRBUF_ADD("\n", 1);
	\\t		STRBUF_ADD("\t", 1);
	\\(.|\n)	STRBUF_ADD(yytext+1, 1);
        "$"             STRBUF_ADD("$", 1);
	[^\\\"$]+	tally_newlines(yytext, yyleng); STRBUF_ADD(yytext, yyleng);
        "${"            {
				yy_push_state(interpol);
                                MK_STRING_NODE(L_lval, STRBUF_STRING());
                                STRBUF_STOP();
				return T_LEFT_INTERPOL;
			}
	\"		{
				yy_pop_state();
                                MK_STRING_NODE(L_lval, STRBUF_STRING());
                                STRBUF_STOP();
				return T_STR_LITERAL;
			}
}

<str_single>{
	\\n		STRBUF_ADD("\n", 1);
	\\t		STRBUF_ADD("\t", 1);
	\\(.|\n)	STRBUF_ADD(yytext+1, 1);
	[^\\\']+	tally_newlines(yytext, yyleng); STRBUF_ADD(yytext, yyleng);
	\'		{
				yy_pop_state();
                                MK_STRING_NODE(L_lval, STRBUF_STRING());
                                STRBUF_STOP();
				return T_STR_LITERAL;
			}
}

<comment>{
	[^*]+           tally_newlines(yytext, yyleng);
        "*"
	"*/"		yy_pop_state();
}

<glob_re>{
	[^\\/]+	        tally_newlines(yytext, yyleng); STRBUF_ADD(yytext, yyleng);
	\\(.|\n)	STRBUF_ADD(yytext+1, 1);
	"/"		{
                                yy_pop_state();
                                MK_STRING_NODE(L_lval, STRBUF_STRING());
                                STRBUF_STOP();
				return T_RE;
			}

}
        .		{       /* this is essentially an "else" */
                                fprintf(stderr, "illegal character %c\n", *yytext);
                                exit(1);
                        }


