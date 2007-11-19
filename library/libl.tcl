# This file provides environment initialization and runtime library
# support for the L language.  It is loaded automatically by init.tcl.
#
# This stuff should probably be in its own namespace or only turned on when
# processing L source.  It breaks tcl scripts.
#
# Copyright (c) 2007 BitMover, Inc.

proc printf {args} {
	puts -nonewline [format {*}$args]
}

proc fprintf {stdio args} {
	puts -nonewline $stdio [format {*}$args]
}


# XXX - I'd really like a C preprocessor for this stuff
# But we need {*} in L.
proc sprintf {args} {
	return [format {*}$args]
}

set ::%%suppress_calling_main 0

proc %%call_main_if_defined {} {
	if {[llength [info proc main]] && !${::%%suppress_calling_main}} {
		append L_argv $::argv0 " " $::argv
		set L_envp [dict create {*}[array get ::env]]
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
proc setenv {var val {overwrite 1}} {
	global env
	if {$overwrite == 0 && [info exists env($var)]} { return }
	set env($var) $val
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
	return "";
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

#lang L
/*
 * stdio stuff (some above because we don't have {*} yet).
 */
typedef	string	FILE;
FILE    stdin = "stdin";
FILE    stderr = "stderr";
FILE    stdout = "stdout";
string	stdio_lasterr;

FILE
fopen(string path, string mode)
{
	FILE	f;
	string	err;
	int	v = 0;

	/* new mode, v, means be verbose w/ errors */
	if (mode =~ /v/) {
		mode =~ s/v//;
		v = 1;
	}
	if (catch("set f [open {${path}} ${mode}]", &err)) {
		stdio_lasterr = err;
		if (v) fprintf(stderr, "fopen(%s, %s) = %s\n", path, mode, err);
		return (0);
	} else {
		return (f);
	}
}

FILE
popen(string cmd, string mode)
{
	FILE	f;
	string	err;
	int	v = 0;
	
	if (mode =~ /v/) {
		mode =~ s/v//;
		v = 1;
	}
	if (catch("set f [open {|${cmd}} ${mode}]", &err)) {
		stdio_lasterr = err;
		if (v) fprintf(stderr, "popen(%s, %s) = %s\n", cmd, mode, err);
		return (0);
	} else {
		return (f);
	}
}

int
fclose(FILE f)
{
	string	err = "";
	
	if (f eq "") return (0);
	if (catch("close ${f}", &err)) {
		stdio_lasterr = err;
		return (-1);
	} else {
		return (0);
	}
}

int pclose(FILE f) { return (fclose(f)); }

int
fgetline(FILE f, string &buf)
{
	return (gets(f, &buf));
}

string
stdio_getLastError()
{
	return (stdio_lasterr);
}

/*
 * string functions
 */
int
streq(string a, string b)
{
	return (string("compare", a, b));
}

int
strneq(string a, string b, int n)
{
	return (string("equal", length: n, a, b));
}

string
strchr(string s, string c)
{
	return (string("first", c, s));
}

string
strrchr(string s, string c)
{
	return (string("last", c, s));
}

int
strlen(string s)
{
	return (string("length", s));
}

// XXX - do we need this?
void
chomp(string &s)
{
	s = string("trimright", s, "\r\n");
}

/*
 * spawn like stuff.
 *
 * system returns 0 if it worked, a string otherwise indicating the error.
 */
string
system(string cmd)
{
	string	err;
	string	command = cmd;

	unless (cmd =~ />/) command = "${cmd} >@ stdout 2>@ stderr";
	if (catch("exec -ignorestderr -- {*}$command", &err)) {
		// XXX - this could be a lot nicer by digging into errorCode
		return ("${cmd}: ${err}");
	}
	return (0);
}
