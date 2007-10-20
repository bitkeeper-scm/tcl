%option	noyywrap
%option stack
%x re_modifier
%x glob_re
%x subst_re
%x comment
%x str_double
%x str_single
%x interpol
ID		([a-zA-Z_]|::)([0-9a-zA-Z_]|::)*
%{
#include <string.h>
#define	_PWD_H			// Some solaris9 conflict, we don't need pwd.h
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
extern char *L_source_file;
extern int L_token_offset;
extern int L_prev_token_len;

/* Keep track of the current offset in the input string: */
#define YY_USER_ACTION	L_token_offset += L_prev_token_len; \
			L_prev_token_len = yyleng;

/* The character that began the current regexp, so in m|foo| this is
 * '|'.
 *
 * XXX: since regexps are interpolated, they can nest, which
 * will fail unless they all use the same quote char. */
char re_quote_char;


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
	"+="		return T_EQPLUS;
	"-="		return T_EQMINUS;
	"*="		return T_EQSTAR;
	"/="		return T_EQSLASH;
	"%="		return T_EQPERC;
	"&="		return T_EQBITAND;
	"|="		return T_EQBITOR;
	"^="		return T_EQBITXOR;
	"<<="		return T_EQLSHIFT;
	">>="		return T_EQRSHIFT;
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
	"..."		return T_ELLIPSIS;
	"class"		return T_CLASS;
	"extern"	return T_EXTERN;
        "return"        return T_RETURN;
	"include"	return T_INCLUDE;
        "void"          return T_VOID;
        "string"        return T_STRING;
        "int"           return T_INT;
        "float"         return T_FLOAT;
        "hash"          return T_HASH;
        "poly"          return T_POLY;
        "var"           return T_VAR;

        "("[ \t]*"string"[ \t]*")"      return T_STRING_CAST;
        "("[ \t]*"tcl"[ \t]*")"         return T_TCL_CAST;
        "("[ \t]*"float"[ \t]*")"       return T_FLOAT_CAST;
        "("[ \t]*"int"[ \t]*")"         return T_INT_CAST;
        "("[ \t]*"hash"[ \t]*")"        return T_HASH_CAST;

        "if"		return T_IF;
        "else"		return T_ELSE;
        "unless"	return T_UNLESS;
        "while"         return T_WHILE;
        "do"            return T_DO;
        "for"           return T_FOR;
        "struct"        return T_STRUCT;
        "typedef"       return T_TYPEDEF;
        "defined"       return T_DEFINED;
	"foreach"	return T_FOREACH;
	"break"		return T_BREAK;
	"continue"	return T_CONTINUE;
	"as"		return T_AS;
	"in"		return T_IN;
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
        {ID}[ \t\n\r]*:	{
	  			int i, j;
                                MK_STRING_NODE(L_lval, yytext);
				((L_expression *)L_lval)->u.string[0] = '-';
				/* strip the whitespace */
				for (i=0, j=1; i<yyleng-1; i++) {
					switch (yytext[i]) {
					case ' ':
					case '\t':
					case '\n':
					case '\r':
						break;
					default:
						((L_expression *)L_lval)->u.string[j++] = yytext[i];
					}
				}
				((L_expression *)L_lval)->u.string[j] = '\0';
				return T_KEYWORD;
                        }
        {ID}		{
                                MK_STRING_NODE(L_lval, yytext);

                                if (L_lookup_typedef(L_lval, FALSE)) {
                                        return T_TYPE;
                                } else {
                                        return T_ID;
                                }
                        }
	([A-Z]|::)([0-9a-zA-Z]|::)*_\*	{
                                MK_STRING_NODE(L_lval, yytext);
				return T_PATTERN;
			}
        $[0-9]+         {
                                /* Regular expression submatches */
                                MK_STRING_NODE(L_lval, yytext);
                                return T_ID;
                        }
	/* XXX no hex literals like 0xff, etc., yet */
        [0-9]*		{
                                MK_INT_NODE(L_lval, atoi(yytext));
                                return T_INT_LITERAL;
                        }
        [0-9]*\.[0-9]+	{
                                MK_FLOAT_NODE(L_lval, atof(yytext));
                                return T_FLOAT_LITERAL;
                        }
        "//".*("\r"|"\n"|"\r\n") tally_newlines(yytext, yyleng);
        [ \t\n\r]+      tally_newlines(yytext, yyleng);
        \"		yy_push_state(str_double); STRBUF_START();
        \'		yy_push_state(str_single); STRBUF_START();
        "/*"		yy_push_state(comment);
        "=~"[ \t\r\n]*"m".	{
		yy_push_state(re_modifier);
		yy_push_state(glob_re);
		STRBUF_START();
		re_quote_char = *(yytext + yyleng - 1);
		return T_EQTWID;
	}
	/* if / is used to delimit the regexp, the m can be omitted */
        "=~"[ \t\r\n]*"/"	{
		yy_push_state(re_modifier);
		yy_push_state(glob_re);
		STRBUF_START();
		re_quote_char = '/';
		return T_EQTWID;
	}
	/* a substitution pattern */
        "=~"[ \t\r\n]*"s".	{
		yy_push_state(re_modifier);
		yy_push_state(subst_re);
		yy_push_state(glob_re);
		STRBUF_START();
		re_quote_char = *(yytext + yyleng - 1);
		return T_EQTWID;
	}
}

<INITIAL>{
        "}"		return T_RBRACE;
}

<interpol>{
        "}"             {
				STRBUF_START();
                                yy_pop_state();
                                return T_RIGHT_INTERPOL;
                        }
        "\\}"           return T_RBRACE;
}

<str_double>{
	\\r		STRBUF_ADD("\r", 1);
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
	\"[ \t\r\n]*\"	tally_newlines(yytext, yyleng);
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

<glob_re,subst_re>{
	\\n		STRBUF_ADD("\n", 1);
	\\t		STRBUF_ADD("\t", 1);
	\\(.|\n)	STRBUF_ADD(yytext+1, 1);
        "$"             STRBUF_ADD("$", 1);
        "${"            {
				yy_push_state(interpol);
                                MK_STRING_NODE(L_lval, STRBUF_STRING());
                                STRBUF_STOP();
				return T_LEFT_INTERPOL;
			}
	.		{
				if (*(yytext) == re_quote_char) {
	                                MK_STRING_NODE(L_lval, STRBUF_STRING());
					STRBUF_STOP();
					if (YYSTATE == subst_re) {
		                                yy_pop_state();
						return T_SUBST;
					} else {
		                                yy_pop_state();
						if (YYSTATE == subst_re) {
							STRBUF_START();
						}
						return T_RE;
					}
				} else {
					tally_newlines(yytext, yyleng);
					STRBUF_ADD(yytext, yyleng);
				}
			}

}
<re_modifier>{
	[ig]+		{
				MK_STRING_NODE(L_lval, yytext);
				yy_pop_state();
				return T_RE_MODIFIER;
			}
	.		{
				unput(yytext[0]);
				yy_pop_state();
				L_lval = NULL;
				return T_RE_MODIFIER;
			}
}
	\f		/* ignore page breaks */
        .		{       /* this is essentially an "else" */
                                fprintf(stderr, "%s:%d: L error: illegal character %c",
				    L_source_file, L_line_number, *yytext);
                                exit(1);
                        }

