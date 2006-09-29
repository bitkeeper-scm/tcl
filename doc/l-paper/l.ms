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
.de BU
.IP \(bu 2
..
.\" Title, authors, etc.
.nr PO 1i
.nr LL 6.5i
.po \n[PO]u
.ll \n[LL]u
.HM .75i
.FM .75i
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
This paper describes a new programming language called L.  
L is a compiled-to-byte-code language with the unusual twist that it
compiles to Tcl byte codes and by doing so leverages the entire Tcl
runtime.  
L is designed to peacefully coexist with Tcl rather than replace Tcl
and L functions may call Tcl procs and vice versa.
L and Tcl may coexist in the same source file.
L is a typed language with int, float, string, struct, array, and
hash as first class objects.
The L syntax is reminiscent of C with a bit of C++ thrown in.
.PP
The implementation consists primarily of an additional parser which is
invoked to compile L to byte codes whenever L code is seen.
Tcl has been modified to always compile all procs to byte codes as well 
to enable L<->Tcl cross calls.
.PP
L has been discussed slightly on the #tcl IRC channel and the best quote
to date is from Donal K Fellows who said:
.I "\(lqIt's like perl without the nastiest bits.\(rq"
.PP
L is open source under the same license as Tcl/Tk with the hope that 
people will find it useful and it may encourage more people will join
the Tcl/Tk community.
.AE
.bp
.2C
.NH
Introduction
.LP
BitMover products are produced using a conservative development methodology.
All development goes through a stringent process which relies on heavily
peer review and extensive regression tests to ensure a quality product.
.LP
Because of the stability requirements of our market,
we read code much more than we write it.
Spot checks indicate that we spend at least 10 times as much
time reading and reviewing than we do writing.
So we tend to optimize heavily for the read path rather than the
write path.
.\" Much like a filesystem.  Hmm.  Work that into the talk?
.LP
For years, we have used the Tcl/Tk system for our graphical user interfaces.
We periodically consider the alternatives and have consistently found that 
short of doing native Windows, Aqua, and Java or QT implementations, the
Tcl/Tk system is still the best choice from a development cost point of 
view.
That statement became less true, a lot less true, as two things happened:
.BU
our Tcl source base grew past a manageable size (for us).
.BU
the emphasis is placed on mainly reading and extending, rather than writing.
.LP
We have about 25,000 lines lines of Tcl implementing about a dozen
graphical interfaces for browsing code, checking in code, view changes,
etc.\**
.FS
This number is artificially low because we have been holding off on a number 
GUIs until we had a better answer.  A more realistic number might be 4 times
that size.
.FE
For us, that has become unmanageable, maintainence and extending 
this source has become too expensive.
When the review process was added to the mix, the Tcl costs were starting to
be too high.
.LP
This has been a problem for us for years and we finally decided
to do  something about it.
We investigated the alternatives but in the end the Tcl runtime
and the Tk widgets were too compelling.
We solved our problems by marrying the language syntax we felt
was well suited for  fast reviewing and understanding with what
we feel is the best GUI toolkit and run time available today.
.LP
The rest of the paper is divided sections which discuss the following
topics:
an overview of what L is and how it fits in Tcl,
why the L approach is interesting,
why other runtimes were not choosen,
why not pure Tcl,
why not native GUIs,
L language details such as types, calling/return conventions,
code examples,
current status,
features we have not yet done but want to do,
licensing and availability,
and a summary.
.\" Acknowledgements?  Rob?
.NH 1
L overview
.LP
One way to view a scripting system is as a collection of parts:
.BU
Syntax
.BU
Runtime
.BU
Libraries (aka extensions)
.LP
In Tcl's case there is a parser which can convert Tcl source to Tcl
byte codes,
a runtime which provides the execution environment for those byte codes,
and a large suite of libraries either in Tcl or in C as extensions.
.LP
The syntax part of the system is relatively small when compared to the
code that implements the runtime and the libraries.
So small that it is feasable to add an alternative parser/compiler to the
system and let them both run side by side.
In nutshell, that is L.  It is the small amount of effort required to
leverage a large amount of effort embodied in the runtime and libraries.
.LP
The L compiler creates an abstract syntax tree from L
source and compiles that to byte codes.
The bytes codes generated are traditional Tcl byte codes, following Tcl 
call/return conventions using Tcl variables.
Because we were careful to not break any of those conventions,
L functions may call Tcl procs and vice versa.
This leads to L being able to use the extensive, mature Tcl runtime
and libraries unmodified.
.LP
XXX - how it fits with Tcl?  Need a little more.
.NH 1
Unique design
.LP
As we dive deeper into the L syntax and semantics it would be
easy to be drawn into a discussion of why L is better or why Tcl
is better.
To do so would be to miss an important point.
Whether the L language takes over the world or is used only at
BitMover,  the value of L is that it demonstrates a new way to 
leverage, or reuse, existing code.
.LP
The existence of L opens the door to any number of domain
specific languages being added to the Tcl system.
If some group prefers Python syntax we see no reason they could
not take the L scanner and parser, change the syntax to Python,
and add another syntax to Tcl.
A valid question is \(lqwhy bother?\(rq because Python has a
runtime.
The point isn't Python syntax, it is domain specific languages.
Many organizations have needs for an interpreter of a specific
language and being able to create one without all the work of
creating a runtime is a win.
Consider the GDB debugger.
It wants to let users type C at it and run it.
Consider ModelSim, it's more or less a debugger for  verilog
(and other hardware simulation languages).
Users would like to type in their own language at the debugger.
Having a well maintained runtime with the option of creating an 
arbitrary syntax to use that runtime has many applications.
L is just the first one, we are confident it won't be the last one.
.NH 1
Alternative runtimes
.LP
Perl, Python, Java, etc.
.NH 1
L vs pure Tcl
.LP
Brian went on and on about syntax / lint checker.
Coverity example.
.NH 1
L vs native GUIs
.NH 1
L language details
.NH 1
Example code
.NH 1
Status
.NH 1
Future work
.NH 1
Licensing and availability
.NH 1
Conclusion
.LP
Ever since we switched to L the sun shines out of our asses and all our code
is fantastic.  Oh, and we get more nooky.
.ig
Introduction
.LP
At BitMover, we are great fans of code reading.
We spend much more time reading our source code than writing it.
Most of our source base is written in C, but our GUI is written
in Tcl.
It would greatly simplify things for us if everything was in a
common language.
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
..
