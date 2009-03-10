# This file provides environment initialization and runtime library
# support for the L language.  It is loaded automatically by init.tcl.
#
# This stuff should probably be in its own namespace or only turned on when
# processing L source.  It breaks tcl scripts.
#
# Copyright (c) 2007 BitMover, Inc.

if {[info exists ::L_libl_initted]} { return }
set ::L_libl_initted 1

set ::%%suppress_calling_main 0

proc %%call_main_if_defined {} {
	if {[llength [info proc main]] && !${::%%suppress_calling_main}} {
		incr ::argc
		set  ::argv [linsert $::argv 0 $::argv0]
		switch [llength [info args main]] {
		    0 {
			set ::%%suppress_calling_main 1
			main
			set ::%%suppress_calling_main 0
		    }
		    1 {
			set ::%%suppress_calling_main 1
			main $::argc
			set ::%%suppress_calling_main 0
		    }
		    2 {
			set ::%%suppress_calling_main 1
			main $::argc $::argv
			set ::%%suppress_calling_main 0
		    }
		    3 {
			set ::%%suppress_calling_main 1
			main $::argc $::argv [dict create {*}[array get ::env]]
			set ::%%suppress_calling_main 0
		    }
		    default {
			error "Too many parameters for main()."
		    }
		}
	}
}

## These commands will be translated to L once we have (expand).

proc printf {args} {
	puts -nonewline [format {*}$args]
}

proc fprintf {stdio args} {
	puts -nonewline $stdio [format {*}$args]
}

proc sprintf {args} {
	return [format {*}$args]
}

proc img_create {args} {
	return [image create photo {*}$args]
}

proc joinpath {args} {
	return [file join {*}$args]
}


#lang L
/*
 * Types for compatibility with older versions of the compiler.
 * The tcl typedef lets the tcl cast work now that it's not
 * hard-coded.
 */
typedef	poly	hash{poly};
typedef	poly	tcl;

typedef	string	FILE;
FILE    stdin  = "stdin";
FILE    stderr = "stderr";
FILE    stdout = "stdout";
string	stdio_lasterr;

struct	stat {
	int	st_dev;
	int	st_ino;
	int	st_mode;
	int	st_nlink;
	int	st_uid;
	int	st_gid;
	int	st_size;
	int	st_atime;
	int	st_mtime;
	int	st_ctime;
	string	st_type;
};


string
basename(string path)
{
	return (file("tail", path));
}

string
caller(int stacks)
{
	return (uplevel(1, "info level -${stacks}"));
}

void
chdir(string dir)
{
	cd(dir);
}

void
chmod(string permissions, string paths[])
{
	string	path;

	foreach (path in paths) {
		file("attributes", path, permissions: permissions);
	}
}

void
chown(string owner, string group, string paths[])
{
	string	path;

	foreach (path in paths) {
		unless (owner eq "") {
			file("attributes", path, owner: owner);
		}

		unless (group eq "") {
			file("attributes", path, group: group);
		}
	}
}

void
die(string message, int exitCode)
{
	warn(message);
	exit(exitCode);
}

string
dirname(string path)
{
	return (file("dirname", path));
}

int
exists(string path)
{
	return (file("exists", path));
}

int
fclose(FILE f)
{
	string	err;
	
	if (f eq "") return (0);
	if (catch("close ${f}", &err)) {
		stdio_lasterr = err;
		return (-1);
	} else {
		return (0);
	}
}

int
fgetline(FILE f, string &buf)
{
	return ((int)gets(f, &buf) > -1);
}

FILE
fopen(string path, string mode)
{
	int	v;
	FILE	f;
	string	err;

	/* new mode, v, means be verbose w/ errors */
	if (mode =~ /v/) {
		mode =~ s/v//;
		v = 1;
	}
	if (catch("set f [open {${path}} ${mode}]", &err)) {
		stdio_lasterr = err;
		if (v) fprintf(stderr, "fopen(%s, %s) = %s\n", path, mode, err);
		return ((string)0);
	} else {
		return (f);
	}
}

void
frename(string oldPath, string newPath)
{
	file("rename", oldPath, newPath);
}

int
fsize(string path)
{
	return (file("size", path));
}

string
ftype(string path)
{
	return (file("type", path));
}

string[]
getdir(string dir, string pattern)
{
	return(glob(nocomplain:, directory: dir, pattern));
}

string
getenv(string varname)
{
	if (info("exists", "::env(${varname})")) {
		return (set("::env(${varname})"));
	}
}

int
isdouble(poly n)
{
	return (string("is", "double", n));
}

int
isdir(string path)
{
	return (file("isdirectory", path));
}

int
isinteger(poly n)
{
	return (string("is", "integer", n));
}

int
isfile(string path)
{
	return (file("isfile", path));
}

int
islink(string path)
{
	return (file("type", path) eq "link");
}

void
link(string sourcePath, string targetPath)
{
	file("link", sourcePath, targetPath);
}

int
lstat(string path, struct stat &buf)
{
	string	st_hash{string};

	unless (exists(path)) return (-1);
	file("lstat", path, "a");
	st_hash = array("get", "a");
	buf.st_dev = (int)st_hash{"dev"};
	buf.st_ino = (int)st_hash{"ino"};
	buf.st_mode = (int)st_hash{"mode"};
	buf.st_nlink = (int)st_hash{"nlink"};
	buf.st_uid = (int)st_hash{"uid"};
	buf.st_gid = (int)st_hash{"gid"};
	buf.st_size = (int)st_hash{"size"};
	buf.st_atime = (int)st_hash{"atime"};
	buf.st_mtime = (int)st_hash{"mtime"};
	buf.st_ctime = (int)st_hash{"ctime"};
	buf.st_type = st_hash{"type"};
}

void
mkdir(string path)
{
	file("mkdir", path);
}

int
mtime(string path)
{
	return (file("mtime", path));
}

int
pclose(FILE f)
{
	return (fclose(f));
}

FILE
popen(string cmd, string mode)
{
	int	v;
	FILE	f;
	string	err;
	
	if (mode =~ /v/) {
		mode =~ s/v//;
		v = 1;
	}
	if (catch("set f [open {|${cmd}} ${mode}]", &err)) {
		stdio_lasterr = err;
		if (v) fprintf(stderr, "popen(%s, %s) = %s\n", cmd, mode, err);
		return ((string)0);
	} else {
		return (f);
	}
}

string
readlink(string path)
{
	return (file("readlink", path));
}

string
require(string packageName)
{
	package("require", packageName);
}

int
rmdir(string dir)
{
	if (catch("file delete \"${dir}\"")) return (0);
	return (1);
}

string
setenv(string varname, string val, int overwrite)
{
	if (overwrite && info("exists", "::env(${varname})")) return;
	return (set("::env(${varname})", val));
}

void
sleep(int seconds)
{
	after(seconds * 1000);
}

int
stat(string path, struct stat &buf)
{
	string	st_hash{string};

	unless (exists(path)) return (-1);
	file("stat", path, "a");
	st_hash = array("get", "a");
	buf.st_dev = (int)st_hash{"dev"};
	buf.st_ino = (int)st_hash{"ino"};
	buf.st_mode = (int)st_hash{"mode"};
	buf.st_nlink = (int)st_hash{"nlink"};
	buf.st_uid = (int)st_hash{"uid"};
	buf.st_gid = (int)st_hash{"gid"};
	buf.st_size = (int)st_hash{"size"};
	buf.st_atime = (int)st_hash{"atime"};
	buf.st_mtime = (int)st_hash{"mtime"};
	buf.st_ctime = (int)st_hash{"ctime"};
	buf.st_type = st_hash{"type"};
}

string
stdio_getLastError()
{
	return (stdio_lasterr);
}

int
strchr(string s, string c)
{
	return (string("first", c, s));
}

int
streq(string a, string b)
{
	return (string("compare", a, b) eq "0");
}

int
strlen(string s)
{
	return ((int)string("length", s));
}

int
strneq(string a, string b, int n)
{
	return (string("equal", length: n, a, b) ne "0");
}

int
strrchr(string s, string c)
{
	return (string("last", c, s));
}

void
symlink(string sourcePath, string targetPath)
{
	file("link", symbolic:, sourcePath, targetPath);
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
	return ((string)0);
}

string
trim(string s)
{
	return (string("trim", s));
}

void
unlink(string paths[])
{
	string	path;

	foreach (path in paths) {
		file("delete", path);
	}
}

void
unsetenv(string varname)
{
	unset(nocomplain: "::env(${varname})");
}

void
warn(string message)
{
	puts(stderr, message);
	flush(stderr);
}


/*
 * Tk API functions
 */

string
tk_windowingsystem()
{
	return (tk("windowingsystem"));
}

void
update_idletasks()
{
	update("idletasks");
}

string[]
winfo_children(string w)
{
	return (winfo("children", w));
}

string
winfo_containing(int x, int y)
{
	return (winfo("containing", x, y));
}
