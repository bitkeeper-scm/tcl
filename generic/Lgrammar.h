/* A Bison parser, made by GNU Bison 2.3.  */

/* Skeleton interface for Bison GLR parsers in C

   Copyright (C) 2002, 2003, 2004, 2005, 2006 Free Software Foundation, Inc.

   This program is free software; you can redistribute it and/or modify
   it under the terms of the GNU General Public License as published by
   the Free Software Foundation; either version 2, or (at your option)
   any later version.

   This program is distributed in the hope that it will be useful,
   but WITHOUT ANY WARRANTY; without even the implied warranty of
   MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
   GNU General Public License for more details.

   You should have received a copy of the GNU General Public License
   along with this program; if not, write to the Free Software
   Foundation, Inc., 51 Franklin Street, Fifth Floor,
   Boston, MA 02110-1301, USA.  */

/* As a special exception, you may create a larger work that contains
   part or all of the Bison parser skeleton and distribute that work
   under terms of your choice, so long as that work isn't itself a
   parser generator using the skeleton or a modified version thereof
   as a parser skeleton.  Alternatively, if you modify or redistribute
   the parser skeleton itself, you may (at your option) remove this
   special exception, which will cause the skeleton and the resulting
   Bison output files to be licensed under the GNU General Public
   License without this special exception.

   This special exception was added by the Free Software Foundation in
   version 2.2 of Bison.  */

/* Tokens.  */
#ifndef YYTOKENTYPE
# define YYTOKENTYPE
   /* Put the tokens into the symbol table, so that GDB and other debuggers
      know about them.  */
   enum yytokentype {
     END = 0,
     T_ANDAND = 258,
     T_ARROW = 259,
     T_ATTRIBUTE = 260,
     T_BANG = 261,
     T_BANGTWID = 262,
     T_BITAND = 263,
     T_BITOR = 264,
     T_BITNOT = 265,
     T_BITXOR = 266,
     T_BREAK = 267,
     T_CLASS = 268,
     T_COLON = 269,
     T_COMMA = 270,
     T_CONSTRUCTOR = 271,
     T_CONTINUE = 272,
     T_DEFINED = 273,
     T_DESTRUCTOR = 274,
     T_DO = 275,
     T_DOT = 276,
     T_DOTDOT = 277,
     T_ELLIPSIS = 278,
     T_ELSE = 279,
     T_EQ = 280,
     T_EQBITAND = 281,
     T_EQBITOR = 282,
     T_EQBITXOR = 283,
     T_EQDOT = 284,
     T_EQLSHIFT = 285,
     T_EQMINUS = 286,
     T_EQPERC = 287,
     T_EQPLUS = 288,
     T_EQRSHIFT = 289,
     T_EQSTAR = 290,
     T_EQSLASH = 291,
     T_EQTWID = 292,
     T_EQUALS = 293,
     T_EQUALEQUAL = 294,
     T_EXPAND = 295,
     T_EXTERN = 296,
     T_FLOAT = 297,
     T_FLOAT_LITERAL = 298,
     T_FOR = 299,
     T_FOREACH = 300,
     T_GOTO = 301,
     T_GE = 302,
     T_GREATER = 303,
     T_GREATEREQ = 304,
     T_GT = 305,
     T_ID = 306,
     T_LHTML_START = 307,
     T_IF = 308,
     T_INSTANCE = 309,
     T_INT = 310,
     T_INT_LITERAL = 311,
     T_LBRACE = 312,
     T_LBRACKET = 313,
     T_LE = 314,
     T_LEFT_INTERPOL = 315,
     T_LEFT_INTERPOL_RE = 316,
     T_START_BACKTICK = 317,
     T_LESSTHAN = 318,
     T_LESSTHANEQ = 319,
     T_LPAREN = 320,
     T_LSHIFT = 321,
     T_LT = 322,
     T_MINUS = 323,
     T_MINUSMINUS = 324,
     T_NE = 325,
     T_NOTEQUAL = 326,
     T_OROR = 327,
     T_PATTERN = 328,
     T_PERC = 329,
     T_PLUS = 330,
     T_PLUSPLUS = 331,
     T_POINTS = 332,
     T_POLY = 333,
     T_PRIVATE = 334,
     T_PUBLIC = 335,
     T_QUESTION = 336,
     T_RBRACE = 337,
     T_RBRACKET = 338,
     T_RE = 339,
     T_RE_MODIFIER = 340,
     T_RETURN = 341,
     T_RIGHT_INTERPOL = 342,
     T_RIGHT_INTERPOL_RE = 343,
     T_RPAREN = 344,
     T_RSHIFT = 345,
     T_TRY = 346,
     T_SEMI = 347,
     T_SLASH = 348,
     T_SPLIT = 349,
     T_STAR = 350,
     T_STR_BACKTICK = 351,
     T_STR_LITERAL = 352,
     T_STRCAT = 353,
     T_STRING = 354,
     T_STRUCT = 355,
     T_SUBST = 356,
     T_TYPE = 357,
     T_TYPEDEF = 358,
     T_UNLESS = 359,
     T_ARGUSED = 360,
     T_OPTIONAL = 361,
     T_MUSTBETYPE = 362,
     T_VOID = 363,
     T_WIDGET = 364,
     T_WHILE = 365,
     T_PRAGMA = 366,
     T_SWITCH = 367,
     T_CASE = 368,
     T_DEFAULT = 369,
     LOWEST = 370,
     ADDRESS = 371,
     UMINUS = 372,
     UPLUS = 373,
     PREFIX_INCDEC = 374,
     HIGHEST = 375
   };
#endif


/* Copy the first part of user declarations.  */
#line 1 "/Users/rob/bk/dev-L-try-catch/src/gui/tcltk/tcl/generic/Lgrammar.y"

/*
 * Copyright (c) 2006-2008 BitMover, Inc.
 */
#include <stdio.h>
#include "Lcompile.h"

/* L_lex is generated by flex. */
extern int	L_lex (void);

#define YYERROR_VERBOSE
#define L_error L_synerr


#if ! defined YYSTYPE && ! defined YYSTYPE_IS_DECLARED
typedef union YYSTYPE 
#line 53 "/Users/rob/bk/dev-L-try-catch/src/gui/tcltk/tcl/generic/Lgrammar.y"
{
	long	i;
	char	*s;
	Tcl_Obj	*obj;
	Type	*Type;
	Expr	*Expr;
	Block	*Block;
	ForEach	*ForEach;
	Switch	*Switch;
	Case	*Case;
	FnDecl	*FnDecl;
	Cond	*Cond;
	Loop	*Loop;
	Stmt	*Stmt;
	TopLev	*TopLev;
	VarDecl	*VarDecl;
	ClsDecl	*ClsDecl;
	struct {
		Type	*t;
		char	*s;
	} Typename;
}
/* Line 2616 of glr.c.  */
#line 207 "Lgrammar.h"
	YYSTYPE;
# define YYSTYPE_IS_DECLARED 1
# define YYSTYPE_IS_TRIVIAL 1
#endif

#if ! defined YYLTYPE && ! defined YYLTYPE_IS_DECLARED
typedef struct YYLTYPE
{

  int first_line;
  int first_column;
  int last_line;
  int last_column;

} YYLTYPE;
# define YYLTYPE_IS_DECLARED 1
# define YYLTYPE_IS_TRIVIAL 1
#endif


extern YYSTYPE L_lval;

extern YYLTYPE L_lloc;


