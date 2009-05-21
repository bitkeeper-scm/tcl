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
     T_BANG = 260,
     T_BITAND = 261,
     T_BITOR = 262,
     T_BITNOT = 263,
     T_BITXOR = 264,
     T_BREAK = 265,
     T_CLASS = 266,
     T_COLON = 267,
     T_COMMA = 268,
     T_CONSTRUCTOR = 269,
     T_CONTINUE = 270,
     T_DEFINED = 271,
     T_DESTRUCTOR = 272,
     T_DO = 273,
     T_DOT = 274,
     T_DOTDOT = 275,
     T_ELLIPSIS = 276,
     T_ELSE = 277,
     T_EQ = 278,
     T_EQBITAND = 279,
     T_EQBITOR = 280,
     T_EQBITXOR = 281,
     T_EQDOT = 282,
     T_EQLSHIFT = 283,
     T_EQMINUS = 284,
     T_EQPERC = 285,
     T_EQPLUS = 286,
     T_EQRSHIFT = 287,
     T_EQSTAR = 288,
     T_EQSLASH = 289,
     T_EQTWID = 290,
     T_EQUALS = 291,
     T_EQUALEQUAL = 292,
     T_EXPAND = 293,
     T_EXTERN = 294,
     T_FLOAT = 295,
     T_FLOAT_LITERAL = 296,
     T_FOR = 297,
     T_FOREACH = 298,
     T_GOTO = 299,
     T_GE = 300,
     T_GREATER = 301,
     T_GREATEREQ = 302,
     T_GT = 303,
     T_ID = 304,
     T_IF = 305,
     T_INSTANCE = 306,
     T_INT = 307,
     T_INT_LITERAL = 308,
     T_LBRACE = 309,
     T_LBRACKET = 310,
     T_LE = 311,
     T_LEFT_INTERPOL = 312,
     T_LESSTHAN = 313,
     T_LESSTHANEQ = 314,
     T_LPAREN = 315,
     T_LSHIFT = 316,
     T_LT = 317,
     T_MINUS = 318,
     T_MINUSMINUS = 319,
     T_NE = 320,
     T_NOTEQUAL = 321,
     T_OROR = 322,
     T_PATTERN = 323,
     T_PERC = 324,
     T_PLUS = 325,
     T_PLUSPLUS = 326,
     T_POINTS = 327,
     T_POLY = 328,
     T_PRIVATE = 329,
     T_PUBLIC = 330,
     T_QUESTION = 331,
     T_RBRACE = 332,
     T_RBRACKET = 333,
     T_RE = 334,
     T_RE_MODIFIER = 335,
     T_RETURN = 336,
     T_RIGHT_INTERPOL = 337,
     T_RPAREN = 338,
     T_RSHIFT = 339,
     T_SEMI = 340,
     T_SLASH = 341,
     T_SPLIT = 342,
     T_STAR = 343,
     T_STR_BACKTICK = 344,
     T_STR_LITERAL = 345,
     T_STRCAT = 346,
     T_STRING = 347,
     T_STRUCT = 348,
     T_SUBST = 349,
     T_TYPE = 350,
     T_TYPEDEF = 351,
     T_UNLESS = 352,
     T_UNUSED = 353,
     T_VOID = 354,
     T_WHILE = 355,
     LOWEST = 356,
     ADDRESS = 357,
     UMINUS = 358,
     UPLUS = 359,
     PREFIX_INCDEC = 360,
     HIGHEST = 361
   };
#endif


/* Copy the first part of user declarations.  */
#line 1 "/Users/rob/bk/bk-tcl86-L-nobison-win/src/gui/tcltk/tcl/generic/Lgrammar.y"

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
#line 53 "/Users/rob/bk/bk-tcl86-L-nobison-win/src/gui/tcltk/tcl/generic/Lgrammar.y"
{
	long	i;
	double	f;
	char	*s;
	Tcl_Obj	*obj;
	Type	*Type;
	Expr	*Expr;
	Block	*Block;
	ForEach	*ForEach;
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
#line 192 "Lgrammar.h"
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


