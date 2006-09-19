# This file provides environment initialization and runtime library
# support for the L language.  It is loaded automatically by init.tcl.

# I suspect that after changing the set of procs defined in this file,
# you should say:
#     echo 'auto_mkindex . *.tcl' | ../unix/tclsh
# to update the tclIndex.  --timjr 2006.09.19

proc printf {args} {
    puts -nonewline [format {expand}$args]
}
