# tcltest.tcl --
#
#	This file contains support code for the Tcl test suite.  It defines the
#       defines the ::tcltest namespace and finds and defines the output
#       directory, constraints available, output and error channels, etc. used
#       by Tcl tests.  See the README file for more details.
#       
#       This design was based on the original Tcl testing approach designed and
#       initially implemented by Mary Ann May-Pumphrey of Sun Microsystems. 
#
# Copyright (c) 1994-1997 Sun Microsystems, Inc.
# Copyright (c) 1998-1999 by Scriptics Corporation.
# All rights reserved.
# 
# RCS: @(#) $Id$

package provide tcltest 1.0

# Ensure that we have a minimal auto_path so we don't pick up extra junk.
set auto_path [list [info library]]

# create the "tcltest" namespace for all testing variables and procedures

namespace eval tcltest {

    # Export the public tcltest procs
    set procList [list test cleanupTests dotests saveState restoreState \
	    normalizeMsg makeFile removeFile makeDirectory removeDirectory \
	    viewFile grep bytestring set_iso8859_1_locale restore_locale \
	    safeFetch threadReap]
    foreach proc $procList {
	namespace export $proc
    }

    # ::tcltest::verbose defaults to "b"

    variable verbose "b"

    # match defaults to the empty list

    variable match {}

    # skip defaults to the empty list

    variable skip {}

    # output goes to stdout by default

    variable outputChannel stdout

    # errors go to stderr by default

    variable errorChannel stderr

    # debug output doesn't get printed by default; default debugLevel (1) spits
    # up only the tets that were skipped because they didn't match or were 
    # specifically skipped.  A debugLevel of 2 would spit up the tcltest
    # variables and flags provided; a debugLevel of 3 causes some additional
    # output regarding operations of the test harness.  The tcltest package
    # currently implements only up to debugLevel 3.

    variable debug false
    variable debugLevel 1

    # Count the number of files tested (0 if all.tcl wasn't called).
    # The all.tcl file will set testSingleFile to false, so stats will
    # not be printed until all.tcl calls the cleanupTests proc.
    # The currentFailure var stores the boolean value of whether the
    # current test file has had any failures.  The failFiles list
    # stores the names of test files that had failures.

    variable numTestFiles 0
    variable testSingleFile true
    variable currentFailure false
    variable failFiles {}

    # Tests should remove all files they create.  The test suite will
    # check the current working dir for files created by the tests.
    # ::tcltest::filesMade keeps track of such files created using the
    # ::tcltest::makeFile and ::tcltest::makeDirectory procedures.
    # ::tcltest::filesExisted stores the names of pre-existing files.

    variable filesMade {}
    variable filesExisted {}

    # ::tcltest::numTests will store test files as indices and the list
    # of files (that should not have been) left behind by the test files.

    array set ::tcltest::createdNewFiles {}

    # initialize ::tcltest::numTests array to keep track fo the number of
    # tests that pass, fial, and are skipped.

    array set ::tcltest::numTests [list Total 0 Passed 0 Skipped 0 Failed 0] 

    # initialize ::tcltest::skippedBecause array to keep track of
    # constraints that kept tests from running; a constraint name of
    # "userSpecifiedSkip" means that the test appeared on the list of tests
    # that matched the -skip value given to the flag; "userSpecifiedNonMatch"
    # means that the test didn't match the argument given to the -match flag;
    # both of these constraints are counted only if ::tcltest::debug is set to
    # true. 

    array set ::tcltest::skippedBecause {}

    # initialize the ::tcltest::testConstraints array to keep track of valid
    # predefined constraints (see the explanation for the ::tcltest::initConstraints
    # proc for more details).

    array set ::tcltest::testConstraints {}

    # tests that use thread need to know which is the main thread

    variable mainThread 1
    if {[info commands testthread] != {}} {
	set mainThread [testthread names]
    }

    # save the original environement so that it can be restored later
    
    array set ::tcltest::originalEnv [array get ::env]

    # TclPro has other variables that need to be set, including the locations
    # of various directories.
    
    # Set ::tcltest::workingDirectory to [pwd]. The default output directory
    # for Tcl tests is the working directory.

    variable workingDirectory [pwd]
    variable temporaryDirectory $workingDirectory

    # Tests should not rely on the current working directory.
    # Files that are part of the test suite should be accessed relative to 
    # ::tcltest::testsDirectory.

    variable testsDirectory [pwd]

    variable saveState {}

    # Internationalization support
    if {![info exists ::tcltest::isoLocale]} {
	variable isoLocale fr
        switch $tcl_platform(platform) {
	    "unix" {

		# Try some 'known' values for some platforms:

		switch -exact -- $tcl_platform(os) {
		    "FreeBSD" {
			set ::tcltest::isoLocale fr_FR.ISO_8859-1
		    }
		    HP-UX {
			set ::tcltest::isoLocale fr_FR.iso88591
		    }
		    Linux -
		    IRIX {
			set ::tcltest::isoLocale fr
		    }
		    default {

			# Works on SunOS 4 and Solaris, and maybe others...
			# define it to something else on your system
			#if you want to test those.

			set ::tcltest::isoLocale iso_8859_1
		    }
		}
	    }
	    "windows" {
		set ::tcltest::isoLocale French
	    }
	}
    }

    # Set the location of the execuatble
    variable tcltest [info nameofexecutable]

    # If there is no "memory" command (because memory debugging isn't
    # enabled), generate a dummy command that does nothing.
    
    if {[info commands memory] == {}} {
	namespace eval :: {
	    proc memory args {}
	}
    }
}   


proc ::tcltest::AddToSkippedBecause { constraint } {
    # add the constraint to the list of constraints the kept tests
    # from running

    if {[info exists ::tcltest::skippedBecause($constraint)]} {
	incr ::tcltest::skippedBecause($constraint)
    } else {
	set ::tcltest::skippedBecause($constraint) 1
    }
    return
}

# ::tcltest::PrintError --
#
#	Prints errors to ::tcltest::errorChannel and then flushes that
#       channel.  
#
# Arguments:
#	errorMsg     String containing the error to be printed
#

proc ::tcltest::PrintError {errorMsg} {
    set InitialMessage "Error:  "
    set InitialMsgLen  [string length $InitialMessage]
    puts -nonewline $::tcltest::errorChannel $InitialMessage
    set beginningIndex [string wordend $errorMsg 72]
    puts $::tcltest::errorChannel [string range $errorMsg 0 $beginningIndex]
    set endingIndex [string length $errorMsg]
    while {$beginningIndex < $endingIndex} {
	set newEndingIndex [string wordend $errorMsg \
		[expr {$beginningIndex + 72}]]
	puts -nonewline $::tcltest::errorChannel \
		[string repeat " " $InitialMsgLen]  
	puts $::tcltest::errorChannel [string trim \
		[string range $errorMsg $beginningIndex $newEndingIndex]]
	set beginningIndex $newEndingIndex
    }
    return
}

proc ::tcltest::initConstraintsHook {} {}

# ::tcltest::initConstraints --
#
# Check Constraintsuration information that will determine which tests
# to run.  To do this, create an array ::tcltest::testConstraints.  Each
# element has a 0 or 1 value.  If the element is "true" then tests
# with that constraint will be run, otherwise tests with that constraint
# will be skipped.  See the README file for the list of built-in
# constraints defined in this procedure.
#
# Arguments:
#	none
#
# Results:
#	The ::tcltest::testConstraints array is reset to have an index for
#	each built-in test constraint.

proc ::tcltest::initConstraints {} {
    global tcl_platform tcl_interactive tk_version

    catch {unset ::tcltest::testConstraints}

    # The following trace procedure makes it so that we can safely refer to
    # non-existent members of the ::tcltest::testConstraints array without causing an
    # error.  Instead, reading a non-existent member will return 0.  This is
    # necessary because tests are allowed to use constraint "X" without ensuring
    # that ::tcltest::testConstraints("X") is defined.

    trace variable ::tcltest::testConstraints r ::tcltest::safeFetch

    proc ::tcltest::safeFetch {n1 n2 op} {
	if {($n2 != {}) && ([info exists ::tcltest::testConstraints($n2)] == 0)} {
	    set ::tcltest::testConstraints($n2) 0
	}
    }

    ::tcltest::initConstraintsHook

    set ::tcltest::testConstraints(unixOnly) \
	    [string equal $tcl_platform(platform) "unix"]
    set ::tcltest::testConstraints(macOnly) \
	    [string equal $tcl_platform(platform) "macintosh"]
    set ::tcltest::testConstraints(pcOnly) \
	    [string equal $tcl_platform(platform) "windows"]

    set ::tcltest::testConstraints(unix) $::tcltest::testConstraints(unixOnly)
    set ::tcltest::testConstraints(mac) $::tcltest::testConstraints(macOnly)
    set ::tcltest::testConstraints(pc) $::tcltest::testConstraints(pcOnly)

    set ::tcltest::testConstraints(unixOrPc) \
	    [expr {$::tcltest::testConstraints(unix) || $::tcltest::testConstraints(pc)}]
    set ::tcltest::testConstraints(macOrPc) \
	    [expr {$::tcltest::testConstraints(mac) || $::tcltest::testConstraints(pc)}]
    set ::tcltest::testConstraints(macOrUnix) \
	    [expr {$::tcltest::testConstraints(mac) || $::tcltest::testConstraints(unix)}]

    set ::tcltest::testConstraints(nt) [string equal $tcl_platform(os) "Windows NT"]
    set ::tcltest::testConstraints(95) [string equal $tcl_platform(os) "Windows 95"]
    set ::tcltest::testConstraints(win32s) [string equal $tcl_platform(os) "Win32s"]

    # The following Constraints switches are used to mark tests that should work,
    # but have been temporarily disabled on certain platforms because they don't
    # and we haven't gotten around to fixing the underlying problem.

    set ::tcltest::testConstraints(tempNotPc) [expr {!$::tcltest::testConstraints(pc)}]
    set ::tcltest::testConstraints(tempNotMac) [expr {!$::tcltest::testConstraints(mac)}]
    set ::tcltest::testConstraints(tempNotUnix) [expr {!$::tcltest::testConstraints(unix)}]

    # The following Constraints switches are used to mark tests that crash on
    # certain platforms, so that they can be reactivated again when the
    # underlying problem is fixed.

    set ::tcltest::testConstraints(pcCrash) [expr {!$::tcltest::testConstraints(pc)}]
    set ::tcltest::testConstraints(win32sCrash) [expr {!$::tcltest::testConstraints(win32s)}]
    set ::tcltest::testConstraints(macCrash) [expr {!$::tcltest::testConstraints(mac)}]
    set ::tcltest::testConstraints(unixCrash) [expr {!$::tcltest::testConstraints(unix)}]

    # Skip empty tests

    set ::tcltest::testConstraints(emptyTest) 0

    # By default, tests that expose known bugs are skipped.

    set ::tcltest::testConstraints(knownBug) 0

    # By default, non-portable tests are skipped.

    set ::tcltest::testConstraints(nonPortable) 0

    # Some tests require user interaction.

    set ::tcltest::testConstraints(userInteraction) 0

    # Some tests must be skipped if the interpreter is not in interactive mode

    set ::tcltest::testConstraints(interactive) $tcl_interactive

    # Some tests can only be run if the installation came from a CD image
    # instead of a web image
    # Some tests must be skipped if you are running as root on Unix.
    # Other tests can only be run if you are running as root on Unix.

    set ::tcltest::testConstraints(root) 0
    set ::tcltest::testConstraints(notRoot) 1
    set user {}
    if {[string equal $tcl_platform(platform) "unix"]} {
	catch {set user [exec whoami]}
	if {[string equal $user ""]} {
	    catch {regexp {^[^(]*\(([^)]*)\)} [exec id] dummy user}
	}
	if {([string equal $user "root"]) || ([string equal $user ""])} {
	    set ::tcltest::testConstraints(root) 1
	    set ::tcltest::testConstraints(notRoot) 0
	}
    }

    # Set nonBlockFiles constraint: 1 means this platform supports
    # setting files into nonblocking mode.

    if {[catch {set f [open defs r]}]} {
	set ::tcltest::testConstraints(nonBlockFiles) 1
    } else {
	if {[catch {fconfigure $f -blocking off}] == 0} {
	    set ::tcltest::testConstraints(nonBlockFiles) 1
	} else {
	    set ::tcltest::testConstraints(nonBlockFiles) 0
	}
	close $f
    }

    # Set asyncPipeClose constraint: 1 means this platform supports
    # async flush and async close on a pipe.
    #
    # Test for SCO Unix - cannot run async flushing tests because a
    # potential problem with select is apparently interfering.
    # (Mark Diekhans).

    if {[string equal $tcl_platform(platform) "unix"]} {
	if {[catch {exec uname -X | fgrep {Release = 3.2v}}] == 0} {
	    set ::tcltest::testConstraints(asyncPipeClose) 0
	} else {
	    set ::tcltest::testConstraints(asyncPipeClose) 1
	}
    } else {
	set ::tcltest::testConstraints(asyncPipeClose) 1
    }

    # Test to see if we have a broken version of sprintf with respect
    # to the "e" format of floating-point numbers.

    set ::tcltest::testConstraints(eformat) 1
    if {[string compare "[format %g 5e-5]" "5e-05"] != 0} {
	set ::tcltest::testConstraints(eformat) 0
    }

    # Test to see if execed commands such as cat, echo, rm and so forth are
    # present on this machine.

    set ::tcltest::testConstraints(unixExecs) 1
    if {[string equal $tcl_platform(platform) "macintosh"]} {
	set ::tcltest::testConstraints(unixExecs) 0
    }
    if {($::tcltest::testConstraints(unixExecs) == 1) && \
	    ([string equal $tcl_platform(platform) "windows"])} {
	if {[catch {exec cat defs}] == 1} {
	    set ::tcltest::testConstraints(unixExecs) 0
	}
	if {($::tcltest::testConstraints(unixExecs) == 1) && \
		([catch {exec echo hello}] == 1)} {
	    set ::tcltest::testConstraints(unixExecs) 0
	}
	if {($::tcltest::testConstraints(unixExecs) == 1) && \
		([catch {exec sh -c echo hello}] == 1)} {
	    set ::tcltest::testConstraints(unixExecs) 0
	}
	if {($::tcltest::testConstraints(unixExecs) == 1) && \
		([catch {exec wc defs}] == 1)} {
	    set ::tcltest::testConstraints(unixExecs) 0
	}
	if {$::tcltest::testConstraints(unixExecs) == 1} {
	    exec echo hello > removeMe
	    if {[catch {exec rm removeMe}] == 1} {
		set ::tcltest::testConstraints(unixExecs) 0
	    }
	}
	if {($::tcltest::testConstraints(unixExecs) == 1) && \
		([catch {exec sleep 1}] == 1)} {
	    set ::tcltest::testConstraints(unixExecs) 0
	}
	if {($::tcltest::testConstraints(unixExecs) == 1) && \
		([catch {exec fgrep unixExecs defs}] == 1)} {
	    set ::tcltest::testConstraints(unixExecs) 0
	}
	if {($::tcltest::testConstraints(unixExecs) == 1) && \
		([catch {exec ps}] == 1)} {
	    set ::tcltest::testConstraints(unixExecs) 0
	}
	if {($::tcltest::testConstraints(unixExecs) == 1) && \
		([catch {exec echo abc > removeMe}] == 0) && \
		([catch {exec chmod 644 removeMe}] == 1) && \
		([catch {exec rm removeMe}] == 0)} {
	    set ::tcltest::testConstraints(unixExecs) 0
	} else {
	    catch {exec rm -f removeMe}
	}
	if {($::tcltest::testConstraints(unixExecs) == 1) && \
		([catch {exec mkdir removeMe}] == 1)} {
	    set ::tcltest::testConstraints(unixExecs) 0
	} else {
	    catch {exec rm -r removeMe}
	}
    }

    # Locate tcltest executable

    if {![info exists tk_version]} {
	set tcltest [info nameofexecutable]

	if {$tcltest == "{}"} {
	    set tcltest {}
	}
    }

    set ::tcltest::testConstraints(stdio) 0
    catch {
	catch {file delete -force tmp}
	set f [open tmp w]
	puts $f {
	    exit
	}
	close $f

	set f [open "|[list $tcltest tmp]" r]
	close $f
	
	set ::tcltest::testConstraints(stdio) 1
    }
    catch {file delete -force tmp}

    # Deliberately call socket with the wrong number of arguments.  The error
    # message you get will indicate whether sockets are available on this system.

    catch {socket} msg
    set ::tcltest::testConstraints(socket) \
	    [expr {$msg != "sockets are not available on this system"}]
    
    # Check for internationalization

    if {[info commands testlocale] == ""} {
	# No testlocale command, no tests...
	set ::tcltest::testConstraints(hasIsoLocale) 0
    } else {
	set ::tcltest::testConstraints(hasIsoLocale) \
	    [string length [::tcltest::set_iso8859_1_locale]]
	::tcltest::restore_locale
    }
}   

proc ::tcltest::processCmdLineArgsAddFlagsHook {} {}

proc ::tcltest::processCmdLineArgsHook {flag} {}

# ::tcltest::processCmdLineArgs --
#
#	Use command line args to set the verbose, skip, and
#	match, outputChannel, errorChannel, debug, and temporaryDirectory
#       variables.   
#
#       This procedure must be run after constraints are initialized, because
#       some constraints can be overridden.
#
# Arguments:
#	none
#
# Results:
#	Sets the above-named variables in the tcltest namespace.

proc ::tcltest::processCmdLineArgs {} {
    global argv

    # The "argv" var doesn't exist in some cases, so use {}.

    if {(![info exists argv]) || ([llength $argv] < 2)} {
	set flagArray {}
    } else {
	set flagArray $argv
    }
    
    # Allow for 1-char abbreviations, where applicable (e.g., -match == -m).
    # Note that -verbose cannot be abbreviated to -v in wish because it
    # conflicts with the wish option -visual.

    if {[catch {array set flag $flagArray}]} {
	::tcltest::PrintError "odd number of arguments specified on command line: \ 
		$argv"
	exit
    }
    
    lappend defaultFlags {-verbose -match -skip -constraints \
	    -outfile -errfile -debug -tmpdir}
    lappend defaultFlags [ ::tcltest::processCmdLineArgsAddFlagsHook ]

    foreach arg $defaultFlags {
	set abbrev [string range $arg 0 1]
	if {([info exists flag($abbrev)]) && \
		([lsearch -exact $flagArray $arg] < \
		[lsearch -exact $flagArray $abbrev])} {
	    set flag($arg) $flag($abbrev)
	}
    }

    # Set ::tcltest::verbose to the arg of the -verbose flag, if given

    if {[info exists flag(-verbose)]} {
	set ::tcltest::verbose $flag(-verbose)
    }

    # Set ::tcltest::match to the arg of the -match flag, if given.  

    if {[info exists flag(-match)]} {
	set ::tcltest::match $flag(-match)
    } 

    # Set ::tcltest::skip to the arg of the -skip flag, if given

    if {[info exists flag(-skip)]} {
	set ::tcltest::skip $flag(-skip)
    }

    # Use the -constraints flag, if given, to turn on constraints that are
    # turned off by default: userInteractive knownBug nonPortable.  This
    # code fragment must be run after constraints are initialized.

    if {[info exists flag(-constraints)]} {
	foreach elt $flag(-constraints) {
	    set ::tcltest::testConstraints($elt) 1
	}
    }

    # If an alternate error or output files are specified, change the
    # default channels.

    if {[info exists flag(-outfile)]} {
	set tmp $flag(-outfile)
	if {[string compare [file pathtype $tmp] "absolute"] != 0} {
	    set tmp [file join $::tcltest::temporaryDirectory $tmp]
	}
	set ::tcltest::outputChannel [open $tmp w]
    } 

    if {[info exists flag(-errfile)]} {
	set tmp $flag(-errfile)
	if {[string compare [file pathtype $tmp] "absolute"] != 0} {
	    set tmp [file join $::tcltest::temporaryDirectory $tmp]
	}
	set ::tcltest::errorChannel [open $tmp w]
    }

    # If the user specifies debug testing, print out extra information during
    # the run.
    if {[info exists flag(-debug)]} {
	set ::tcltest::debug true
	if {$flag(-debug) != {}} {
	    set ::tcltest::debugLevel $flag(-debug)
	}
    }

    # Set the ::tcltest::temporaryDirectory to the arg of -tmpdir, if
    # given.
    # 
    # If the path is relative, make it absolute.  If the file exists but
    # is not a dir, then return an error.
    #
    # If ::tcltest::temporaryDirectory does not already exist, create it.
    # If you cannot create it, then return an error.

    set tmpDirError ""
    if {[info exists flag(-tmpdir)]} {
	set ::tcltest::temporaryDirectory $flag(-tmpdir)

	if {[string compare \
		[file pathtype $::tcltest::temporaryDirectory] \
		"absolute"] != 0} { 
	    set ::tcltest::temporaryDirectory [file join [pwd] \
		    $::tcltest::temporaryDirectory] 
	}
	set tmpDirError "bad argument \"$flag(-tmpdir)\" to -tmpdir: "
    }
    if {[file exists $::tcltest::temporaryDirectory]} {
	if {![file isdir $::tcltest::temporaryDirectory]} { 
	    ::tcltest::PrintError "$tmpDirError \"$::tcltest::temporaryDirectory\" \
		    is not a directory"
	    exit
	} elseif {![file writable $::tcltest::temporaryDirectory]} {
	    ::tcltest::PrintError "$tmpDirError \"$::tcltest::temporaryDirectory\" \
		    is not writeable" 
	    exit
	} elseif {![file readable $::tcltest::temporaryDirectory]} {
	    ::tcltest::PrintError "$tmpDirError \"$::tcltest::temporaryDirectory\" \
		    is not readable" 
	    exit
	}
    } else {
	file mkdir $::tcltest::temporaryDirectory
    }

    # Save the names of files that already exist in
    # the output directory.
    foreach file [glob -nocomplain \
	    [file join $::tcltest::temporaryDirectory *]] {
	lappend ::tcltest::filesExisted [file tail $file]
    }

    ::tcltest::processCmdLineArgsHook [array get flag]

    # Spit out everything you know if ::tcltest::debug is set.
    if {($::tcltest::debug) && ($::tcltest::debugLevel > 1)} {
	puts "Flags passed into tcltest:"
	parray flag
	puts "::tcltest::debug = $::tcltest::debug"
	puts "::tcltest::debugLevel = $::tcltest::debugLevel"
	puts "::tcltest::testsDirectory = $::tcltest::testsDirectory"
	puts "::tcltest::workingDirectory = $::tcltest::workingDirectory"
	puts "::tcltest::temporaryDirectory = $::tcltest::temporaryDirectory"
	puts "::tcltest::outputChannel = $::tcltest::outputChannel"
	puts "::tcltest::errorChannel = $::tcltest::errorChannel"
	puts "Original environment (::tcltest::originalEnv):"
	parray ::tcltest::originalEnv
    }
}

# ::tcltest::cleanupTests --
#
# Remove files and dirs created using the makeFile and makeDirectory
# commands since the last time this proc was invoked.
#
# Print the names of the files created without the makeFile command
# since the tests were invoked.
#
# Print the number tests (total, passed, failed, and skipped) since the
# tests were invoked.
# 
# Restore original environment (as reported by special variable env).

proc ::tcltest::cleanupTests {{calledFromAllFile 0}} {

    set testFileName [file tail [info script]]

    # Call the cleanup hook
    ::tcltest::cleanupTestsHook 

    # Remove files and directories created by the :tcltest::makeFile and
    # ::tcltest::makeDirectory procedures.
    # Record the names of files in ::tcltest::workingDirectory that were not
    # pre-existing, and associate them with the test file that created them.

    if {!$calledFromAllFile} {
	foreach file $::tcltest::filesMade {
	    if {[file exists $file]} {
		catch {file delete -force $file}
	    }
	}
	set currentFiles {}
	foreach file [glob -nocomplain \
		[file join $::tcltest::temporaryDirectory *]] {
	    lappend currentFiles [file tail $file]
	}
	set newFiles {}
	foreach file $currentFiles {
	    if {[lsearch -exact $::tcltest::filesExisted $file] == -1} {
		lappend newFiles $file
	    }
	}
	set ::tcltest::filesExisted $currentFiles
	if {[llength $newFiles] > 0} {
	    set ::tcltest::createdNewFiles($testFileName) $newFiles
	}
    }

    if {$calledFromAllFile || $::tcltest::testSingleFile} {

	# print stats

	puts -nonewline $::tcltest::outputChannel "$testFileName:"
	foreach index [list "Total" "Passed" "Skipped" "Failed"] {
	    puts -nonewline $::tcltest::outputChannel \
		    "\t$index\t$::tcltest::numTests($index)"
	}
	puts $::tcltest::outputChannel ""

	# print number test files sourced
	# print names of files that ran tests which failed

	if {$calledFromAllFile} {
	    puts $::tcltest::outputChannel \
		    "Sourced $::tcltest::numTestFiles Test Files."
	    set ::tcltest::numTestFiles 0
	    if {[llength $::tcltest::failFiles] > 0} {
		puts $::tcltest::outputChannel \
			"Files with failing tests: $::tcltest::failFiles"
		set ::tcltest::failFiles {}
	    }
	}

	# if any tests were skipped, print the constraints that kept them
	# from running.

	set constraintList [array names ::tcltest::skippedBecause]
	if {[llength $constraintList] > 0} {
	    puts $::tcltest::outputChannel \
		    "Number of tests skipped for each constraint:"
	    foreach constraint [lsort $constraintList] {
		puts $::tcltest::outputChannel \
			"\t$::tcltest::skippedBecause($constraint)\t$constraint"
		unset ::tcltest::skippedBecause($constraint)
	    }
	}

	# report the names of test files in ::tcltest::createdNewFiles, and
	# reset the array to be empty.

	set testFilesThatTurded [lsort [array names ::tcltest::createdNewFiles]]
	if {[llength $testFilesThatTurded] > 0} {
	    puts $::tcltest::outputChannel "Warning: files left behind:"
	    foreach testFile $testFilesThatTurded {
		puts "\t$testFile:\t$::tcltest::createdNewFiles($testFile)"
		unset ::tcltest::createdNewFiles($testFile)
	    }
	}

	# reset filesMade, filesExisted, and numTests

	set ::tcltest::filesMade {}
	foreach index [list "Total" "Passed" "Skipped" "Failed"] {
	    set ::tcltest::numTests($index) 0
	}

	# restore the environment to the state it was in before this package
	# was loaded

	set newEnv {}
	set changedEnv {}
	set removedEnv {}
	foreach index [array names env] {
	    if {![info exists ::tcltest::originalEnv($index)]} {
		lappend newEnv $index
		unset env($index)
	    } else {
		if {$env($index) != $::tcltest::originalEnv($index)} {
		    lappend changedEnv $index
		    set env($index) $::tcltest::originalEnv($index)
		}
	    }
	}
	foreach index [array names ::tcltest::originalEnv] {
	    if {![info exists ::env($index)]} {
		lappend removedEnv $index
		set env($index) $::tcltest::originalEnv($index)
	    }
	}
	if {[llength $newEnv] > 0} {
	    puts $::tcltest::outputChannel \
		    "\t\tenv array elements created:\t$newEnv"
	}
	if {[llength $changedEnv] > 0} {
	    puts $::tcltest::outputChannel \
		    "\t\tenv array elements changed:\t$changedEnv"
	}
	if {[llength $removedEnv] > 0} {
	    puts $::tcltest::outputChannel \
		    "\t\tenv array elements removed:\t$removedEnv"
	}

	# exit only if running Tk in non-interactive mode

	global tk_version tcl_interactive
	if {[info exists tk_version] && !$tcl_interactive} {
	    exit
	}
    } else {

	# if we're deferring stat-reporting until all files are sourced,
	# then add current file to failFile list if any tests in this file
	# failed

	incr ::tcltest::numTestFiles
	if {($::tcltest::currentFailure) && \
		([lsearch -exact $::tcltest::failFiles $testFileName] == -1)} {
	    lappend ::tcltest::failFiles $testFileName
	}
	set ::tcltest::currentFailure false
    }
}

proc ::tcltest::cleanupTestsHook {} {}

# test --
#
# This procedure runs a test and prints an error message if the test fails.
# If ::tcltest::verbose has been set, it also prints a message even if the
# test succeeds.  The test will be skipped if it doesn't match the
# ::tcltest::match variable, if it matches an element in
# ::tcltest::skip, or if one of the elements of "constraints" turns
# out not to be true.
#
# Arguments:
# name -		Name of test, in the form foo-1.2.
# description -		Short textual description of the test, to
#			help humans understand what it does.
# constraints -		A list of one or more keywords, each of
#			which must be the name of an element in
#			the array "::tcltest::testConstraints".  If any of these
#			elements is zero, the test is skipped.
#			This argument may be omitted.
# script -		Script to run to carry out the test.  It must
#			return a result that can be checked for
#			correctness.
# expectedAnswer -	Expected result from script.

proc ::tcltest::test {name description script expectedAnswer args} {
    incr ::tcltest::numTests(Total)

    # skip the test if it's name matches an element of skip

    foreach pattern $::tcltest::skip {
	if {[string match $pattern $name]} {
	    incr ::tcltest::numTests(Skipped)
	    if {$::tcltest::debug} {
		::tcltest::AddToSkippedBecause userSpecifiedSkip
	    }
	    return
	}
    }

    # skip the test if it's name doesn't match any element of match

    if {[llength $::tcltest::match] > 0} {
	set ok 0
	foreach pattern $::tcltest::match {
	    if {[string match $pattern $name]} {
		set ok 1
		break
	    }
        }
	if {!$ok} {
	    incr ::tcltest::numTests(Skipped)
	    if {$::tcltest::debug} {
		::tcltest::AddToSkippedBecause userSpecifiedNonMatch
	    }
	    return
	}
    }
    set i [llength $args]
    if {$i == 0} {
	set constraints {}
    } elseif {$i == 1} {

	# "constraints" argument exists;  shuffle arguments down, then
	# make sure that the constraints are satisfied.

	set constraints $script
	set script $expectedAnswer
	set expectedAnswer [lindex $args 0]
	set doTest 0
	if {[string match {*[$\[]*} $constraints] != 0} {

	    # full expression, e.g. {$foo > [info tclversion]}

	    catch {set doTest [uplevel #0 expr $constraints]}

	} elseif {[regexp {[^.a-zA-Z0-9 ]+} $constraints] != 0} {

	    # something like {a || b} should be turned into 
	    # $::tcltest::testConstraints(a) || $::tcltest::testConstraints(b).

 	    regsub -all {[.a-zA-Z0-9]+} $constraints \
		    {$::tcltest::testConstraints(&)} c
	    catch {set doTest [eval expr $c]}
	} else {

	    # just simple constraints such as {unixOnly fonts}.

	    set doTest 1
	    foreach constraint $constraints {
		if {![info exists ::tcltest::testConstraints($constraint)]
		|| !$::tcltest::testConstraints($constraint)} {
		    set doTest 0

		    # store the constraint that kept the test from running

		    set constraints $constraint
		    break
		}
	    }
	}
	if {$doTest == 0} {
	    incr ::tcltest::numTests(Skipped)
	    if {[string first s $::tcltest::verbose] != -1} {
		puts $::tcltest::outputChannel "++++ $name SKIPPED: $constraints"
	    }

	    ::tcltest::AddToSkippedBecause $constraints
	    return	
	}
    } else {
	error "wrong # args: must be \"test name description ?constraints? script expectedAnswer\""
    }   
    memory tag $name
    set code [catch {uplevel $script} actualAnswer]
    if {([string compare $actualAnswer $expectedAnswer] == 0) && ($code == 0)} {
	incr ::tcltest::numTests(Passed)
	if {[string first p $::tcltest::verbose] != -1} {
	    puts $::tcltest::outputChannel "++++ $name PASSED"
	}
    } else {
	incr ::tcltest::numTests(Failed)
	set ::tcltest::currentFailure true
	if {[string first b $::tcltest::verbose] == -1} {
	    set script ""
	}
	puts $::tcltest::outputChannel "\n==== $name $description FAILED"
	if {$script != ""} {
	    puts $::tcltest::outputChannel "==== Contents of test case:"
	    puts $::tcltest::outputChannel $script
	}
	if {$code != 0} {
	    if {$code == 1} {
		puts $::tcltest::outputChannel "==== Test generated error:"
		puts $::tcltest::outputChannel $actualAnswer
	    } elseif {$code == 2} {
		puts $::tcltest::outputChannel "==== Test generated return exception;  result was:"
		puts $::tcltest::outputChannel $actualAnswer
	    } elseif {$code == 3} {
		puts $::tcltest::outputChannel "==== Test generated break exception"
	    } elseif {$code == 4} {
		puts $::tcltest::outputChannel "==== Test generated continue exception"
	    } else {
		puts $::tcltest::outputChannel "==== Test generated exception $code;  message was:"
		puts $::tcltest::outputChannel $actualAnswer
	    }
	} else {
	    puts $::tcltest::outputChannel "---- Result was:\n$actualAnswer"
	}
	puts $::tcltest::outputChannel "---- Result should have been:\n$expectedAnswer"
	puts $::tcltest::outputChannel "==== $name FAILED\n"
    }
}

# ::tcltest::dotests --
#
#	takes two arguments--the name of the test file (such
#	as "parse.test"), and a pattern selecting the tests you want to
#	execute.  It sets ::tcltest::match to the second argument, calls
#	"source" on the file specified in the first argument, and restores
#	::tcltest::match to its pre-call value at the end.
#
# Arguments:
#	file    name of tests file to source
#	args    pattern selecting the tests you want to execute
#
# Results:
#	none

proc ::tcltest::dotests {file args} {
    set savedTests $::tcltest::match
    set ::tcltest::match $args
    source $file
    set ::tcltest::match $savedTests
}

proc ::tcltest::openfiles {} {
    if {[catch {testchannel open} result]} {
	return {}
    }
    return $result
}

proc ::tcltest::leakfiles {old} {
    if {[catch {testchannel open} new]} {
        return {}
    }
    set leak {}
    foreach p $new {
    	if {[lsearch $old $p] < 0} {
	    lappend leak $p
	}
    }
    return $leak
}

proc ::tcltest::saveState {} {
    uplevel #0 {set ::tcltest::saveState [list [info procs] [info vars]]}
    if {($::tcltest::debug) && ($::tcltest::debugLevel > 1)} {
	puts "::tcltest::saveState: $::tcltest::saveState"
    }
}

proc ::tcltest::restoreState {} {
    foreach p [info procs] {
	if {([lsearch [lindex $::tcltest::saveState 0] $p] < 0) && \
		(![string equal ::tcltest::$p [namespace origin $p]])} {
	    if {($::tcltest::debug) && ($::tcltest::debugLevel > 2)} {
		puts "::tcltest::restoreState: Removing proc $p"
	    }
	    rename $p {}
	}
    }
    foreach p [uplevel #0 {info vars}] {
	if {[lsearch [lindex $::tcltest::saveState 1] $p] < 0} {
	    if {($::tcltest::debug) && ($::tcltest::debugLevel > 2)} {
		puts "::tcltest::restoreState: Removing variable $p"
	    }
	    uplevel #0 "unset $p"
	}
    }
}

proc ::tcltest::normalizeMsg {msg} {
    regsub "\n$" [string tolower $msg] "" msg
    regsub -all "\n\n" $msg "\n" msg
    regsub -all "\n\}" $msg "\}" msg
    return $msg
}

# makeFile --
#
# Create a new file with the name <name>, and write <contents> to it.
#
# If this file hasn't been created via makeFile since the last time
# cleanupTests was called, add it to the $filesMade list, so it will
# be removed by the next call to cleanupTests.
#
proc ::tcltest::makeFile {contents name} {
    global tcl_platform
    
    if {($::tcltest::debug) && ($::tcltest::debugLevel > 2)} {
	puts "::tcltest::makeFile: putting $contents into $name"
    }
    set fd [open $name w]

    # Doing the translation breaks TclPro Checker tests
    # under Windows 
    if {[string equal $tcl_platform(platform) "unix"]} {
	fconfigure $fd -translation lf
    }

    if {[string equal \
	    [string index $contents [expr {[string length $contents] - 1}]] \
	    "\n"]} {
	puts -nonewline $fd $contents
    } else {
	puts $fd $contents
    }
    close $fd

    set fullName [file join [pwd] $name]
    if {[lsearch -exact $::tcltest::filesMade $fullName] == -1} {
	lappend ::tcltest::filesMade $fullName
    }
}

proc ::tcltest::removeFile {name} {
    if {($::tcltest::debug) && ($::tcltest::debugLevel > 2)} {
	puts "::tcltest::removeFile: removing $name"
    }
    file delete $name
}

# makeDirectory --
#
# Create a new dir with the name <name>.
#
# If this dir hasn't been created via makeDirectory since the last time
# cleanupTests was called, add it to the $directoriesMade list, so it will
# be removed by the next call to cleanupTests.
#
proc ::tcltest::makeDirectory {name} {
    file mkdir $name

    set fullName [file join [pwd] $name]
    if {[lsearch -exact $::tcltest::filesMade $fullName] == -1} {
	lappend ::tcltest::filesMade $fullName
    }
}

proc ::tcltest::removeDirectory {name} {
    file delete -force $name
}

proc ::tcltest::viewFile {name} {
    global tcl_platform
    if {([string equal $tcl_platform(platform) "macintosh"]) || \
	    ($::tcltest::testConstraints(unixExecs) == 0)} {
	set f [open $name]
	set data [read -nonewline $f]
	close $f
	return $data
    } else {
	exec cat $name
    }
}

# grep --
#
# Evaluate a given expression against each element of a list and return all
# elements for which the expression evaluates to true.  For the purposes of
# this proc, use of the keyword "CURRENT_ELEMENT" will flag the proc to use the
# value of the current element within the expression.  This is equivalent to
# the perl grep command where CURRENT_ELEMENT would be the name for the special
# variable $_.
#
# Examples of usage would be:
#   set subList [grep {CURRENT_ELEMENT == 1} $listOfNumbers]
#   set subList [grep {regexp {abc} CURRENT_ELEMENT} $listOfStrings]
#
# Use of the CURRENT_ELEMENT keyword is optional.  If it is left out, it is
# assumed to be the final argument to the expression provided.
# 
# Example:
#   grep {regexp a} $someList   
#
proc ::tcltest:grep { expression searchList } {
    foreach element $searchList {
	if {[regsub -all CURRENT_ELEMENT $expression $element \
		newExpression] == 0} { 
	    set newExpression "$expression {$element}"
	}
	if {[eval $newExpression] == 1} {
	    lappend returnList $element
	}
    }
    if {[info exists returnList]} {
	return $returnList
    }
    return
}

#
# Construct a string that consists of the requested sequence of bytes,
# as opposed to a string of properly formed UTF-8 characters.  
# This allows the tester to 
# 1. Create denormalized or improperly formed strings to pass to C procedures 
#    that are supposed to accept strings with embedded NULL bytes.
# 2. Confirm that a string result has a certain pattern of bytes, for instance
#    to confirm that "\xe0\0" in a Tcl script is stored internally in 
#    UTF-8 as the sequence of bytes "\xc3\xa0\xc0\x80".
#
# Generally, it's a bad idea to examine the bytes in a Tcl string or to
# construct improperly formed strings in this manner, because it involves
# exposing that Tcl uses UTF-8 internally.

proc ::tcltest::bytestring {string} {
    encoding convertfrom identity $string
}

#
# Internationalization / ISO support procs     -- dl
#
proc ::tcltest::set_iso8859_1_locale {} {
    if {[info commands testlocale] != ""} {
	set ::tcltest::previousLocale [testlocale ctype]
	testlocale ctype $::tcltest::isoLocale
    }
    return
}

proc ::tcltest::restore_locale {} {
    if {[info commands testlocale] != ""} {
	testlocale ctype $::tcltest::previousLocale
    }
    return
}

# threadReap --
#
#	Kill all threads except for the main thread.
#	Do nothing if testthread is not defined.
#
# Arguments:
#	none.
#
# Results:
#	Returns the number of existing threads.
proc ::tcltest::threadReap {} {
    if {[info commands testthread] != {}} {
	testthread errorproc ThreadNullError
	while {[llength [testthread names]] > 1} {
	    foreach tid [testthread names] {
		if {$tid != $::tcltest::mainThread} {
		    catch {testthread send -async $tid {testthread exit}}
		    update
		}
	    }
	}
	testthread errorproc ThreadError
	return [llength [testthread names]]
    } else {
	return 1
    }
}

# Initialize the constraints and set up command line arguments 
namespace eval tcltest {
    ::tcltest::initConstraints
    ::tcltest::processCmdLineArgs
}

return
