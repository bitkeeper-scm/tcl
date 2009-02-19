%option	noyywrap
%option noyy_top_state
%option stack
%x re_modifier
%s re_arg
%x glob_re
%x subst_re
%x comment
%x str_double
%x str_single
%x interpol
%x include
ID	([a-zA-Z_]|::)([0-9a-zA-Z_]|::)*
%{
/*
 * Copyright (c) 2006-2008 BitMover, Inc.
 */
#include <string.h>
#define	_PWD_H			// Some solaris9 conflict, we don't need pwd.h
#include "tclInt.h"
#include "Lcompile.h"
#include "Lgrammar.h"

private int	include_pop();
private int	include_push(FILE *f, char *name);
private FILE *	include_search(char *file);
private void	tally_newlines(char *s, int len);

// Stack for tracking include() statements.
#define INCLUDE_STACK_SZ	10
typedef struct {
	FILE	*file;
	char	*name;
	int	line;
	YY_BUFFER_STATE	buf;
} Include;

private char	re_quote_char;	// delim char that began the current regexp
private Tcl_Obj	*str;		// string collection buffer
private int	str_beg;	// source offset of string
private int	include_top;
private Include	include_stk[INCLUDE_STACK_SZ];

#define STRBUF_START(beg)			\
	do {					\
		str = Tcl_NewObj();		\
		Tcl_IncrRefCount(str);		\
		str_beg = (beg);		\
	} while (0)


#define STRBUF_STRING()		Tcl_GetString(str)

#define STRBUF_ADD(s, len)	Tcl_AppendToObj(str, s, len)

#define STRBUF_STOP(e)				\
	do {					\
		Tcl_DecrRefCount(str);		\
		str = NULL;			\
		L_lloc.beg = str_beg;		\
		L_lloc.end = (e);		\
	} while (0)

/*
 * Keep track of the current offset in the input string.
 * YY_USER_ACTION is run before each action.  Note that some actions
 * further modify L_lloc.
 */
#define YY_USER_ACTION					\
	do {						\
		L->token_offset += L->prev_token_len;	\
		L->prev_token_len = yyleng;		\
		L_lloc.beg = L->token_offset;		\
		L_lloc.end = L->token_offset + yyleng;	\
	} while (0);

/*
 * In case of errors, the start condition stack will be left in an
 * unknown state.  This function gives us a way to reset it.
 */
void L_lex_start()
{
	include_top = -1;
	BEGIN(0);
}

/*
 * Count the newlines in a string and add the number to L_line_number.
 */
private void
tally_newlines(char *s, int len)
{
	char	*end, *p;

	for (p = s, end = p + len; p < end; p++) {
		if (*p == '\n') {
			L->line++;
		} else if ((*p == '\r') && ((p+1) < end) && (*(p+1) != '\n')) {
			/* Mac line endings. */
			L->line++;
		}
	}
}

/*
 * Search for file in the include path and open it.  If the passed-in
 * name is not an absolute path, we currently look only in the
 * directory of the current script (i.e., dirname of [info script]).
 */
private FILE *
include_search(char *file)
{
	FILE	*f;
	char	*resolvedFile;
	Interp	*iPtr = (Interp *)L->interp;
	Tcl_Obj	*dir;
	Tcl_Obj *fileObj = Tcl_NewStringObj(file, -1);

	/* If the path is relative, make it absolute. */
	Tcl_IncrRefCount(fileObj);
	if ((Tcl_FSGetPathType(fileObj) == TCL_PATH_ABSOLUTE) ||
	    !iPtr->scriptFile) {
		resolvedFile = ckstrdup(file);
	} else {
		dir = TclPathPart(L->interp, iPtr->scriptFile,
				  TCL_PATH_DIRNAME);
		Tcl_AppendPrintfToObj(dir, "/%s", file);
		resolvedFile = ckstrdup(Tcl_GetString(dir));
		Tcl_DecrRefCount(dir);
	}
	Tcl_DecrRefCount(fileObj);
	f = fopen(resolvedFile, "r");
	ckfree(resolvedFile);
	return (f);
}

private int
include_push(FILE *f, char *name)
{
	YY_BUFFER_STATE buf;

	if (include_top >= INCLUDE_STACK_SZ) {
		L_err("include file nesting too deep -- aborting");
		while (include_pop()) ;
		return (0);
	} else {
		buf = yy_create_buffer(f, YY_BUF_SIZE);
		++include_top;
		include_stk[include_top].file = f;
		include_stk[include_top].name = L->file;
		include_stk[include_top].line = L->line;
		include_stk[include_top].buf  = YY_CURRENT_BUFFER;
		yy_switch_to_buffer(buf);
		L->file = name;
		L->line = 1;
		return (1);
	}
}

private int
include_pop()
{
	if (include_top >= 0) {
		L->file = include_stk[include_top].name;
		L->line = include_stk[include_top].line;
		fclose(include_stk[include_top].file);
		yy_delete_buffer(YY_CURRENT_BUFFER);
		yy_switch_to_buffer(include_stk[include_top].buf);
		--include_top;
		return (1);
	} else {
		return (0);
	}
}

%}
%%
<INITIAL,interpol,re_arg>{
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
	"<<"		return T_LSHIFT;
	">>"		return T_RSHIFT;
	"="		return T_EQUALS;
	";"		return T_SEMI;
	"."		return T_DOT;
	"..."		return T_ELLIPSIS;
	"class"		return T_CLASS;
	"extern"	return T_EXTERN;
	"return"	return T_RETURN;
	"void"		return T_VOID;
	"string"	return T_STRING;
	"int"		return T_INT;
	"float"		return T_FLOAT;
	"poly"		return T_POLY;
	"var"		return T_VAR;
	"widget"	return T_WIDGET;
	"split"		return T_SPLIT;
	"if"		return T_IF;
	"else"		return T_ELSE;
	"unless"	return T_UNLESS;
	"while"		return T_WHILE;
	"do"		return T_DO;
	"for"		return T_FOR;
	"struct"	return T_STRUCT;
	"typedef"	return T_TYPEDEF;
	"defined"	return T_DEFINED;
	"foreach"	return T_FOREACH;
	"break"		return T_BREAK;
	"continue"	return T_CONTINUE;
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
				tally_newlines(yytext, yyleng);
				L_lval.s = ckalloc(yyleng+1);
				L_lval.s[0] = '-';
				/* Strip the whitespace. */
				for (i=0, j=1; i<yyleng-1; i++) {
					switch (yytext[i]) {
					case ' ':
					case '\t':
					case '\n':
					case '\r':
						break;
					default:
						L_lval.s[j++] = yytext[i];
					}
				}
				L_lval.s[j] = '\0';
				return T_KEYWORD;
			}
	{ID}		{
				Type *t = L_typedef_lookup(yytext);
				if (t) {
					L_lval.Typename.s = ckstrdup(yytext);
					L_lval.Typename.t = t;
					return T_TYPE;
				} else {
					L_lval.s = ckstrdup(yytext);
					return T_ID;
				}
			}
	([A-Z]|::)([0-9a-zA-Z]|::)*_\*	{
				L_lval.s = ckstrdup(yytext);
				return T_PATTERN;
			}
	$[0-9]+		{
				/* Regular expression submatches */
				L_lval.s = ckstrdup(yytext);
				return T_ID;
			}
	[0-9]+		{
				// XXX - we don't handle constants > 32 bits
				L_lval.i = atoi(yytext);
				return T_INT_LITERAL;
			}
	0o[0-7]+	{
				L_lval.i = strtoul(yytext+2, 0, 8);
				return T_INT_LITERAL;
			}
	0x[0-9a-fA-F]+	{
				// XXX - we don't handle constants > 32 bits
				L_lval.i = strtoul(yytext+2, 0, 16);
				return T_INT_LITERAL;
			}
	[0-9]*\.[0-9]+	{
				L_lval.f = atof(yytext);
				return T_FLOAT_LITERAL;
			}
	^include[ \t]*\([ \t]*\" {
				BEGIN(include);
			}
	"//".*("\r"|"\n"|"\r\n") tally_newlines(yytext, yyleng);
	[ \t\n\r\f]+	tally_newlines(yytext, yyleng);
	\"		yy_push_state(str_double); STRBUF_START(L->token_offset);
	\'		yy_push_state(str_single); STRBUF_START(L->token_offset);
	"/*"		yy_push_state(comment);
	"=~"[ \t\r\n]*"m".	{
		tally_newlines(yytext, yyleng);
		yy_push_state(re_modifier);
		yy_push_state(glob_re);
		STRBUF_START(L_lloc.end - 2);	// next token starts at the "m"
		re_quote_char = *(yytext + yyleng - 1);
		L_lloc.end = L_lloc.beg + 2;	// this token spans the "=~"
		return T_EQTWID;
	}
	/* if / is used to delimit the regexp, the m can be omitted */
	"=~"[ \t\r\n]*"/"	{
		tally_newlines(yytext, yyleng);
		yy_push_state(re_modifier);
		yy_push_state(glob_re);
		STRBUF_START(L_lloc.end - 1);	// next token starts at the "/"
		re_quote_char = '/';
		L_lloc.end = L_lloc.beg + 2;	// this token spans the "=~"
		return T_EQTWID;
	}
	/* a substitution pattern */
	"=~"[ \t\r\n]*"s".	{
		tally_newlines(yytext, yyleng);
		yy_push_state(re_modifier);
		yy_push_state(subst_re);
		yy_push_state(glob_re);
		STRBUF_START(L_lloc.end - 2);	// next token starts at the "s"
		re_quote_char = *(yytext + yyleng - 1);
		L_lloc.end = L_lloc.beg + 2;	// this token spans the "=~"
		return T_EQTWID;
	}
}

<include>{
	[^\"]*\"[ \t]*\)[ \t]*;[ \t;]*	{
		int	len = strrchr(yytext, '"') - yytext;
		char	*name = ckstrndup(yytext, len);
		FILE	*f = include_search(name);

		unless (f) {
			L_err("cannot find include file %s", name);
		} else {
			/* This bails if includes nest too deeply. */
			unless (include_push(f, name)) yyterminate();
		}
		BEGIN(INITIAL);
	}
	.	{
		L_err("malformed include");
		BEGIN(INITIAL);
	}
}

<re_arg>{
	/*
	 * A regexp used as a function argument (e.g., in the "split"
	 * built-in).
	 */
	[ \t\r\n]*"/"	{
		tally_newlines(yytext, yyleng);
		yy_push_state(glob_re);
		STRBUF_START(L_lloc.end - 1);	// next token starts at the "/"
		re_quote_char = '/';
	}
	[ \t\r\n]*"m"[^a-zA-Z \t\r\n]	{
		tally_newlines(yytext, yyleng);
		yy_push_state(glob_re);
		STRBUF_START(L_lloc.end - 1);	// next token starts at the "/"
		re_quote_char = *(yytext + yyleng - 1);
	}
}

<INITIAL>{
	"}"		return T_RBRACE;
}

<interpol>{
	"}"		{
				STRBUF_START(L_lloc.end);
				yy_pop_state();
				return T_RIGHT_INTERPOL;
			}
	"\\}"		return T_RBRACE;
}

<str_double>{
	\\r		STRBUF_ADD("\r", 1);
	\\n		STRBUF_ADD("\n", 1);
	\\t		STRBUF_ADD("\t", 1);
	\\(.|\n)	STRBUF_ADD(yytext+1, 1);
	"$"		STRBUF_ADD("$", 1);
	[^\\\"$]+	{
				tally_newlines(yytext, yyleng);
				STRBUF_ADD(yytext, yyleng);
			}
	"${"		{
				yy_push_state(interpol);
				L_lval.s = ckstrdup(STRBUF_STRING());
				STRBUF_STOP(L_lloc.beg);
				return T_LEFT_INTERPOL;
			}
	\"[ \t\r\n]*\"	tally_newlines(yytext, yyleng);
	\"		{
				yy_pop_state();
				L_lval.s = ckstrdup(STRBUF_STRING());
				STRBUF_STOP(L_lloc.end);
				return T_STR_LITERAL;
			}
}

<str_single>{
	\\n		STRBUF_ADD("\n", 1);
	\\t		STRBUF_ADD("\t", 1);
	\\(.|\n)	STRBUF_ADD(yytext+1, 1);
	[^\\\']+	{
				tally_newlines(yytext, yyleng);
				STRBUF_ADD(yytext, yyleng);
			}
	\'		{
				yy_pop_state();
				L_lval.s = ckstrdup(STRBUF_STRING());
				STRBUF_STOP(L_lloc.end);
				return T_STR_LITERAL;
			}
}

<comment>{
	[^*]+		tally_newlines(yytext, yyleng);
	"*"
	"*/"		yy_pop_state();
}

<glob_re,subst_re>{
	"${"		{
				yy_push_state(interpol);
				L_lval.s = ckstrdup(STRBUF_STRING());
				STRBUF_STOP(L_lloc.beg);
				return T_LEFT_INTERPOL;
			}
	\\.		{
				if (yytext[1] == re_quote_char) {
					STRBUF_ADD(yytext+1, 1);
				} else {
					STRBUF_ADD(yytext, yyleng);
				}
			}
	.		{
				if (*(yytext) == re_quote_char) {
					L_lval.s = ckstrdup(STRBUF_STRING());
					STRBUF_STOP(L_lloc.end);
					if (YYSTATE == subst_re) {
						yy_pop_state();
						return T_SUBST;
					} else {
						yy_pop_state();
						if (YYSTATE == subst_re) {
							STRBUF_START(L_lloc.end);
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
				L_lval.s = ckstrdup(yytext);
				yy_pop_state();
				return T_RE_MODIFIER;
			}
	.		{
				unput(yytext[0]);
				/*
				 * This is ugly, but since we just
				 * unput a character, we have to undo
				 * the effects of the YY_USER_ACTION
				 * rule to keep the source-file
				 * offsets correct.  We rely on the
				 * fact that the previous token must
				 * have been a single character,
				 * matched by the "." rule in
				 * <glob_re,subst_re> above.
				 */
				--L->token_offset;
				--L_lloc.end;  // now, L_lloc.beg == L_lloc.end
				yy_pop_state();
				L_lval.s = ckstrdup("");
				return T_RE_MODIFIER;
			}
}
	.		{
				/* This rule matches a char if no other does. */
				L_err("illegal character '%c'", *yytext);
				yyterminate();
			}
	<<EOF>>		{
				unless (include_pop()) yyterminate();
			}
%%
void
L_lex_begReArg()
{
	yy_push_state(re_arg);
}

void
L_lex_endReArg()
{
	yy_pop_state();
}
