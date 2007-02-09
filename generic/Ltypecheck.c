/* A typechecker for the L programming language.  In case not enough type
 * information is available, typechecks are queued up to try again at the end
 * of compilation.  That way it doesn't matter which order functions appear
 * in. */
#include <stdio.h>
#include "tclInt.h"
#include "Lcompile.h"
#include "Lgrammar.h"
#include "Last.h"


#define CHECK_ARG_COUNT	1	/* mark a queued check as an arg count
				 * check */

/* A delayed type check */
typedef struct queued_check {
    int flags;			/* Set for special cases, like argument count
				 * checks */
    L_type *want;		/* The required type */
    L_type *have;		/* The actual type */
    /* In case :want is unknown, these three will be set: */
    char *name;			/* The function name */
    int pos;			/* The argument position */
    /* In case :have is unknown, the expression to get it from */
    L_expression *expr;
    /* A pointer so we can link the checks together. */
    struct queued_check *next;
} queued_check;

/* The type of a function */
typedef struct function_type {
    L_type *return_type;	/* The return type */
    int param_count;		/* How many parameters */
    L_type **param_types;	/* An array of types, one for each
				 * parameter. */
} function_type;

/* A list of type checks to be performed later. */
static queued_check *queued_checks = NULL;

/* A table mapping function names to function types */
static Tcl_HashTable *function_types = NULL;

/* Return codes from subtype */
typedef enum { NOT_SUBTYPE, UNKNOWN, IS_SUBTYPE } type_relation;

static type_relation subtype(L_type *have, L_type *want);
static L_type *parameter_type(char *name, int pos);
static L_type *return_type(char *name);
static function_type *get_function_type(char *name);
static void L_type_error(L_expression *expr, L_type *have, L_type *want);
static L_type *binop_expression_type(L_expression *expr);
static L_type *unop_expression_type(L_expression *expr);
static void free_type_info();
static L_expression *copy_index_expr(L_expression *expr);

/* A convenience wrapper around L_check_type() that instantiates the type for
 * you. */
void 
L_check_kind(
    L_type_kind want, 		/* The kind of the expected type */
    L_expression *expr)		/* The expression from which we derive
				 * the actual type */
{
    L_type *type = mk_type(want, NULL, NULL, NULL, NULL, FALSE);
    return L_check_type(type, expr);
}

/* Ensure that the type of :expr is compatible with the :want type.
 * If not, emit a type error.  In certain cases, such as when :expr is
 * a function call, L_check_type() queues up the check to be performed
 * by L_finish_typechecks(). */
void 
L_check_type(
    L_type *want, 		/* The expected type */
    L_expression *expr)		/* The expression from which we derive
				 * the actual type */
{
    L_type *have;
    queued_check *new;

    if (!want) L_bomb("typecheck: Missing want type");
    have = L_expression_type(expr);
    switch (subtype(have, want)) {
    case NOT_SUBTYPE:
	L_type_error(expr, have, want);
	break;
    case IS_SUBTYPE:
	break;
    case UNKNOWN:
	new = (queued_check *)ckalloc(sizeof(queued_check));
	memset(new, 0, sizeof(queued_check));
	new->want = want;
	new->expr = expr;
	new->next = queued_checks;
	queued_checks = new;
	break;
    default:
	L_bomb("typecheck: bad retval from subtype()");
    }
}

/* Functions don't need to be declared before they're used, so
 * L_check_arg_type() just queues up argument typechecks.
 * L_finish_typechecks() below will do the actual checks. */
void 
L_check_arg_type(
    char *funcname, 		/* The name of the function being
				 * called. */
    int pos, 			/* The position of this argument in the
				 * arglist of the function being called.
				 * Starts at 1.  0 means no arguments. */
    L_expression *expr) 	/* The argument itself. */
{
    queued_check *new;
    new = (queued_check *)ckalloc(sizeof(queued_check));
    memset(new, 0, sizeof(queued_check));
    new->have = L_expression_type(expr);
    new->expr = expr;
    new->name = funcname;
    new->pos = pos;
    new->next = queued_checks;
    queued_checks = new;
}

/* Check that the number of actual parameters matches the number of formal
 * parameters. */
void 
L_check_arg_count(
    char *funcname, 		/* The name of the function being
				 * called. */
    int count, 			/* The number of args passed */
    L_expression *expr)		/* An expression to grab location info from */
{
    queued_check *new;
    new = (queued_check *)ckalloc(sizeof(queued_check));
    memset(new, 0, sizeof(queued_check));
    new->flags = CHECK_ARG_COUNT;
    new->pos = count;
    new->name = funcname;
    new->expr = expr;
    new->next = queued_checks;
    queued_checks = new;
}


/* Store the return type and parameter types of a function, so that
 * they can be checked by L_finish_typechecks(). */
void 
L_store_fun_type(
    L_function_declaration *fun) /* The function declaration from
				  * which we get the type info. */
{
    function_type *fun_type;
    L_variable_declaration *p;
    int param_count, freshp;
    Tcl_HashEntry *hPtr;

    fun_type = (function_type *)ckalloc(sizeof(function_type));

    fun_type->return_type = fun->return_type;

    for (param_count = 0, p = fun->params; p; param_count++, p = p->next);
    fun_type->param_count = param_count;

    fun_type->param_types = 
	(L_type **)ckalloc(sizeof(L_type *) * param_count);
    for (param_count = 0, p = fun->params; p; param_count++, p = p->next) {
	fun_type->param_types[param_count] = p->type;
    }

    if (function_types == NULL) {
        function_types = (Tcl_HashTable *)ckalloc(sizeof(Tcl_HashTable));
        Tcl_InitHashTable(function_types, TCL_STRING_KEYS);
    }
    hPtr = Tcl_CreateHashEntry(function_types, fun->name->u.string, &freshp);
    if (!freshp) {
	L_bomb("typecheck: Redefinition of function type for %s", 
	  fun->name->u.string);
    } else {
	Tcl_SetHashValue(hPtr, fun_type);
    }
}

/* Perform type checks that have been queued up by L_check_type() and
 * L_check_arg_type().  Emit an error for each type mismatch.  Also frees up
 * the memory allocated by the typechecker. */
void 
L_finish_typechecks()
{
    queued_check *q;

    for (q = queued_checks; q; q = q->next) {
	if (q->flags == CHECK_ARG_COUNT) {
	    function_type *fun_type = get_function_type(q->name);
	    if (fun_type) {
		if (fun_type->param_count > q->pos) {
		    L_errorf(q->expr, "Not enough arguments for function %s", q->name);
		} else if (fun_type->param_count < q->pos) {
		    L_errorf(q->expr, "Too many arguments for function %s", q->name);		    
		}
	    } else {
		L_trace("couldn't check argcount for %s", q->name);
	    }
	} else {
	    if (q->have == NULL) {
		q->have = L_expression_type(q->expr);
	    }
	    if (q->want == NULL) {
		q->want = parameter_type(q->name, q->pos);
	    }
	    switch (subtype(q->have, q->want)) {
	    case NOT_SUBTYPE:
		L_type_error(q->expr, q->have, q->want);
		break;
	    case IS_SUBTYPE:
		L_trace("queued check succeeded");
		break;
	    case UNKNOWN:
		L_trace("typecheck: Couldn't typecheck expression. "
		    "Have is %s, want is %s. Line %d\n", 
		    q->have ? "set" : "NULL",
		    q->want ? "set" : "NULL",
		    q->expr ? ((L_ast_node *)q->expr)->line_no : -1);
		break;
	    default:
		L_bomb("typecheck: bad retval from subtype()");
	    }
	}
    }
    free_type_info();
}

static type_relation 
subtype(
    L_type *have, 
    L_type *want)
{
    if (!have || !want) {
	return UNKNOWN;
    }
    /* XXX Actually, once L_TYPE_VAR is implemented, we shouldn't see it
     * here. */
    if (want->kind != L_TYPE_POLY && want->kind != L_TYPE_VAR) {
	if (want->kind == L_TYPE_NUMBER) {
	    if (have->kind != L_TYPE_FLOAT && have->kind != L_TYPE_INT) {
		return NOT_SUBTYPE;
	    }
	} else if (want->kind != have->kind) {
	    return NOT_SUBTYPE;
	}
	if (want->kind == L_TYPE_STRUCT) {
	    if (want->struct_tag && have->struct_tag) {
		/* Note that since we define struct subtyping by checking type
		 * tags, untagged structs are pairwise disjoint... */
		if (strcmp(want->struct_tag->u.string, 
			   have->struct_tag->u.string)) 
		{
		    return NOT_SUBTYPE;
		}
	    } else {
		return NOT_SUBTYPE;
	    }
	}
    }
    /* We don't check if the dimensions of two array types are all the same.
     * Since the size of arrays can change anyway, it seems pointless.  We
     * don't check the number of dimensions, either, though that would be more
     * pointful. */
    if ((want->next_dim && !have->next_dim) ||
	(!want->next_dim && have->next_dim))
    {
	return NOT_SUBTYPE;
    }
    return IS_SUBTYPE;
}

/* handy debugging type dumper thingy.  say elucidate_type(type, 0); */
void
tab(int tabs) { while (tabs--) fprintf(stderr, "\t"); }

void
elucidate_type(
    L_type *type,
    int tabs)
{
    tab(tabs);
    fprintf(stderr, "type's kind is %s\n", L_type_tostr[type->kind]);
    if (type->next_dim) {
	tab(tabs);
	fprintf(stderr, "type's next dim is:\n");
	elucidate_type(type->next_dim, tabs + 1);
    }
    if (type->kind == L_TYPE_STRUCT) {
	L_variable_declaration *mem;
	tab(tabs);
	fprintf(stderr, "type has struct members:\n");
	for (mem = type->members;  mem; mem = mem->next) {
	    tab(tabs);
	    fprintf(stderr, "%s", mem->name->u.string);
	    elucidate_type(mem->type, tabs + 1);
	}
    }
    tab(tabs);
    fprintf(stderr, ";\n");
}

/* Return the type of an expression. */
L_type *
L_expression_type(
    L_expression *expr)
{
    L_symbol *symbol;
    L_type *type = NULL;
    L_expression *index;
    
    if (!expr) return NULL;
    switch (expr->kind) {
    case L_EXPRESSION_FUNCALL:
        if (!(symbol = L_get_symbol(expr->a, FALSE))) {
	    type = return_type(expr->a->u.string);
	}
        break;
    case L_EXPRESSION_PRE:
    case L_EXPRESSION_POST:
    case L_EXPRESSION_INTEGER:
	type = mk_type(L_TYPE_INT, NULL, NULL, NULL, NULL, FALSE);
        break;
    case L_EXPRESSION_STRING:
    case L_EXPRESSION_INTERPOLATED_STRING:
	type = mk_type(L_TYPE_STRING, NULL, NULL, NULL, NULL, FALSE);
	break;
    case L_EXPRESSION_FLOTE:
	type = mk_type(L_TYPE_FLOAT, NULL, NULL, NULL, NULL, FALSE);
	break;
    case L_EXPRESSION_UNARY:
	type = unop_expression_type(expr);
	break;    
    case L_EXPRESSION_BINARY:
	type = binop_expression_type(expr);
        break;
    case L_EXPRESSION_VARIABLE:
	index = copy_index_expr(expr->indices);
        if ((symbol = L_get_symbol(expr->a, FALSE))) {
	    type = symbol->type;
	}
	while (index) {
	    switch (index->kind) {
            case L_EXPRESSION_ARRAY_INDEX:
            case L_EXPRESSION_HASH_INDEX:
		L_trace(index->kind == L_EXPRESSION_HASH_INDEX ? 
		    "hash index" : "array index");
		if (type->next_dim) {
		    type = type->next_dim;
		} else {
		    L_trace("not enough dimensions in type for index, "
			"giving up");
		    type = mk_type(L_TYPE_POLY, NULL, NULL, NULL, NULL, 
			FALSE);
		}
		break;
            case L_EXPRESSION_STRUCT_INDEX: {
		L_trace("struct index");
		L_variable_declaration *member;
		int memberOffset;

		member = L_get_struct_member(type, index, &memberOffset);
		if (member) {
		    type = member->type;
		} else {
		    L_trace("not enough dimensions in type for struct "
			"index, giving up");
		    type = mk_type(L_TYPE_POLY, NULL, NULL, NULL, NULL, 
			FALSE);
		}
		break;
	    }
	    default:
		L_bomb("malformed AST in L_expression_type()");
	    }
	    index = index->indices;
	}
	break;
    default:
        L_bomb("typecheck: Unknown expression type %d", expr->kind);
    }
    return type;
}

static L_expression *
copy_index_expr(
    L_expression *expr)
{
    L_expression *copy, *runner;

    if (!expr) return expr;
    copy = (L_expression *)ckalloc(sizeof(L_expression));
    memcpy(copy, expr, sizeof(L_expression));
    for (runner = copy, expr = expr->indices; expr; 
	 expr = expr->indices, runner = runner->indices)
    {
	runner->indices = (L_expression *)ckalloc(sizeof(L_expression));
	memcpy(runner->indices, expr, sizeof(L_expression));
    }
    return copy;
}

/* Return the type of an expression with a unary operator in it. */
static L_type *
unop_expression_type(
    L_expression *expr)
{
    L_type *type, *type1; 

    type = mk_type(L_TYPE_POLY, NULL, NULL, NULL, NULL, FALSE);
    switch (expr->op) {
    case T_TCL_CAST:
    case T_STRING_CAST:
	type->kind = L_TYPE_STRING;
	break;
    case T_FLOAT_CAST:
	type->kind = L_TYPE_FLOAT;
        break;
    case T_BANG:
    case T_BITNOT:
    case T_INT_CAST:
    case T_DEFINED:
	type->kind = L_TYPE_INT;
        break;
    case T_BITAND:
	type = L_expression_type(expr->a);
	break;
    case T_PLUS:
    case T_MINUS:
	type1 = L_expression_type(expr->a);
	if (!type1) return NULL;
	if (type1->kind == L_TYPE_FLOAT) {
	    type->kind = L_TYPE_FLOAT;
	} else {
	    type->kind = L_TYPE_INT;
	}
        break;
    default:
        L_bomb("typecheck: Unknown unary operator %d", expr->op);
    }
    return type;
}

/* Return the type of an expression with a binary operator in it. */
static L_type *
binop_expression_type(
    L_expression *expr)
{
    L_type *type, *type1, *type2;

    type = mk_type(L_TYPE_POLY, NULL, NULL, NULL, NULL, FALSE);
    switch (expr->op) {
    case T_EQUALS:
	type = L_expression_type(expr->b);
	break;
    case T_PLUS:
    case T_PLUSPLUS:
    case T_EQPLUS:
    case T_MINUS:
    case T_MINUSMINUS:
    case T_EQMINUS:
    case T_STAR:
    case T_EQSTAR:
    case T_SLASH:
    case T_EQSLASH:
	type1 = L_expression_type(expr->a);
	type2 = L_expression_type(expr->b);
	if (!type1 || !type2) return NULL;
	if (type1->kind == L_TYPE_FLOAT || type2->kind == L_TYPE_FLOAT) {
	    type->kind = L_TYPE_FLOAT;
	} else {
	    type->kind = L_TYPE_INT;
	}
	break;
    case T_BITAND:
    case T_EQBITAND:
    case T_BITOR:
    case T_EQBITOR:
    case T_BITXOR:
    case T_EQBITXOR:
    case T_LSHIFT:
    case T_EQLSHIFT:
    case T_RSHIFT:
    case T_EQRSHIFT:
    case T_PERC:
    case T_EQPERC:
    case T_ANDAND:
    case T_OROR:
    case T_EQUALEQUAL:
    case T_NOTEQUAL:
    case T_GREATER:
    case T_GREATEREQ:
    case T_LESSTHAN:
    case T_LESSTHANEQ:
	type->kind = L_TYPE_INT;
	break;
    case T_EQ:
    case T_NE:
    case T_GT:
    case T_GE:
    case T_LT:
    case T_LE:
    case T_EQTWID:
	type->kind = L_TYPE_STRING;
	break;
    default:
	L_bomb("typecheck: Unknown binary operator %d", expr->op);
    }
    return type;
}


/* Return the want type for a function parameter.  Returns NULL if nothing is
 * known about the parameter, or it is out of bounds. */
L_type *
parameter_type(
    char *name, 		/* The name of the function */
    int pos) 			/* The position in the argument list, starting
				 * at 1 -- 0 means no arguments. */
{
    function_type *fun_type;

    fun_type = get_function_type(name);
    if (!fun_type) return NULL;
    if (pos < fun_type->param_count) {
	return fun_type->param_types[pos];
    } else {
	L_trace("parameter %d out of range 0..%d for function %s", 
	    pos, fun_type->param_count, name);
    }
    return NULL;
}

/* Look up the return type for a function.  Returns NULL if nothing is
 * known about the function. */
static L_type *
return_type(
    char *name)
{
    function_type *fun_type;
    
    fun_type = get_function_type(name);
    if (!fun_type) {
	L_trace("checking return type failed");
	return NULL;
    }
    return fun_type->return_type;
}


/* Lookup the type of a function.  Return null if the type is not
 * known. */
static function_type *
get_function_type(
    char *name)
{
    Tcl_HashEntry *hPtr;

    if (!function_types) {
	L_trace("typecheck: No function types found.");
	return NULL; 
    }
    hPtr = Tcl_FindHashEntry(function_types, name);
    if (hPtr) {
	return (function_type *)Tcl_GetHashValue(hPtr);
    } else {
	L_trace("typecheck: No function type found for %s", name);
	return NULL;
    }
}

/* Release memory used by the type checker */
static void
free_type_info()
{
    Tcl_HashEntry *hPtr;
    Tcl_HashSearch hSearch;
    function_type *f;
    queued_check *q;

    while (queued_checks) {
	q = queued_checks->next;
	ckfree((char *)queued_checks);
	queued_checks = q;
    }
    if (function_types != NULL) {
	for (hPtr = Tcl_FirstHashEntry(function_types, &hSearch); hPtr != NULL;
	     hPtr = Tcl_NextHashEntry(&hSearch)) 
	{
	    f = (function_type *)Tcl_GetHashValue(hPtr);
	    ckfree((char *)f->param_types);
	    ckfree((char *)f);
	}
	Tcl_DeleteHashTable(function_types);
	function_types = NULL;
    }
}

/* Generate a type error */
static void L_type_error(
    L_expression *expr, 	/* The erroneous expression */
    L_type *have, 		/* The expected type */
    L_type *want)		/* The erroneous type */
{
    L_errorf(expr, "type error, want %s, got %s", 
	     L_type_tostr[want->kind], L_type_tostr[have->kind]);
}

/*
 * Local Variables:
 * mode: c
 * c-basic-offset: 4
 * fill-column: 78
 * End:
 */
