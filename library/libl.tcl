# This file provides environment initialization and runtime library
# support for the L language.  It is loaded automatically by init.tcl.

# this stuff should probably be in its own namespace, but I haven't
# figured out the right way to import the L namespace for L code yet.
# --timjr 2006.11.1

#namespace eval ::L {
    proc printf {args} {
	puts -nonewline [format {expand}$args]
    }

    proc %%call_main_if_defined {} {
	if {[llength [info proc main]]} {
	    append L_argv $::argv0 " " $::argv
	    set L_envp [dict create {expand}[array get ::env]]
	    switch [llength [info args main]] {
		0 {
		    main
		}
		1 {
		    main [expr {$::argc + 1}]
		}
		2 {
		    main [expr {$::argc + 1}] L_argv
		}
		3 {
		    main [expr {$::argc + 1}] L_argv L_envp
		}
		default {
		    error "Too many parameters for main()."
		}
	    }
	}
    }
#}
