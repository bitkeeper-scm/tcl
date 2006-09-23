.\" The L Programming Language
.\" Copyright (c) 2006 BitMover, Inc.
.\"
.\" process with 
.\"    groff -R -ms l.ms > l.ps
.\"
.\" Commands for refer
.R1
database references
accumulate
.R2
.\" Title, authors, etc.
.TL
The L Programming Language
.br
or
.br
Tcl for C Programmers
.AU
Oscar Bonilla, Tim Daly, Jr., Larry McVoy
.AI
BitMover, Inc.
300 Orchard City Drive, Suite 132
Campbell, CA 95008
\f(CR
l@bitmover.com
\fP
.\" Abstract
.AB
This paper describes a new programming language called L.  The goal of
L is to make it easy for C programmers to take full advantage of
Tcl/Tk without requiring them to be proficient in Tcl. L is a new
programming language that shares most of its syntax and semantics with
C, including pointers and a weak static type system.  We have modified
the Tcl parser to add a special command which can be used to switch
between L and Tcl syntax. Source code written in L syntax is passed to
a simple compiler which emits Tcl bytecode. So L source code can be
mixed freely with Tcl source code, and Tcl and L can share data and
functions transparently. L is free and open source, and the authors
hope it will bring many new people to the Tcl community.
.AE
.\" Main text
.NH
Introduction
.LP
At BitMover, we are great fans of code reading. We spend much more
time reading our source code than writing it. Most of our source base
is written in C, but our GUI is written in Tcl. It would greatly
simplify things for us if everything was in a common language.
However, using Tk from C would be difficult and error-prone.
.LP
For that reason, we've decided to implement a new language that shares
the Tcl runtime. By keeping the language similar to C we can use the
same idioms as we would in C, avoiding confusion. To make access to Tk
and other Tcl libraries seamless, the language runs right in the Tcl
runtime. Its functions are Tcl functions, and its types are Tcl types.
.LP
In keeping with the grand tradition of one letter language names, this
new language is called L. In the next section, we will go into more
detail about some interesting aspects of the language. After that we
discuss its implementation as a front-end for Tcl.  Finally we touch
on our plans for the future of L, and tell you where you can get a
copy.
.NH
The L Language
.LP
Say that we're mostly like C and then go on to describe where we're
different.  Explain how L types correspond to Tcl types, and give an
example of the interaction between the two languages.
.\" This is an example reference so that I don't forget how to make one
.[
kernighan cherry eqn
.]
.NH
The Implementation
.LP
The first step in processing an L program is to read in the source
code.  L source code can be in its own file, or it can be in a mixed
file together with Tcl source code.
.NH 2
Parsing Mixed Languages
.LP
The most obvious approach to embedding L code within a Tcl program
would be to pass the L code as an argument to a new Tcl command which
implements L.  However, the Tcl syntax rule that "braces nest within a
word" [cite endekalogue/tcl book?] means that we would still be
required to match (or escape) braces within the L code.  This would be
an unpleasant wrinkle for the L programmer to deal with.
.LP
In order to free the brace characters from the reign of Tcl, it was
necessary to modify the Tcl parser.  We added support for special
comments that start with the word "pragma".  The parser consumes the
input from an opening pragma to a closing pragma, and packages it as a
pair of Tcl words -- the name of the command that implements L,
followed by the source code between the pragmas.  In this way, the
result of parsing embedded L code is the same as if the L code had
been properly escaped.
.NH 1
\...
.LP
Mention using Tcl to generate C code, and explain how L pointers work.
Take opportunity to release bile about Tcl being a bizarre backend for
a C compiler.
.NH
"Current Status, Availability
.lp 
L is completely finished and golden, and has a magic shield of +2
anti-bitrot.  You can get it from sunsite, tsx-11, or wuarchive.
Build instructions are for sissies.
.\"  All done, print the references
.[
$LIST$
.]
