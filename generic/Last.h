#ifndef L_AST_H
#define L_AST_H

/* AST node types  */
typedef enum L_node_type { 
    L_NODE_SYMBOL, 
    L_NODE_INT, 
    L_NODE_FLOAT, 
    L_NODE_STRING,
    L_NODE_NODE 
} L_node_type;

/* types in the L language */
typedef enum L_type { 
    L_TYPE_VOID, 
    L_TYPE_INT, 
    L_TYPE_FLOAT, 
    L_TYPE_STRING, 
    L_TYPE_ARRAY, 
    L_TYPE_HASH, 
    L_TYPE_POLY, 
    L_TYPE_VAR 
} L_type;


/* L_symbols are used to represent variables. */
typedef struct L_symbol {
    char *name;
    int base_type;
    struct L_node *array_type;
} L_symbol;

typedef struct L_node {
    L_node_type type;
    union {
        int i;
        double f;
        char *s;
        L_symbol *sym;
        struct L_node *child;
    } v;
    struct L_node *next;
    /* The _trace is used to clean up the AST once we're done with it.  It
       should be considered a private field. */
    void *_trace;
} L_node;

#define LNIL ((L_node*)0)

L_node *L_make_node(L_node_type type, L_node *next, ...);
void L_dump_ast(L_node *ast);

#endif /* L_AST_H  */

/*
 * Local Variables:
 * mode: c
 * c-basic-offset: 4
 * fill-column: 78
 * End:
 */
