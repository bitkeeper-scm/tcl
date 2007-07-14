# This file provides environment initialization and runtime library
# support for the L language.  It is loaded automatically by init.tcl.

# this stuff should probably be in its own namespace, but I haven't
# figured out the right way to import the L namespace for L code yet.
# --timjr 2006.11.1

#namespace eval ::L {
    proc printf {args} {
	puts -nonewline [format {expand}$args]
    }

    proc write {args} {
	puts -nonewline {expand}$args
    }

    set ::%%suppress_calling_main 0
    
    proc %%call_main_if_defined {} {
	if {[llength [info proc main]] && !${::%%suppress_calling_main}} {
	    append L_argv $::argv0 " " $::argv
	    set L_envp [dict create {expand}[array get ::env]]
	    switch [llength [info args main]] {
		0 {
		    set ::%%suppress_calling_main 1
		    main
		    set ::%%suppress_calling_main 0
		}
		1 {
		    set ::%%suppress_calling_main 1
		    main [expr {$::argc + 1}]
		    set ::%%suppress_calling_main 0
		}
		2 {
		    set ::%%suppress_calling_main 1
		    main [expr {$::argc + 1}] $L_argv
		    set ::%%suppress_calling_main 0
		}
		3 {
		    set ::%%suppress_calling_main 1
		    main [expr {$::argc + 1}] $L_argv $L_envp
		    set ::%%suppress_calling_main 0
		}
		default {
		    error "Too many parameters for main()."
		}
	    }
	}
    }

# Tcl uses a write trace on the $env array to set environment
# variables.  We can't easily emulate that with a dict, so we provide
# setenv, unsetenv, and getenv for L.

    proc setenv {var val overwrite} {
	global env
	if {$overwrite || ![info exists env($var)]} {
	    set env($var) $val
	}
    }

    proc unsetenv {var} {
	global env
	unset env($var)
    }

    proc getenv {var} {
	global env
	if {[info exists env($var)]} {
	    return $env($var);
	} else {
	    return 0;
	}
    }

# Extending lset is like lset except when the index is 1 past the end
# of the list then it will lappend instead of lset.

    proc extendingLset {listname index value} {
	upvar 1 $listname list
	if {[expr {[llength $list] == $index}]} {
	    lappend list $value
	} else {
	    lset list $index $value
	}
    }


# Push adds a new element to the end of an array. 
    proc push {listname value} {
	upvar 1 $listname list
	extendingLset list [llength $list] $value
    }


# Pop removes an element from the end of an array and returns it.  If
# the array is empty, pop returns the empty string.
    proc pop {listname} {
	upvar 1 $listname list
	set last [lindex $list end]
	set list [lrange $list 0 [expr {[llength $list] - 2}]]
	return $last
    }
#}
