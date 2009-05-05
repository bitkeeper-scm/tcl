%{
/*
 * Copyright (c) 2006-2008 BitMover, Inc.
 */
#include <stdio.h>
#include "Lcompile.h"

/* L_lex is generated by lex */
extern int	L_lex (void);

#define YYERROR_VERBOSE
#define L_error L_err
%}

/*
 * We need a GLR parser because of a shift/reduce conflict introduced
 * by hash-element types.  This production is the culprit:
 *
 * array_or_hash_type: "{" scalar_type_specifier "}"
 *
 * This introduced a shift/reduce conflict on "{" due to "{" being in
 * the FOLLOW set of scalar_type_specifier because "{" can follow
 * type_specifier in function_decl.  For example, after you
 * have seen
 *
 *    struct s
 *
 * and "{" is the next token, the parser can't tell whether to shift
 * and proceed to parse a struct_specifier that declares a struct:
 *
 *    struct s { int x,y; }
 *
 * or whether to reduce and proceed in to a array_or_hash_type:
 *
 *    struct s { int } f() {}
 *
 * To make this grammar LALR(1) seemed difficult.  The grammar seems
 * to want to be LALR(3) perhaps(?).  The best we could do was to extend
 * the language by pushing the array_or_hash_type syntax down into
 * scalar_type_specifier and struct_specifier.  This would allow
 * inputs that should be syntax errors, so extra checking would have
 * been needed to detect these cases.
 *
 * The GLR parser has no problem with this type of conflict and keeps
 * the grammar nice.
 *
 * Note that the %expect 1 below is for this conflict.  Although the
 * GLR parser handles it, it is still reported as a conflict.
 */
%glr-parser
%expect 1

%union {
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

%token T_LPAREN "("
%token T_RPAREN ")"
%token T_LBRACE "{"
%token T_RBRACE "}"
%token T_LBRACKET "["
%token T_RBRACKET "]"
%token T_SEMI ";"
%token T_EXTERN
%token T_EQTWID
%token T_IF
%token T_UNLESS
%token T_ELSE
%token T_RETURN
%token T_COMMA ","
%token T_DOT "."
%token T_STRCAT
%token T_POINTS "->"
%token T_ARROW "=>"
%token T_RIGHT_INTERPOL T_PLUSPLUS T_MINUSMINUS
%token <s> T_ID T_STR_LITERAL T_LEFT_INTERPOL T_RE T_SUBST T_RE_MODIFIER
%token <s> T_STR_BACKTICK T_PATTERN T_KEYWORD
%token <i> T_INT_LITERAL
%token <f> T_FLOAT_LITERAL
%token <Typename> T_TYPE
%token T_WHILE T_FOR T_DO T_STRUCT T_TYPEDEF T_DEFINED
%token T_POLY T_VOID T_VAR T_STRING T_INT T_FLOAT
%token T_FOREACH T_IN T_BREAK T_CONTINUE T_ELLIPSIS T_CLASS
%token T_SPLIT T_DOTDOT T_INSTANCE T_PRIVATE T_PUBLIC
%token T_CONSTRUCTOR T_DESTRUCTOR T_EXPAND T_UNUSED

/*
 * This follows the C operator-precedence rules, from lowest to
 * highest precedence.
 */
%left LOWEST
%left T_COMMA
%nonassoc T_ELSE T_SEMI
%right T_EQUALS T_EQPLUS T_EQMINUS T_EQSTAR T_EQSLASH T_EQPERC
       T_EQBITAND T_EQBITOR T_EQBITXOR T_EQLSHIFT T_EQRSHIFT T_EQDOT
%left T_OROR
%left T_ANDAND
%left T_BITOR
%left T_BITXOR
%left T_BITAND
%left T_EQ T_NE T_EQUALEQUAL T_NOTEQUAL T_EQTWID
%left T_GT T_GE T_LT T_LE T_GREATER T_GREATEREQ T_LESSTHAN T_LESSTHANEQ
%left T_LSHIFT T_RSHIFT
%left T_PLUS T_MINUS T_STRCAT
%left T_STAR T_SLASH T_PERC
%right PREFIX_INCDEC UPLUS UMINUS T_BANG T_BITNOT ADDRESS
%left T_LBRACKET T_LBRACE T_RBRACE T_DOT T_POINTS T_PLUSPLUS T_MINUSMINUS
%left HIGHEST

%type <TopLev> toplevel_code
%type <ClsDecl> class_decl
%type <FnDecl> function_decl fundecl_tail fundecl_tail1
%type <Stmt> stmt single_stmt compound_stmt stmt_list optional_else
%type <Cond> selection_stmt
%type <Loop> iteration_stmt
%type <ForEach> foreach_stmt
%type <Expr> expr expression_stmt argument_expr_list opt_arg re_or_string
%type <Expr> id id_list string_literal cmdsubst_literal dotted_id
%type <Expr> regexp_literal subst_literal interpolated_expr
%type <Expr> list list_element
%type <VarDecl> parameter_list parameter_decl_list parameter_decl
%type <VarDecl> declaration_list declaration declaration2
%type <VarDecl> init_declarator_list declarator_list init_declarator
%type <VarDecl> declarator struct_decl_list struct_decl
%type <VarDecl> struct_declarator_list
%type <Type> array_or_hash_type type_specifier scalar_type_specifier
%type <Type> struct_specifier
%type <obj> dotted_id_1
%type <i> decl_qualifier

%%

start:	  toplevel_code
	{
		REVERSE(TopLev, next, $1);
		L->ast = $1;
	}
	;

toplevel_code:
	  toplevel_code class_decl
	{
		$$ = ast_mkTopLevel(L_TOPLEVEL_CLASS, $1, @1.beg, @2.end);
		$$->u.class = $2;
	}
	| toplevel_code function_decl
	{
		$$ = ast_mkTopLevel(L_TOPLEVEL_FUN, $1, @1.beg, @2.end);
		$2->decl->flags |= DECL_FN;
		if ($2->decl->flags & DECL_PRIVATE) {
			$2->decl->flags |= SCOPE_SCRIPT;
		} else {
			$2->decl->flags |= SCOPE_GLOBAL;
		}
		$$->u.fun = $2;
	}
	| toplevel_code struct_specifier ";"
	{
		$$ = $1;  // nothing more to do
	}
	| toplevel_code T_TYPEDEF type_specifier declarator ";"
	{
		L_set_declBaseType($4, $3);
		L_typedef_store($4);
		$$ = $1;  // nothing more to do
	}
	| toplevel_code declaration
	{
		// Global variable declaration.
		VarDecl *v;
		$$ = ast_mkTopLevel(L_TOPLEVEL_GLOBAL, $1, @1.beg, @2.end);
		for (v = $2; v; v = v->next) {
			v->flags |= DECL_GLOBAL_VAR;
			if ($2->flags & DECL_PRIVATE) {
				v->flags |= SCOPE_SCRIPT;
			} else {
				v->flags |= SCOPE_GLOBAL;
			}
		}
		$$->u.global = $2;
	}
	| toplevel_code stmt
	{
		// Top-level statement.
		$$ = ast_mkTopLevel(L_TOPLEVEL_STMT, $1, @1.beg, @2.end);
		$$->u.stmt = $2;
	}
	| /* epsilon */		{ $$ = NULL; }
	;

class_decl:
	  T_CLASS id "{"
	{
		/*
		 * Alloc the VarDecl now and associate it with
		 * the class name so that it is available while
		 * parsing the class body.
		 */
		Type	*t = type_mkClass(PER_INTERP);
		VarDecl	*d = ast_mkVarDecl(t, $2, @1.beg, 0);
		ClsDecl	*c = ast_mkClsDecl(d, @1.beg, 0);
		L_typedef_store(d);
		$<ClsDecl>$ = c;
	}
	class_code "}"
	{
		$$ = $<ClsDecl>4;
		$$->node.end       = @6.end;
		$$->decl->node.end = @6.end;
		/* If constructor or destructor were omitted, make defaults. */
		unless ($$->constructor) {
			$$->constructor = ast_mkConstructor($$);
		}
		unless ($$->destructor) {
			$$->destructor = ast_mkDestructor($$);
		}
	}
	;

class_code:
	  class_code T_INSTANCE "{" declaration_list "}" opt_semi
	{
		VarDecl	*v;
		ClsDecl	*clsdecl = $<ClsDecl>0;
		REVERSE(VarDecl, next, $4);
		for (v = $4; v; v = v->next) {
			v->clsdecl = clsdecl;
			v->flags  |= SCOPE_CLASS | DECL_CLASS_INST_VAR;
			unless (v->flags & (DECL_PUBLIC | DECL_PRIVATE)) {
				L_errf(v, "class instance variable %s not "
				       "declared public or private",
				       v->id->u.string);
				v->flags |= DECL_PUBLIC;
			}
		}
		APPEND_OR_SET(VarDecl, next, clsdecl->instvars, $4);
	}
	| class_code T_INSTANCE "{" "}" opt_semi
	| class_code declaration
	{
		VarDecl	*v;
		ClsDecl	*clsdecl = $<ClsDecl>0;
		REVERSE(VarDecl, next, $2);
		for (v = $2; v; v = v->next) {
			v->clsdecl = clsdecl;
			v->flags  |= SCOPE_CLASS | DECL_CLASS_VAR;
			unless (v->flags & (DECL_PUBLIC | DECL_PRIVATE)) {
				L_errf(v, "class variable %s not "
				       "declared public or private",
				       v->id->u.string);
				v->flags |= DECL_PUBLIC;
			}
		}
		APPEND_OR_SET(VarDecl, next, clsdecl->clsvars, $2);
	}
	| class_code struct_specifier ";"
	| class_code T_TYPEDEF type_specifier declarator ";"
	{
		L_set_declBaseType($4, $3);
		L_typedef_store($4);
	}
	| class_code function_decl
	{
		ClsDecl	*clsdecl = $<ClsDecl>0;
		$2->decl->clsdecl = clsdecl;
		$2->decl->flags  |= DECL_CLASS_FN;
		unless ($2->decl->flags & DECL_PRIVATE) {
			$2->decl->flags |= SCOPE_GLOBAL | DECL_PUBLIC;
		} else {
			$2->decl->flags |= SCOPE_CLASS;
			$2->decl->tclprefix = cksprintf("_L_class_%s_",
						clsdecl->decl->id->u.string);
		}
		APPEND_OR_SET(FnDecl, next, clsdecl->fns, $2);
	}
	| class_code T_CONSTRUCTOR fundecl_tail
	{
		ClsDecl	*clsdecl = $<ClsDecl>0;
		$3->decl->type->base_type = clsdecl->decl->type;
		$3->decl->clsdecl = clsdecl;
		$3->decl->flags  |= SCOPE_GLOBAL | DECL_CLASS_FN | DECL_PUBLIC |
			DECL_CLASS_CONST;
		if (clsdecl->constructor) {
			L_errf($3, "class constructor already declared");
		} else {
			clsdecl->constructor = $3;
		}
	}
	| class_code T_DESTRUCTOR fundecl_tail
	{
		ClsDecl	*clsdecl = $<ClsDecl>0;
		$3->decl->type->base_type = L_void;
		$3->decl->clsdecl = clsdecl;
		$3->decl->flags  |= SCOPE_GLOBAL | DECL_CLASS_FN | DECL_PUBLIC |
			DECL_CLASS_DESTR;
		if (clsdecl->destructor) {
			L_errf($3, "class destructor already declared");
		} else {
			clsdecl->destructor = $3;
		}
	}
	| /* epsilon */
	;

opt_semi:
	  ";"
	| /* epsilon */
	;

function_decl:
	  type_specifier fundecl_tail
	{
		$2->decl->type->base_type = $1;
		$$ = $2;
		$$->node.beg = @1.beg;
	}
	| decl_qualifier type_specifier fundecl_tail
	{
		$3->decl->type->base_type = $2;
		$3->decl->flags |= $1;
		$$ = $3;
		$$->node.beg = @1.beg;
	}
	;

fundecl_tail:
	  id fundecl_tail1
	{
		$2->decl->id = $1;
		$$ = $2;
		$$->node.beg = @1.beg;
	}
	| T_PATTERN fundecl_tail1
	{
		VarDecl	*new_param;
		Expr	*dollar1 = ast_mkId("$1", @2.beg, @2.end);

		$2->decl->id = ast_mkId($1, @1.beg, @1.end);
		ckfree($1);
		$$ = $2;
		$$->node.beg = @1.beg;
		/* Prepend a new arg "$1" as the first formal. */
		new_param = ast_mkVarDecl(L_string, dollar1, @1.beg, @2.end);
		new_param->flags = SCOPE_LOCAL | DECL_LOCAL_VAR;
		new_param->next = $2->decl->type->u.func.formals;
		$2->decl->type->u.func.formals = new_param;
	}
	;

fundecl_tail1:
	  "(" parameter_list ")" compound_stmt
	{
		Type	*type = type_mkFunc(NULL, $2, PER_INTERP);
		VarDecl	*decl = ast_mkVarDecl(type, NULL, @1.beg, @3.end);
		$$ = ast_mkFnDecl(decl, $4->u.block, @1.beg, @4.end);
	}
	| "(" parameter_list ")" ";"
	{
		Type	*type = type_mkFunc(NULL, $2, PER_INTERP);
		VarDecl	*decl = ast_mkVarDecl(type, NULL, @1.beg, @3.end);
		$$ = ast_mkFnDecl(decl, NULL, @1.beg, @4.end);
	}
	;

stmt:
	  single_stmt	{ $$ = $1; if (L->interactive) YYACCEPT; }
	| compound_stmt	{ $$ = $1; if (L->interactive) YYACCEPT; }
	;

single_stmt:
	  selection_stmt
	{
		$$ = ast_mkStmt(L_STMT_COND, NULL, @1.beg, @1.end);
		$$->u.cond = $1;
	}
	| iteration_stmt
	{
		$$ = ast_mkStmt(L_STMT_LOOP, NULL, @1.beg, @1.end);
		$$->u.loop = $1;
	}
	| foreach_stmt
	{
		$$ = ast_mkStmt(L_STMT_FOREACH, NULL, @1.beg, @1.end);
		$$->u.foreach = $1;
	}
	| expr ";"
	{
		$$ = ast_mkStmt(L_STMT_EXPR, NULL, @1.beg, @1.end);
		$$->u.expr = $1;
	}
	| T_BREAK ";"
	{
		$$ = ast_mkStmt(L_STMT_BREAK, NULL, @1.beg, @1.end);
	}
	| T_CONTINUE ";"
	{
		$$ = ast_mkStmt(L_STMT_CONTINUE, NULL, @1.beg, @1.end);
	}
	| T_RETURN ";"
	{
		$$ = ast_mkStmt(L_STMT_RETURN, NULL, @1.beg, @1.end);
	}
	| T_RETURN expr ";"
	{
		$$ = ast_mkStmt(L_STMT_RETURN, NULL, @1.beg, @2.end);
		$$->u.expr = $2;
	}
	| ";"	{ $$ = NULL; }
	;

selection_stmt:
	  T_IF "(" expr ")" compound_stmt optional_else
	{
		$$ = ast_mkIfUnless($3, $5, $6, @1.beg, @6.end);
	}
	/* If you have no curly braces, you get no else. */
	| T_IF "(" expr ")" single_stmt
	{
		$$ = ast_mkIfUnless($3, $5, NULL, @1.beg, @5.end);
	}
	| T_UNLESS "(" expr ")" compound_stmt optional_else
	{
		$$ = ast_mkIfUnless($3, $6, $5, @1.beg, @6.end);
	}
	| T_UNLESS "(" expr ")" single_stmt
	{
		$$ = ast_mkIfUnless($3, NULL, $5, @1.beg, @5.end);
	}
	;

optional_else:
	/* Else clause must either have curly braces or be another if/unless. */
	  T_ELSE compound_stmt
	{
		$$ = $2;
		$$->node.beg = @1.beg;
	}
	| T_ELSE selection_stmt
	{
		$$ = ast_mkStmt(L_STMT_COND, NULL, @1.beg, @2.end);
		$$->u.cond = $2;
	}
	| /* epsilon */		{ $$ = NULL; }
	;

iteration_stmt:
	  T_WHILE "(" expr ")" stmt
	{
		$$ = ast_mkLoop(L_LOOP_WHILE, NULL, $3, NULL, $5,
				@1.beg, @5.end);
	}
	| T_DO stmt T_WHILE "(" expr ")" ";"
	{
		$$ = ast_mkLoop(L_LOOP_DO, NULL, $5, NULL, $2, @1.beg, @6.end);
	}
	| T_FOR "(" expression_stmt expression_stmt ")" stmt
	{
		$$ = ast_mkLoop(L_LOOP_FOR, $3, $4, NULL, $6, @1.beg, @6.end);
	}
	| T_FOR "(" expression_stmt expression_stmt expr ")" stmt
	{
		$$ = ast_mkLoop(L_LOOP_FOR, $3, $4, $5, $7, @1.beg, @7.end);
	}
	;

foreach_stmt:
	  T_FOREACH "(" id "=>" id T_IN expr ")" stmt
	{
		$$ = ast_mkForeach($7, $3, $5, $9, @1.beg, @9.end);
	}
	| T_FOREACH "(" id_list T_IN expr ")" stmt
	{
		$$ = ast_mkForeach($5, $3, NULL, $7, @1.beg, @7.end);
	}
	;

expression_stmt
	: ";"		{ $$ = NULL; }
	| expr ";"
	;

stmt_list:
	  stmt
	| stmt_list stmt
	{
		if ($2) {
			$2->next = $1;
			$$ = $2;
		} else {
			// Empty stmt.
			$$ = $1;
		}
	}
	;

parameter_list:
	  parameter_decl_list
	{
		VarDecl *v;
		REVERSE(VarDecl, next, $1);
		for (v = $1; v; v = v->next) {
			v->flags |= SCOPE_LOCAL | DECL_LOCAL_VAR;
		}
		$$ = $1;
		/*
		 * Special case a parameter list of "void" -- a single
		 * formal of type void with no arg name.  This really
		 * means there are no args.
		 */
		if ($1 && !$1->next && !$1->id && ($1->type == L_void)) {
			$$ = NULL;
		}
	}
	| /* epsilon */	{ $$ = NULL; }
	;

parameter_decl_list:
	  parameter_decl
	| parameter_decl_list "," parameter_decl
	{
		$3->next = $1;
		$$ = $3;
		$$->node.beg = @1.beg;
	}
	;

parameter_decl:
	  type_specifier
	{
		$$ = ast_mkVarDecl($1, NULL, @1.beg, @1.end);
		if (isnameoftype($1)) $$->flags |= DECL_REF;
	}
	| type_specifier declarator
	{
		L_set_declBaseType($2, $1);
		$$ = $2;
		$$->node.beg = @1.beg;
	}
	| T_UNUSED type_specifier declarator
	{
		L_set_declBaseType($3, $2);
		$$ = $3;
		$$->flags |= DECL_UNUSED;
		$$->node.beg = @1.beg;
	}
	| T_ELLIPSIS id
	{
		Type *t = type_mkArray(NULL, L_poly, PER_INTERP);
		$$ = ast_mkVarDecl(t, $2, @1.beg, @2.end);
		$$->flags |= DECL_REST_ARG;
	}
	| T_UNUSED T_ELLIPSIS id
	{
		Type *t = type_mkArray(NULL, L_poly, PER_INTERP);
		$$ = ast_mkVarDecl(t, $3, @1.beg, @3.end);
		$$->flags |= DECL_REST_ARG | DECL_UNUSED;
	}
	;

argument_expr_list:
	  expr %prec T_COMMA
	| T_KEYWORD
	{
		$$ = ast_mkConst(L_string, @1.beg, @1.end);
		$$->u.string = $1;
	}
	| T_KEYWORD expr %prec T_COMMA
	{
		Expr *e = ast_mkConst(L_string, @1.beg, @1.end);
		e->u.string = $1;
		$2->next = e;
		$$ = $2;
		$$->node.beg = @1.beg;
	}
	| argument_expr_list "," expr
	{
		$3->next = $1;
		$$ = $3;
		$$->node.end = @3.end;
	}
	| argument_expr_list "," T_KEYWORD
	{
		Expr *e = ast_mkConst(L_string, @3.beg, @3.end);
		e->u.string = $3;
		e->next = $1;
		$$ = e;
		$$->node.end = @3.end;
	}
	| argument_expr_list "," T_KEYWORD expr %prec T_COMMA
	{
		Expr *e = ast_mkConst(L_string, @3.beg, @3.end);
		e->u.string = $3;
		$4->next = e;
		e->next = $1;
		$$ = $4;
		$$->node.end = @4.end;
	}
	;

expr:
	  "(" expr ")"
	{
		$$ = $2;
		$$->node.beg = @1.beg;
		$$->node.end = @3.end;
	}
	| "(" type_specifier ")" expr %prec PREFIX_INCDEC
	{
		// This is a binop where an arg is a Type*.
		$$ = ast_mkBinOp(L_OP_CAST, (Expr *)$2, $4, @1.beg, @4.end);
	}
	| "(" T_EXPAND ")" expr %prec PREFIX_INCDEC
	{
		$$ = ast_mkUnOp(L_OP_EXPAND, $4, @1.beg, @4.end);
	}
	| "(" T_EXPAND id ")" expr %prec PREFIX_INCDEC
	{
		/*
		 * This rule is for (expand all).  It's an error if id
		 * is not "all".
		 */
		unless (!strcmp($3->u.string, "all")) {
			L_errf($3, "only (expand) and (expand all) are legal");
		}
		$$ = ast_mkUnOp(L_OP_EXPAND_ALL, $5, @1.beg, @5.end);
	}
	| T_BANG expr
	{
		$$ = ast_mkUnOp(L_OP_BANG, $2, @1.beg, @2.end);
	}
	| T_BITNOT expr
	{
		$$ = ast_mkUnOp(L_OP_BITNOT, $2, @1.beg, @2.end);
	}
	| T_BITAND expr %prec ADDRESS
	{
		$$ = ast_mkUnOp(L_OP_ADDROF, $2, @1.beg, @2.end);
	}
	| T_MINUS expr %prec UMINUS
	{
		$$ = ast_mkUnOp(L_OP_UMINUS, $2, @1.beg, @2.end);
	}
	| T_PLUS expr %prec UPLUS
	{
		$$ = ast_mkUnOp(L_OP_UPLUS, $2, @1.beg, @2.end);
	}
	| T_PLUSPLUS expr %prec PREFIX_INCDEC
	{
		$$ = ast_mkUnOp(L_OP_PLUSPLUS_PRE, $2, @1.beg, @2.end);
	}
	| T_MINUSMINUS expr %prec PREFIX_INCDEC
	{
		$$ = ast_mkUnOp(L_OP_MINUSMINUS_PRE, $2, @1.beg, @2.end);
	}
	| expr T_PLUSPLUS
	{
		$$ = ast_mkUnOp(L_OP_PLUSPLUS_POST, $1, @1.beg, @2.end);
	}
	| expr T_MINUSMINUS
	{
		$$ = ast_mkUnOp(L_OP_MINUSMINUS_POST, $1, @1.beg, @2.end);
	}
	| expr T_EQTWID regexp_literal T_RE_MODIFIER
	{
		if (strchr($4, 'i')) $3->flags |= L_EXPR_RE_I;
		if (strchr($4, 'g')) $3->flags |= L_EXPR_RE_G;
		$$ = ast_mkBinOp(L_OP_EQTWID, $1, $3, @1.beg, @4.end);
		ckfree($4);
	}
	| expr T_EQTWID regexp_literal subst_literal T_RE_MODIFIER
	{
		if (strchr($5, 'i')) $3->flags |= L_EXPR_RE_I;
		if (strchr($5, 'g')) $3->flags |= L_EXPR_RE_G;
		$$ = ast_mkTrinOp(L_OP_EQTWID, $1, $3, $4, @1.beg, @5.end);
		ckfree($5);
	}
	| expr T_STAR expr
	{
		$$ = ast_mkBinOp(L_OP_STAR, $1, $3, @1.beg, @3.end);
	}
	| expr T_SLASH expr
	{
		$$ = ast_mkBinOp(L_OP_SLASH, $1, $3, @1.beg, @3.end);
	}
	| expr T_PERC expr
	{
		$$ = ast_mkBinOp(L_OP_PERC, $1, $3, @1.beg, @3.end);
	}
	| expr T_PLUS expr
	{
		$$ = ast_mkBinOp(L_OP_PLUS, $1, $3, @1.beg, @3.end);
	}
	| expr T_MINUS expr
	{
		$$ = ast_mkBinOp(L_OP_MINUS, $1, $3, @1.beg, @3.end);
	}
	| expr T_EQ expr
	{
		$$ = ast_mkBinOp(L_OP_STR_EQ, $1, $3, @1.beg, @3.end);
	}
	| expr T_NE expr
	{
		$$ = ast_mkBinOp(L_OP_STR_NE, $1, $3, @1.beg, @3.end);
	}
	| expr T_LT expr
	{
		$$ = ast_mkBinOp(L_OP_STR_LT, $1, $3, @1.beg, @3.end);
	}
	| expr T_LE expr
	{
		$$ = ast_mkBinOp(L_OP_STR_LE, $1, $3, @1.beg, @3.end);
	}
	| expr T_GT expr
	{
		$$ = ast_mkBinOp(L_OP_STR_GT, $1, $3, @1.beg, @3.end);
	}
	| expr T_GE expr
	{
		$$ = ast_mkBinOp(L_OP_STR_GE, $1, $3, @1.beg, @3.end);
	}
	| expr T_EQUALEQUAL expr
	{
		$$ = ast_mkBinOp(L_OP_EQUALEQUAL, $1, $3, @1.beg, @3.end);
	}
	| expr T_NOTEQUAL expr
	{
		$$ = ast_mkBinOp(L_OP_NOTEQUAL, $1, $3, @1.beg, @3.end);
	}
	| expr T_GREATER expr
	{
		$$ = ast_mkBinOp(L_OP_GREATER, $1, $3, @1.beg, @3.end);
	}
	| expr T_GREATEREQ expr
	{
		$$ = ast_mkBinOp(L_OP_GREATEREQ, $1, $3, @1.beg, @3.end);
	}
	| expr T_LESSTHAN expr
	{
		$$ = ast_mkBinOp(L_OP_LESSTHAN, $1, $3, @1.beg, @3.end);
	}
	| expr T_LESSTHANEQ expr
	{
		$$ = ast_mkBinOp(L_OP_LESSTHANEQ, $1, $3, @1.beg, @3.end);
	}
	| expr T_ANDAND expr
	{
		$$ = ast_mkBinOp(L_OP_ANDAND, $1, $3, @1.beg, @3.end);
	}
	| expr T_OROR expr
	{
		$$ = ast_mkBinOp(L_OP_OROR, $1, $3, @1.beg, @3.end);
	}
	| expr T_LSHIFT expr
	{
		$$ = ast_mkBinOp(L_OP_LSHIFT, $1, $3, @1.beg, @3.end);
	}
	| expr T_RSHIFT expr
	{
		$$ = ast_mkBinOp(L_OP_RSHIFT, $1, $3, @1.beg, @3.end);
	}
	| expr T_BITOR expr
	{
		$$ = ast_mkBinOp(L_OP_BITOR, $1, $3, @1.beg, @3.end);
	}
	| expr T_BITAND expr
	{
		$$ = ast_mkBinOp(L_OP_BITAND, $1, $3, @1.beg, @3.end);
	}
	| expr T_BITXOR expr
	{
		$$ = ast_mkBinOp(L_OP_BITXOR, $1, $3, @1.beg, @3.end);
	}
	| id
	| string_literal
	| cmdsubst_literal
	| T_INT_LITERAL
	{
		$$ = ast_mkConst(L_int, @1.beg, @1.end);
		$$->u.integer = $1;
	}
	| T_FLOAT_LITERAL
	{
		$$ = ast_mkConst(L_float, @1.beg, @1.end);
		$$->u.flote = $1;
	}
	| id "(" argument_expr_list ")"
	{
		REVERSE(Expr, next, $3);
		$$ = ast_mkFnCall($1, $3, @1.beg, @4.end);
	}
	| id "(" ")"
	{
		$$ = ast_mkFnCall($1, NULL, @1.beg, @3.end);
	}
	| T_STRING "(" argument_expr_list ")"
	{
		Expr *id = ast_mkId("string", @1.beg, @1.end);
		REVERSE(Expr, next, $3);
		$$ = ast_mkFnCall(id, $3, @1.beg, @4.end);
	}
	/*
	 * L_lex_begReArg() and L_lex_endReArg() tell the
	 * scanner to start or stop recognizing a regexp.
	 */
	| T_SPLIT "(" expr begin_re_arg
	  "," re_or_string { L_lex_endReArg(); }
	  opt_arg ")"
	{
		Expr *id = ast_mkId("split", @1.beg, @1.end);
		$3->next = $6;
		$6->next = $8;
		$$ = ast_mkFnCall(id, $3, @1.beg, @9.end);
	}
	| T_SPLIT "(" expr ")"
	{
		Expr *id = ast_mkId("split", @1.beg, @1.end);
		$$ = ast_mkFnCall(id, $3, @1.beg, @4.end);
	}
	/* this is to allow calling Tk widget functions */
	| dotted_id "(" argument_expr_list ")"
	{
		REVERSE(Expr, next, $3);
		$$ = ast_mkFnCall($1, $3, @1.beg, @4.end);
	}
	| dotted_id "(" ")"
	{
		$$ = ast_mkFnCall($1, NULL, @1.beg, @3.end);
	}
	| expr T_EQUALS expr
	{
		$$ = ast_mkBinOp(L_OP_EQUALS, $1, $3, @1.beg, @3.end);
	}
	| expr T_EQPLUS expr
	{
		$$ = ast_mkBinOp(L_OP_EQPLUS, $1, $3, @1.beg, @3.end);
	}
	| expr T_EQMINUS expr
	{
		$$ = ast_mkBinOp(L_OP_EQMINUS, $1, $3, @1.beg, @3.end);
	}
	| expr T_EQSTAR expr
	{
		$$ = ast_mkBinOp(L_OP_EQSTAR, $1, $3, @1.beg, @3.end);
	}
	| expr T_EQSLASH expr
	{
		$$ = ast_mkBinOp(L_OP_EQSLASH, $1, $3, @1.beg, @3.end);
	}
	| expr T_EQPERC expr
	{
		$$ = ast_mkBinOp(L_OP_EQPERC, $1, $3, @1.beg, @3.end);
	}
	| expr T_EQBITAND expr
	{
		$$ = ast_mkBinOp(L_OP_EQBITAND, $1, $3, @1.beg, @3.end);
	}
	| expr T_EQBITOR expr
	{
		$$ = ast_mkBinOp(L_OP_EQBITOR, $1, $3, @1.beg, @3.end);
	}
	| expr T_EQBITXOR expr
	{
		$$ = ast_mkBinOp(L_OP_EQBITXOR, $1, $3, @1.beg, @3.end);
	}
	| expr T_EQLSHIFT expr
	{
		$$ = ast_mkBinOp(L_OP_EQLSHIFT, $1, $3, @1.beg, @3.end);
	}
	| expr T_EQRSHIFT expr
	{
		$$ = ast_mkBinOp(L_OP_EQRSHIFT, $1, $3, @1.beg, @3.end);
	}
	| expr T_EQDOT expr
	{
		$$ = ast_mkBinOp(L_OP_EQDOT, $1, $3, @1.beg, @3.end);
	}
	| T_DEFINED "(" expr ")"
	{
		$$ = ast_mkUnOp(L_OP_DEFINED, $3, @1.beg, @4.end);
	}
	| expr "[" expr "]"
	{
		$$ = ast_mkBinOp(L_OP_ARRAY_INDEX, $1, $3, @1.beg, @4.end);
	}
	| expr "{" expr "}"
	{
		$$ = ast_mkBinOp(L_OP_HASH_INDEX, $1, $3, @1.beg, @4.end);
	}
	| expr T_STRCAT expr
	{
		$$ = ast_mkBinOp(L_OP_CONCAT, $1, $3, @1.beg, @3.end);
	}
	| expr "." T_ID
	{
		$$ = ast_mkBinOp(L_OP_DOT, $1, NULL, @1.beg, @3.end);
		$$->u.string = $3;
	}
	| expr "->" T_ID
	{
		$$ = ast_mkBinOp(L_OP_POINTS, $1, NULL, @1.beg, @3.end);
		$$->u.string = $3;
	}
	| T_TYPE "." T_ID
	{
		// This is a binop where an arg is a Type*.
		$$ = ast_mkBinOp(L_OP_CLASS_INDEX, (Expr *)$1.t, NULL, @1.beg,
				 @3.end);
		$$->u.string = $3;
	}
	| T_TYPE "->" T_ID
	{
		// This is a binop where an arg is a Type*.
		$$ = ast_mkBinOp(L_OP_CLASS_INDEX, (Expr *)$1.t, NULL, @1.beg,
				 @3.end);
		$$->u.string = $3;
	}
	| expr "," expr
	{
		$$ = ast_mkBinOp(L_OP_COMMA, $1, $3, @1.beg, @3.end);
	}
	| expr "[" expr T_DOTDOT expr "]"
	{
		$$ = ast_mkTrinOp(L_OP_ARRAY_SLICE, $1, $3, $5, @1.beg, @3.end);
	}
	/*
	 * We don't really need to open a scope here, but it doesn't hurt, and
	 * it avoids a shift/reduce conflict with a compound_stmt production.
	 */
	| "{" enter_scope list "}"
	{
		$$ = $3;
		$$->node.beg = @1.beg;
		$$->node.end = @4.end;
		L_scope_leave();
	}
	| "{" "}"
	{
		$$ = ast_mkBinOp(L_OP_LIST, NULL, NULL, 0, 0);
	}
	;

begin_re_arg:
	  /* epsilon */ %prec T_COMMA
	{
		L_lex_begReArg();
	}
	;

opt_arg:
	  "," expr	{ $$ = $2; $$->node.beg = @1.beg; }
	|		{ $$ = NULL; }
	;

re_or_string:
	  regexp_literal
	| string_literal
	;

id:
	  T_ID
	{
		$$ = ast_mkId($1, @1.beg, @1.end);
		ckfree($1);
	}
	;

id_list:
	id
	| id "," id_list
	{
		$$ = $1;
		$$->next = $3;
		$$->node.end = @3.end;
	}
	;

compound_stmt:
	  "{" enter_scope "}"
	{
		$$ = ast_mkStmt(L_STMT_BLOCK, NULL, @1.beg, @3.end);
		$$->u.block = ast_mkBlock(NULL, NULL, @1.beg, @3.end);
		L_scope_leave();
	}
	| "{" enter_scope stmt_list "}"
	{
		REVERSE(Stmt, next, $3);
		$$ = ast_mkStmt(L_STMT_BLOCK, NULL, @1.beg, @4.end);
		$$->u.block = ast_mkBlock(NULL, $3, @1.beg, @4.end);
		L_scope_leave();
	}
	| "{" enter_scope declaration_list "}"
	{
		VarDecl	*v;
		REVERSE(VarDecl, next, $3);
		for (v = $3; v; v = v->next) {
			v->flags |= SCOPE_LOCAL | DECL_LOCAL_VAR;
		}
		$$ = ast_mkStmt(L_STMT_BLOCK, NULL, @1.beg, @4.end);
		$$->u.block = ast_mkBlock($3, NULL, @1.beg, @4.end);
		L_scope_leave();
	}
	| "{" enter_scope declaration_list stmt_list "}"
	{
		VarDecl	*v;
		REVERSE(VarDecl, next, $3);
		for (v = $3; v; v = v->next) {
			v->flags |= SCOPE_LOCAL | DECL_LOCAL_VAR;
		}
		REVERSE(Stmt, next, $4);
		$$ = ast_mkStmt(L_STMT_BLOCK, NULL, @1.beg, @5.end);
		$$->u.block = ast_mkBlock($3, $4, @1.beg, @5.end);
		L_scope_leave();
	}
	;

enter_scope:
	   /* epsilon */ %prec HIGHEST { L_scope_enter(); }
	;

declaration_list:
	  declaration
	| declaration_list declaration
	{
		/*
		 * Each declaration is a list of declarators.  Here we
		 * append the lists.
		 */
		APPEND(VarDecl, next, $2, $1);
		$$ = $2;
	}
	;

declaration:
	  declaration2 ";"
	| decl_qualifier declaration2 ";"
	{
		VarDecl *v;
		for (v = $2; v; v = v->next) {
			v->flags |= $1;
		}
		$$ = $2;
		$$->node.beg = @1.beg;
	}
	;

decl_qualifier:
	  T_PRIVATE	{ $$ = DECL_PRIVATE; }
	| T_PUBLIC	{ $$ = DECL_PUBLIC; }
	| T_EXTERN	{ $$ = DECL_EXTERN; }
	;

declaration2:
	  type_specifier init_declarator_list
	{
		/* Don't REVERSE $2; it's done as part of declaration_list. */
		VarDecl *v;
		for (v = $2; v; v = v->next) {
			L_set_declBaseType(v, $1);
		}
		$$ = $2;
	}
	;

init_declarator_list:
	  init_declarator
	| init_declarator_list "," init_declarator
	{
		$3->next = $1;
		$$ = $3;
	}
	;

declarator_list:
	  declarator
	| declarator_list "," declarator
	{
		$3->next = $1;
		$$ = $3;
	}
	;

init_declarator:
	  declarator
	| declarator T_EQUALS expr
	{
		$1->initializer = ast_mkBinOp(L_OP_EQUALS, $1->id, $3,
					      @3.beg, @3.end);
		$$ = $1;
		$$->node.end = @3.end;
	}
	;

declarator:
	  id array_or_hash_type
	{
		$$ = ast_mkVarDecl($2, $1, @1.beg, @2.end);
	}
	| T_TYPE array_or_hash_type
	{
		Expr *id = ast_mkId($1.s, @1.beg, @1.end);
		$$ = ast_mkVarDecl($2, id, @1.beg, @2.end);
		if (isnameoftype($1.t)) $$->flags |= DECL_REF;
		ckfree($1.s);
	}
	| T_BITAND id array_or_hash_type
	{
		Type *t = type_mkNameOf($3, PER_INTERP);
		$$ = ast_mkVarDecl(t, $2, @1.beg, @3.end);
		$$->flags |= DECL_REF;
	}
	| T_BITAND id "(" parameter_list ")"
	{
		Type *tf = type_mkFunc(NULL, $4, PER_INTERP);
		Type *tn = type_mkNameOf(tf, PER_INTERP);
		$$ = ast_mkVarDecl(tn, $2, @1.beg, @5.end);
		$$->flags |= DECL_REF;
	}
	;

/* Right recursion OK here since depth is typically low. */
array_or_hash_type:
	  /* epsilon */
	{
		$$ = NULL;
	}
	| "[" expr "]" array_or_hash_type
	{
		$$ = type_mkArray($2, $4, PER_INTERP);
	}
	| "[" "]" array_or_hash_type
	{
		$$ = type_mkArray(NULL, $3, PER_INTERP);
	}
	| "{" scalar_type_specifier "}" array_or_hash_type
	{
		$$ = type_mkHash($2, $4, PER_INTERP);
	}
	;

type_specifier:
	  scalar_type_specifier array_or_hash_type
	{
		if ($2) {
			L_set_baseType($2, $1);
			$$ = $2;
		} else {
			$$ = $1;
		}
	}
	| struct_specifier array_or_hash_type
	{
		if ($2) {
			L_set_baseType($2, $1);
			$$ = $2;
		} else {
			$$ = $1;
		}
	}
	;

scalar_type_specifier:
	  T_STRING	{ $$ = L_string; }
	| T_INT		{ $$ = L_int; }
	| T_FLOAT	{ $$ = L_float; }
	| T_POLY	{ $$ = L_poly; }
	| T_VAR		{ $$ = L_var; }
	| T_VOID	{ $$ = L_void; }
	| T_TYPE	{ $$ = $1.t; ckfree($1.s); }
	;

struct_specifier:
	  T_STRUCT T_ID "{" struct_decl_list "}"
	{
		REVERSE(VarDecl, next, $4);
		$$ = L_struct_store($2, $4);
		ckfree($2);
	}
	| T_STRUCT "{" struct_decl_list "}"
	{
		REVERSE(VarDecl, next, $3);
		(void)L_struct_store(NULL, $3);  // to sanity check member types
		$$ = type_mkStruct(NULL, $3, PER_INTERP);
	}
	| T_STRUCT T_ID
	{
		$$ = L_struct_lookup($2, FALSE);
		ckfree($2);
	}
	;

struct_decl_list:
	  struct_decl
	| struct_decl_list struct_decl
	{
		APPEND(VarDecl, next, $2, $1);
		$$ = $2;
		$$->node.beg = @1.beg;
	}
	;

struct_decl:
	  struct_declarator_list ";"	{ $$->node.end = @2.end; }
	;

struct_declarator_list:
	  type_specifier declarator_list
	{
		VarDecl *v;
		for (v = $2; v; v = v->next) {
			L_set_declBaseType(v, $1);
		}
		$$ = $2;
		$$->node.beg = @1.beg;
	}
	;

list:
	  list_element
	| list "," list_element
	{
		APPEND(Expr, b, $1, $3);
		$$ = $1;
	}
	| list ","
	;

list_element:
	  expr %prec HIGHEST
	{
		$$ = ast_mkBinOp(L_OP_LIST, $1, NULL, @1.beg, @1.end);
	}
	| expr "=>" expr %prec HIGHEST
	{
		Expr *kv = ast_mkBinOp(L_OP_KV, $1, $3, @1.beg, @3.end);
		$$ = ast_mkBinOp(L_OP_LIST, kv, NULL, @1.beg, @3.end);
	}
	;

string_literal:
	  T_STR_LITERAL
	{
		$$ = ast_mkConst(L_string, @1.beg, @1.end);
		$$->u.string = $1;
	}
	| interpolated_expr T_STR_LITERAL
	{
		Expr *right = ast_mkConst(L_string, @2.beg, @2.end);
		right->u.string = $2;
		$$ = ast_mkBinOp(L_OP_INTERP_STRING, $1, right,
				 @1.beg, @2.end);
	}
	;

cmdsubst_literal:
	  T_STR_BACKTICK
	{
		$$ = ast_mkUnOp(L_OP_CMDSUBST, NULL, @1.beg, @1.end);
		$$->u.string = $1;
	}
	| interpolated_expr T_STR_BACKTICK
	{
		$$ = ast_mkUnOp(L_OP_CMDSUBST, $1, @1.beg, @2.end);
		$$->u.string = $2;
	}
	;

regexp_literal:
	  T_RE
	{
		$$ = ast_mkRegexp($1, @1.beg, @1.end);
	}
	| interpolated_expr T_RE
	{
		Expr *right = ast_mkConst(L_string, @2.beg, @2.end);
		right->u.string = $2;
		$$ = ast_mkBinOp(L_OP_INTERP_RE, $1, right, @1.beg, @2.end);
	}
	;

subst_literal:
	  T_SUBST
	{
		$$ = ast_mkConst(L_string, @1.beg, @1.end);
		$$->u.string = $1;
	}
	| interpolated_expr T_SUBST
	{
		Expr *right = ast_mkConst(L_string, @2.beg, @2.end);
		right->u.string = $2;
		$$ = ast_mkBinOp(L_OP_INTERP_RE, $1, right, @1.beg, @2.end);
	}
	;

interpolated_expr:
	  T_LEFT_INTERPOL expr T_RIGHT_INTERPOL
	{
		Expr *left = ast_mkConst(L_string, @1.beg, @1.end);
		left->u.string = $1;
		$$ = ast_mkBinOp(L_OP_INTERP_STRING, left, $2,
				 @1.beg, @3.end);
	}
	| interpolated_expr T_LEFT_INTERPOL expr T_RIGHT_INTERPOL
	{
		Expr *middle = ast_mkConst(L_string, @2.beg, @2.end);
		middle->u.string = $2;
		$$ = ast_mkTrinOp(L_OP_INTERP_STRING, $1, middle, $3,
				    @1.beg, @4.end);
	}
	;

dotted_id:
	  "."
	{
		$$ = ast_mkId(".", @1.beg, @1.end);
	}
	| dotted_id_1
	{
		$$ = ast_mkId(Tcl_GetString($1), @1.beg, @1.end);
		Tcl_DecrRefCount($1);
	}
	;

dotted_id_1:
	  "." T_ID
	{
		$$ = Tcl_NewObj();
		Tcl_IncrRefCount($$);
		Tcl_AppendToObj($$, ".", 1);
		Tcl_AppendToObj($$, $2, -1);
		ckfree($2);
	}
	| dotted_id_1 "." T_ID
	{
		Tcl_AppendToObj($1, ".", 1);
		Tcl_AppendToObj($1, $3, -1);
		$$ = $1;
		ckfree($3);
	}
	;
%%
