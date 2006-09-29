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
label-in-text
label A.nD.y%a
.R2
.de CS
.sp .25
.KS
.in +.5
.ft CW
.nf
..
.de CE
.sp .25
.in
.ft
.fi
.KE
..
.de BR
\fB\\$1\fR\\$2
..
.de LI
'br
.ne 4
.LP
.B "\\$*"
'br
..
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
L is designed to peacefully coexist with Tcl rather than replace Tcl.
L functions may call Tcl procs and vice versa, they may also coexist
in the same source file.
L is a static weakly typed language with int, float, string, struct,
array, and hash as first class.
The L syntax is reminiscent of C with a bit of C++ thrown in.
.PP
The implementation consists primarily of a simple compiler which Tcl
invokes whenever L source code is encountered.
The L code is parsed by a Bison generated parser into an AST which is
typechecked and then translated into Tcl bytecode.
Upon its execution, L code is indistinguishable from Tcl code, which
makes for easy interoperability.
.ig
.PP
L has been discussed slightly on the #tcl IRC channel and the best quote
to date is from Donal K Fellows who said:
.I "\(lqIt's like perl without the nastiest bits.\(rq"
..
.PP
L is open source under the same license as Tcl/Tk with the hope that 
people will find it useful and it may encourage more people will join
the Tcl/Tk community.
.AE
.bp
.EQ
delim @@
.EN
.ce 1
.I "\(lqIt's like perl without the nastiest bits.\(rq"
.sp .5
.ce 1
-- Donal K. Fellows
.sp
.2C
.NH
Introduction
.LP
BitMover products are produced using a conservative development methodology.
All development goes through a stringent process which relies heavily on
peer review and extensive regression tests to ensure a quality product.
.LP
Because of the stability requirements of our market,
we read code much more than we write it.
Spot checks indicate that we spend at least 10 times as much
time reading and reviewing than we do writing.
Naturally, we tend to optimize heavily for the read path rather than the
write path.
.\" Much like a filesystem.  Hmm.  Work that into the talk?
.LP
For years, we have used the Tcl/Tk system for our graphical user interfaces.
We periodically consider the alternatives and have consistently found that 
short of doing native implementations, the
Tcl/Tk system is still the best choice from a development cost point of 
view.
Our estimate is that it would cost roughly six times as much to develop
and maintain native GUIs instead of using a single Tcl sourcebase for all 
platforms.
However, the maintenance of our Tcl sourcebase has recently become
problematic because two things happened:
.BU
our Tcl source base grew past a manageable size (for us).
.BU
our emphasis shifted mainly to reading and extending, rather than writing.
.LP
We have about 25,000 lines lines of Tcl implementing about a dozen
graphical interfaces for browsing code, checking in code, viewing changes,
etc.\**
.FS
This number is artificially low because we have been holding off on a number 
of GUIs until we had a better answer.  A more realistic number might be 4 times
that size.
.FE
Maintaining and extending the Tcl source base has become unmanageable, and
when the review process was added to the mix, the costs started to be
too high.
.LP
This has been a problem for us for years and we were forced to come up with 
a better answer.
We investigated the alternatives but in the end the Tcl runtime
and the Tk widgets were too compelling.
We solved our problems by marrying the language syntax we felt
was well suited for  fast reviewing and understanding with what
we feel is the best GUI toolkit and run time available today.
.LP
The rest of the paper is divided sections which discuss the following
topics:
an overview of L,
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
.\" Acknowledgements?  Rob? Jeff?
.NH 1
L overview
.LP
L is actually a very small addition to the Tcl system.
If we divide the Tcl system in the logical parts this becomes obvious:\**
.FS
The set of sources are: Tcl, Tk, Tile, tktable, treecontrol, and Bwidgets.
These numbers are rough, they include the docs and all platform specific 
code that may not be used.  Even if we are off by 2x, the <= 1% holds true.
.FE
.TS
expand box;
l l
l c.
Subsection	Percentage of total
=
Tcl parser/compiler	<= 1%
L parser/compiler	<= 1%
Tcl runtime	48%
Tk	51%
.TE
.LP
The syntax parser and compiler is quite small when compared to the
code that implements the runtime and the libraries (in both Tcl and L it
is less than 10K lines of code).
Because the parser/compiler is such a small part of the system, it is
reasonable to add an alternative parser/compiler to the
system and let them both run side by side.
That is L in a nutshell.
It is the small amount of effort required to leverage a large amount of
effort embodied in the runtime and libraries.
.LP
The L compiler creates an abstract syntax tree from L
source and compiles that to byte codes.
The bytes codes generated are traditional Tcl byte codes, following Tcl 
call/return conventions, and using Tcl variables.
Because we are careful to not break any Tcl rules,
L functions may call Tcl procs and vice versa.
This allows L to use the extensive, mature Tcl/Tk runtime
and libraries unmodified.
.NH 1
Unique design
.LP
As we dive deeper into the L syntax and semantics it would be
easy to be drawn into a discussion of why L is better or why Tcl
is better.
To do so would be to miss an important point.
Regardless of the merits of each language's syntax, the value of L
is that it demonstrates a new way to leverage and reuse, existing code.
With a relatively small amount of effort, we have leveraged over 
1.4 million lines of source making up the Tcl/Tk system plus the 
extensions we use.
.LP
The existence of L opens the door to any number of domain
specific languages being added to the Tcl runtime system.
.ig
If some group prefers Python syntax we see no reason they could
not take the L scanner and parser, change the syntax to Python,
and add another syntax to Tcl.
A reasonable question is \(lqwhy bother?\(rq because Python has a
runtime.
The answer isn't Python, it is domain specific languages.
Any effort that needs a specific syntax to be interpreted could
take our approach and get the job done for far less effort than
starting from scratch.
..
.LP
For example, consider the GDB debugger.
GDB wants to let users type C, C++, etc., at it and run the code.
Doing so means GDB has to provide an interpreter and a runtime.
Rather than building one, GDB could reuse the ideas and code
pioneered by the L effort.
Having a well maintained runtime with the option of creating an 
arbitrary syntax to use that runtime is useful for any sort of
debugger or runtime inspector.
L is just one example of a different syntax leveraging the Tcl/Tk system,
we are confident there will be others.
.NH 1
Alternative runtimes
.LP
Once the idea of adding a different parser/compiler to a scripting
language is understood, the question becomes: why Tcl rather than some
other runtime?
There is a rich set of runtimes, Perl, Python, Ruby, and others.
Why not one of them?
We looked, briefly, at that question.
Our need was for a well supported, mature runtime that supported
scripting GUI interfaces and was extensible from C.
.LP
We dismissed Java because the runtime is too large and the GUI toolkits
are weak, both in features and in performance.
The other runtimes addressed the GUI issues mostly by providing Tk
bindings (and in some cases Qt or Gtk bindings).
Any system that is using Tk bindings is already dragging along a Tcl
interpreter to run the Tk code.
It seemed like a waste to have a different interpreter just for the GUIs.
It has also been our experience that the only way to build robust
software systems is to have the minimum number of "moving parts".
Having two interpreters is an unnecessary complication.
.LP
But even if there were a good runtime with a good GUI interface, there was
another requirement we felt was only well addressed by Tcl.
Tcl has been designed from the onset to be an extendable language.
The original vision was that Tcl was glue and all the heavy lifting would
be done by C extensions to the language.
The internal Tcl code is fairly small and quite pleasant to use; adding
extensions is straightforward and natural.
Other systems fell short in this area.
.NH 1
L vs pure Tcl
.\" Brian went on and on about syntax / lint checker.
.\" Coverity example.
.LP
Many in the Tcl community may question whether there is any value in an
alternate syntax for the Tcl runtime.
After all, Tcl is a powerful, dynamic language and many significant
applications are based on Tcl.
.LP
We agree that Tcl is powerful but that power comes at a cost.
Tcl's dynamic nature makes it impossible to detect even simple parse
errors, such as a typo, without running the program.
.LP
Although there are some advantages to this approach in language
design, there are also big drawbacks:
.LI Data structures.
Probably the single largest problem we found with Tcl was the lack of
C-like structs.
These are commonly emulated with associative arrays.
That isn't good enough because the "struct fields" are 
scattered all over the source base rather than being in one place,
laid out with types and comments.
A fairly famous paraphrasing of something Fred Brooks said summarizes
it nicely:
.ft I
\(lqShow me your code and conceal your data structures, and I shall
continue to be mystified. Show me your data structures, and I won't
usually need your code; it'll be obvious.\(rq
.LI Lint.
It is impossible to write syntax checker or a lint-like tool for Tcl that
works 100% of the time unless that tool is actually running the language.
Even an interpreter based tool would have the problem that it is not 
practical to force the application through all possible code paths.
It is worth noting that this problem is present in all dynamic languages
and the object oriented languages have the same problem; you can't 
just look at the code and know what it is doing.
.LI Reviewing.
As mentioned above, at BitMover we do a lot of peer review as well as
other forms of code reading.
For the same reasons that it is difficult to write a lint-like tool
for Tcl, it is difficult for a human to look at Tcl and understand what
it is doing.
The verbose style of basic operations in Tcl (\f(CWset tmp [lindex $foo
$i]\fP vs "\f(CWtmp = foo[i]\fP" for example) tend to obscure what is
actually being said in the code.
.LI Optimization.
Optimizing Tcl is more challenging than optimizing a ``weaker'' language
such as L.
Many well understood optimization techniques could be applied to the
compilation of L, resulting in a significant performance increase for
some programs.
As an example, due to the static type system of L, we believe it's
possible to make L immune to ``shimmering.''
.[
shimmering
.]
.LP
We tend to view Tcl more like assembly language on steriods.
It is a powerful tool and when that power is needed it is 
appreciated.
But most of the time we are doing fairly simplistic programming
deliberately so it is easy to read, and we find that a static language
with a static type system is much easier for us to read and easier
for a compiler to optimize and check.
.NH 1
L vs native GUIs
.LP
This question gets raised at least once a year here: why not do native
GUIs?
It is certainly possible to do so, we have done implementations of
several of our GUIs in other toolkits.
The arguments for doing so are compelling: better look and feel, native
behavior, etc.
.LP
The reasons for using Tcl/Tk are simple:
.LI Cost.
The cost of creating 2-4 different implementations of each GUI interface is
probably 3 times what it took us to get where we are today.
But the cost does not end there.
The cost extends to testing the GUIs on each platform as well as putting
processes in place to make sure that the GUIs march forward in sync,
i.e., if the Java revtool gets a new feature that same feature needs to
be added to the Linux, Windows, and Aqua GUIs.
When we add up all the costs, it looks more like 6 times the effort.
.LI Functionality.
Every time we go look at the other toolkits we find that they are not as
powerful as the Tk toolkit.
In particular, the canvas and text widgets are more useful than any others
we have found.
.sp .5
That said, a large drawback of the Tk approach is the lack of a complete
widget set in the core.
In order to get the functionality needed, a ragtag group of extensions, 
with partially overlapping features, need to be combined into a Tcl/Tk
"distribution."
We look forward to the day that this issue is resolved.
.NH 1
L language details
.LP
In this section we cover some of the differences from C, differences
form Tcl, types, call/return conventions, expressions, and control flow.
.NH 2
Extensions to C
.LI Regex.
L uses Perl's syntax for regular expressions in statements, but it uses
Tcl's regular expression engine.
So you may say:
.CS
if (buf =~ /foo.*bar/)
.CE
to get the same results as Tcl's
.CS
if {[regexp {foo.*bar} $buf]}
.CE
.LI Associative arrays.
We call these hashes in L to distinguish them from traditional C like arrays.
The keys and the values are strings.
.LI Arrays grow.
If you assign into an array past the last element the array grows as needed.
Many constructs that would normally use C pointers, such as linked lists
or trees, can be constructed with an array of structures linked via indices
rather than pointers.
.LI defined().
A built-in which indicates if the variable passed is defined.
The following test for the existence of the variable, the existence of the
field in the hash, and the existence of the array element, respectively.
.CS
defined(foo{"bar"})
defined(stuff[3])
.CE
.LI Strings.
Strings are first class objects like any other base type.
One implication of this are that unlike C strings which are pointers,
if you want to pass a reference to the string you must do so
explicitly.
.ig
XXX: See References?
..
.NH 2
Unimplemented C features
.LP
L does not have bitfields, enums, unions, or pointers in the C sense of a
pointer.
L currently does not have a C-like preprocessor though one is planned.
.NH 2
Extensions to Tcl
.LI Type checking.
L has a weak static type system which makes it possible to do type
checking at compile time.
Note that L's type system is independent of Tcl's runtime type system,
although the two of them can interoperate.
Variables in L may not change types, unlike Tcl where everything is a
string except when it's not (when it is a float or an int or a list,
etc.)
.LI Structs.
C like structs are part of L.
A Tcl API is provided which supports getting/setting fields as well as
introspection.
.LI References.
Pass by reference in Tcl is possible but awkward.
Attempts have been made to improve it in Tcl
.[
pass by reference
.]
but they are unsatisfying.
We think our syntax is cleaner and easier to read.
.LI Function prototypes.
Currently these are used to get type checking when calling Tcl builtins.
For example, we can prototype gets() as
.CS
extern int gets(FILE, string &);
.CE
to always require gets to be called with two arguments.
We could also prototype gets as
.CS
extern string gets(FILE);
.CE
to make it return a string.
If prototypes are missing, L treats undefined functions as external Tcl
functions that return poly and take a variable number of arguments of
type poly.
.NH 2
Types
.NH 3
Simple types
.LI int.
Integer types are like C ints, they are sized to the machine (at least 32
bits and possibly 64).
They are not bignums and if we add support for bignum in L we will make a
bignum type.
.LP
Any constant that looks like an int is typed as an int.
.LI float.
Floating point numbers in L are at least double precision IEEE 754.
.LP
Any constant that looks like an float is typed as a float.
Note that this means the following is only legal because of automatic
type conversion of integer to float constant:
.CS
float f = 1;	// Converts to 1.0
.CE
.LI string.
The string type is the same as a Tcl string, but different than a C string.
Strings are not null terminated as they are in C, nor are they an array 
of bytes.
L strings are Tcl strings, which are UTF-8 encoded and have a known length.
To interate over each character in a string use the defined() operator:
.CS
int	i;
string	s = "a string";

for (i = 0; defined(s[i]); i++) {
	printf("s[%d]=%s\\n", i, s[i]);
}
.CE
Note that there is no separate character type in L.
When indexing into a string, each character is merely a string of length 1.
This also means that there is no need to use special single-quoted
syntax for character literals:
.CS
str[i] = "c";
.CE
L provides a special escape sequence, ${, which allows embedding code in
strings.
All the text from ${ to the matching } will be collected and evaluated.
Its value is then substituted into the string:
.CS
int i = 41;

printf("41 + 1 is ${i + 1}\\n"); 
.CE
prints:
.CS
41 + 1 is 42
.CE
.NH 3
Tclish types
.LI poly.
This is a generic type that is like a Tcl variable in that no type checking
is done.
Normal variables will cause an error if they attempt to change types; 
a poly variable supresses the type checking so a variable can switch from
float to array to int, etc.
The following is legal code:
.CS
poly unchecked;

unchecked = 1;
unchecked = "Hey there";
unchecked = 3.14;
.CE
.LI var.
This is a compromise variable type, it is type checked but the type is not
set until the first assignment.
The type is determined from the assignment and may not change.
The following will throw an error:
.CS
var late_binding;

late_binding = 1;
late_binding = "Hey there";
.CE
As we noted above, constant types are intuited.
This may cause problem with @var@ variables.
For example, this will throw an error:
.CS
var	f = 1;	// f is now an int

f += 3.14;	// int/float type error
.CE
but this works fine:
.CS
var	f = 1.0;

f += 3.14;
.CE
.NH 3
Compound types
.LI array.
Arrays are like C arrays in syntax but are implemented as Tcl lists under
the covers.
Array elements are homogeneous, all elements must share the same type.
Array assignments in declarations are supported for globals and locals:
.CS
string	foo[] = { "Hi", "there" };
int	bar[] = { 1, 2, 3, 4 };
int	i;
int	total = 0;

for (i = 0; defined(bar[i]); i++) {
	total += bar[i];
}
.CE
.LI hash.
Hashes are associative arrays, indexed by strings and returning string
values.
They are implemented by Tcl dictionaries under the covers.
Hash assignments in declarations are supported for globals and locals
and follow the Perl syntax:
.CS
hash	h = { "key" => "val",
	      "key2" => "val2" };

h{"foo"} = "bar";
if (defined(h{"blech"})) {
	printf("blech is not a key!\\n");
}
.CE
.LI struct.
Structs are a collection of typed variables, as in C.  
Declarations are same as C declarations.
Struct assignments in declarations are supported for globals and locals:
.CS
typedef struct {
	int	a;
	float	b;
	string	c;
} eg;

eg	s = { 1, 3.14, "hi there" };
.CE
.NH 2
Passing semantics
.LP
L and Tcl have fairly different views on passing information around.
For the most part Tcl is a pass by value system, where each variable
is passed in with an annotation which makes the variable copy on write.
.LP
L is trying to mimic C semantics to some extent so L wants to be able
to pass base types and structures by either value or reference and 
wants to pass arrays and hashes by reference.
.LP
This section describes how this works and how the two languages interoperate
with respect to parameters and returns.
.NH 3
By value
.LP
L obeys Tcl's semantics for pass by value.
Parameter passing looks like it does in C:
.CS
int	i = 1234;

foo(i, 0xdeadbeef, "string");
.CE
L has no way to pass compound types by value to other L functions but 
see the @(tcl)@ cast below for how to pass them to Tcl procs.
.NH 3
By reference
.LP
The Tcl system has a way of passing by reference that may appear strange
to C programmers.
.CS
proc foo {ref} {
	upvar $ref pointer

	set pointer 1
}
.CE
The @upvar@ command creates a reference to the variable in the caller's
context and places it in @pointer@.  
Assignments to @pointer@ are the same as if the assignment was done in
the caller's context (after evaluating the right hand side).
.LP
We used this mechanism to emulate pass by reference in L.
We call it ``pass by name'' because what it is doing is putting the name
of the variable on the stack and in the caller it is doing an automatic
@upvar@ to create the reference.
The syntax looks like:
.CS
void foo(int &ref)
{
	ref = 1234;
}

int	a = 19;

foo(a);
puts(a);
.CE
and that prints
.CS
1234
.CE
Arrays and hashes do not take the ampersand because they are trying to 
behave like C arrays, i.e., they are already references.
.CS
void clear(int v[])
{
	int	i;

	for (i = 0; defined(v[i]); i++) {
		v[i] = 0;
	}
}

int	junk[] = { 1, 2, 3 };

clear(junk);	// junk = { 0, 0, 0 }
.CE
Note that strings, unlike in C, are first class objects and are
.B not
references.
If you want to modify a string you must pass it as a reference.
For example, to use the Tcl builtin for reading a line of intput
you have to do this:
.CS
string	buf;

// buf is an out parameter
gets(stdin, &buf);
.CE
.NH 3
Return values
.LP
Return values ``just work.''
In Tcl and in L returns are always by value in the Tcl sense, i.e., 
a variable that is marked copy on write.
C programmers take note that this is a way to do automatic allocation:
.CS
string[]
vector(int n)
{
	string	v[];

	// Allocate 0..n-1
	v[n - 1] = "";
	return (v);
}

string	foo[] = v(100);
.CE
.NH 2
Casts
.LI (tcl).
There are times when we need to pass a compound object (structure, array,
hash) as a string.
Any Tcl proc which expects to see a string on the stack will want this.
The @(tcl)@ cast is used to do this.
.CS
struct {
	int	a;
	float	b;
	string	c;
} foo = { 1, 2.3, "Hi there" };

puts((tcl)foo);
.CE
prints
.CS
1 2.3 {Hi there}
.CE
.LI (L).
There may be times when a Tcl proc is returning a complex structure to us
and we want to cast it from the Tcl list to our structure:
.CS
#lang(tcl)
proc demo {} {
	return [list 1 2.3 "Hi there"]
}

#lang(L)
// same struct as above
foo = (L)demo();
printf("a=%d b=%f c=%s\\n",
    foo.a, foo.b, foo.c);
.CE
prints
.CS
a=1 b=2.3 c=Hi there
.CE
Note: doing this sort of thing puts you at the mercy of the Tcl code
which knows nothing about the L type system.
.NH 2
Operators
.LP
L supports all of the operators in the C programming language,\** as well
as several of the most useful operators from Perl.
In the this section we do a quick run through all of the operators in L,
and discuss some of the more subtle aspects in depth.
.FS
Since L does not (yet) have pointers in the sense that C does, the C &
address-of operator and * dereference operator are not needed.
.FE
.NH 3
Arithmetic operators
.LP
The binary arithmetic operators in L are +, -, *, /, and % (modulus).
They work as in C with the C precedence rules.
.NH 3
True vs. false
.LP
All of the relational and logical operators are part of an expression and
that expression will evaluate to either true or false.
.LP
In L, there is only one false value.
This is different from Tcl, which allows many false values, such as the
strings "false" and "off".
The false value in L is 0, or, equivalently, "0".
.CS
if (0) {
	printf("consequent\\n");
} else {
	printf("alternative\\n");
}
.CE
prints: alternative
.LP
Any value other than 0 is considered true.
.NH 3
Numeric Comparison
.LP
These all work as in C with the C precedence rules.
.B "Relational operators"
.CS
@expr@ > @expr@
@expr@ >= @expr@
@expr@ < @expr@
@expr@ <= @expr@
.CE
.B "Equality operators"
.CS
@expr@ == @expr@
@expr@ != @expr@
.CE
.LI "Logical Operators"
These all work as in C with the C precedence rules.
The && and || operators short circuit like they do in C.
.CS
@expr@ && @expr@
@expr@ || @expr@
!@expr@
.CE
.NH 3
Regular expression statements
.LP
Stolen from Perl, the first one is true if @regex@ is a regular expression
which matches @string@.  
The second one is true if @regex@ is a regular expression
which does not match @string@.  
@regex@ may be a string variable if it is in the form /\fI${variable}\fP/.
.CS
@string@ =~ /@regex@/
@string@ !~ /@regex@/
.CE
.ig
.NH 3
String Comparison
.LP
To use a numeric operator on a string is a type error in L.
Instead of extending the numeric operators to work on strings, L provides
a separate set of string operators.
.LP
**** relational operators

    gt      Greater Than 
    ge      Greater Than or Equal
    lt      Less Than
    le      Less Than or Equal

**** equality operators

    eq      Equal
    ne      Not equal
..
.NH 3
Increment and Decrement Operators
.LP
As in C, with the value returned either before or after the 
increment or decrement.
.CS
@var@++
++@var@
@var@--
--@var@
.CE
.NH 3
Bitwise Operators
.CS
@expr@ & @expr@
@expr@ | @expr@
@expr@ ^ @expr@
@expr@ << @expr@
@expr@ >> @expr@
~@expr@
.CE
.ne 10
.NH 3
Assignment Operators
.CS
@variable@ = @expr@
@variable@ += @expr@
@variable@ -= @expr@
@variable@ *= @expr@
@variable@ /= @expr@
@variable@ %= @expr@
@variable@ <<= @expr@
@variable@ >>= @expr@
@variable@ &= @expr@
@variable@ |= @expr@
@variable@ ^= @expr@
.CE
.NH 3
Ternary Operator
.CS
@expr@ ? @expr@ : @expr@
.CE
.NH 2
Reserved Words
.LP
These are L's reserved words
.CS
break case continue defined do
else float for foreach if int
poly return string struct switch
tcl typedef unless until var void
while
.CE
.NH 2
Control flow
.LI Conditional statements
.CS
if ( @expr@ ) @statement@
if ( @expr@ ) @statement@ else @statement@
unless ( @expr@ ) @statement@
.CE
In all cases @expr@ is evaluated and if it returns anything other than
zero then the first 
.B if
statement is executed, if it returns zero then the 
.B else 
statement or the 
.B until 
statement is executed.
.LI While/until statements
.CS
while ( @expr@ ) @statement@
until ( @expr@ ) @statement@
.CE
The @expr@ is evaluated and @statement@ is executed repeatedly while
@expr@ is non-zero in the 
.B while 
case, or zero in the
.B until 
case.
.LI do statements
.CS
do @statement@ while ( @expr@ )
do @statement@ until ( @expr@ )
.CE
@statement@ is executed repeatedly while @expr@ is non-zero in the
.B while 
case, or until zero in the
.B until
case.
.LI for statement
.CS
for ( @exp1 sub opt@; @exp2 sub opt@; @exp3 sub opt@ ) @statement@
.CE
All expressions are optional.
Other than the continue statement, which in this case will execute
@exp3@, this is the same as
.CS
@exp1@;
while ( @exp2@ ) {
	@statement@
	@exp3@;
}
.CE
.LI foreach statement
.CS
foreach (@h@ as @key@ => @val@) @statement@
.CE
This statement interates over each key/value pair in the hash @h@.
The key/value pair is placed in @key@ and @val@ and then @statement@ 
is executed.
Behaviour is undefined if @h@ is modified in @statement@.
.LI switch statement
.CS
switch ( @expr@ ) statement
.CE
@expr@ must evaluate to an 
.B int
or a
.BR string .
Any statement within @statement@ may contain one or more labeled statements
of the form
.CS
case @constant-expr@: @statement@
.CE
There may be at most one statement of the form:
.CS
default: @statement@
.CE
When the 
.B switch 
statement is run, @expr@ is evaluated and cause a jump to the 
.B case
label which matches.
If no label matches then if the 
.B default
a jump to the 
.B default 
statement will occur.
As in C, control will continue to flow past labels, see
the \(lqbreak statement\(rq for exiting from a 
.BR switch .
.LI break
.CS
break ;
.CE
causes termination of the smallest enclosing 
.BR while ,
.BR until ,
.BR do ,
.BR for ,
or
.B switch
statement.
.LI continue
.CS
continue ;
.CE
causes control to pass to the loop-continuation portion of the smallest 
enclosing
.BR while ,
.BR until ,
.BR do ,
or
.B for 
loop.
.LI return
.CS
return;
return ( @expr@ );
.CE
In the first case the return value is undefined, in the second the return
value is @expr@.
XXX - talk about returning locals and how that works?
.NH 1
Example code
.NH 2
Types
.NH 3
Basic Data Types
.NH 3
string
.LP
Same as Tcl string.
Unlike C, they are not NULL terminated.
There is no concept of `char` in L.
.CS
// defaults to empty string
string foo;
// initialized string
string bar = "hi mom";
.CE
.LP	
strings support interpolation of L code using `${}`
.CS
string foo = "mom";
// bar is "Hi mom"
string bar = "Hi ${foo}";
.CE
.LP
they are passed by value with Tcl's copy-on-write semantics:
.CS
string foo = "abcdefg";
string bar;

// now bar is "abcdefg"
bar = foo;
// now foo is "zbcdefg"
// but bar is "abcdefg"
foo[0] = 'z';
.CE
.LP
to pass a string by reference, use &
.CS
void
toUpper(string& s)
{
	s = string("toupper", s);
}

int
main()
{
	string foo = "abcdefg";

	toUpper(&foo);
	// prints "ABCDEFG"
	puts(foo);
}
.CE
.NH 3
int
.LP
Same as a Tcl integer, which is at least native machine sized integer value. 
.CS
int     a = 5;
int     b; // defaults to 0
.CE
.NH 3
float
.LP
Same as Tcl's floating point numbers which means double precision floating
point numbers.
.CS
float   f; // defaults to 0.0
float   pi = 3.14159265;
.CE        
.NH 3
poly
.LP
Generic type that means the variable might change types at runtime.
It basically instructs the compiler to ignore type-checking for this
variable.
.CS
string  s;
int     i;
poly    p;

p = s; // ok
p = i; // ok
s = (string)p; // cast needed
.CE

.NH 3
var
.LP
Variables of type `var` get their type from then first assignment.
Once the type has been assigned, it cannot be changed.
.CS
var s = "hi mom"; // type string
s = "look at me now"; // ok
s = 10; // error
s = (string)10; // ok
.CE
.NH 2
Compound Data Types

.NH 3
Arrays
.LP
Arrays are just lists of variables of a common type.

.CS
int	a[10];
int	a[] = { 1, 2, 3, 4 };
.CE
.LP
they are dynamically growing and cannot be sparse.
.CS
a[0] = 10;
a[100] = 20; // allowed
// now a has 101 elements,
// a[1..99] == 0 which is
// the default value for integers
.CE
.LP
The defined operator is an easy way to check if an index is outside
the array bounds:
.CS
// will print 'no'
if (defined(a[101])) {
	printf("yes\\n");
} else {
	printf("no\\n");
}
.CE
.NH 3
Hashes
.LP
Hashes are key, value pairs.
Internally they are Tcl Dictionaries.
.CS
hash    foo;
hash	h = {
	"key" => "val",
	"key1" => "val1"
};	
.CE
.LP	
Hashes are read and written using curly braces instead of square
brackets:
.CS
foo{"key"} = "value";
// prints "value"
printf("Value is %s\\n", foo{"key"});
.CE
.LP
The defined operator can also be use to check if a key is present in a
hash:
.CS
// prints no
if (defined(foo{"k"})) {
	printf("yes\\n");
} else {
	printf("no\\n");
}
.CE
.LP
It is possible to iterate over each value in a hash using a foreach
loop:
.CS
foreach (k, keys(h)) {
	printf("%s => %s\\n", k, h{k});
}
.CE

.NH 3
Structures
.LP
An L structure works like a struct in C.
Declaring a structure defines a new type which amounts to a collection of
named variables, each of which is called a `member` or `field`.
For example, this defines a "struct point" type, which could be used to
represent a location on the screen:
.CS
struct point { int x; int y; };
.CE
.LP
Struct types can be used in the same places as other types, so to
declare a parameter `a` and a local variable `b` that are points:
.CS
int fun(struct point a) {
    struct point b = { 1, 2 };
    ...
.CE
.LP
Individual members of the struct can be denoted using a `.`:
.CS
b.x = 128;
b.y = 256;
// prints "128 256"
printf("%s\\n", b);
.CE
.LP
Structures are implemented as Tcl Lists just like L arrays.
The names are translated into integer indices by the L compiler.
Since it is just a Tcl list, an L structure can be passed to any Tcl proc
that expects a list.
.NH 2
Casting between types
.LP
If you use (tcl) as a typecast, you're basically saying, take this object
and get the string representation of it the same way as Tcl would do it.
For example:
.CS
string	s[] =
    {"hi", "there", "fellow earthling"};

// prints "hi there {fellow earthling}"
puts((tcl)s);
.CE
.NH 2
Examples

.LP
This is an example of calling Tcl's [puts] from L
.CS
puts("Hello World");
.CE
.LP
A personalized version of Hello-World written entirely in L
.CS
int
main(int ac, string av[])
{
	if (ac < 1) {
		printf("Hello Stranger\\n");
	} else {
		printf("Hello %s\\n", av[1])
	}
}
.CE
.LP
Same program written in Tcl/L
.CS
void
print(string s)
{
	printf("This is from L: %s\\n", s)
}
#lang(tcl)
print "Howdy, stranger"
.CE
.ig
.NH 2
Passing Parameters by Reference
.LP
Parameters in Tcl are passed by value.
That means that a Tcl function can't do anything to its parameters that
will affect the values of variables in the function that called it.
.CS
proc caller {} {
  set v 1
  callee $v
  puts $v;   # v still holds 1
}
proc callee {parameter} {
  set parameter 2
}
.CE
.LP
For cases where changes to a parameter should be reflected in the calling
function, Tcl provides upvar.
The calling function passes the name of a variable instead of its value,
and the callee uses the upvar command to create a local variable that is
linked to the original variable in the calling procedure.
When they are linked in this way, they act as one variable -- any change
to one is reflected in the other.
For cases where changes to a parameter should be reflected in the calling
function, Tcl provides upvar.
The calling function passes the name of a variable instead of its value,
and the callee uses the upvar command to create a local variable that is
linked to the original variable in the calling procedure.
When they are linked in this way, they act as one variable -- any change
to one is reflected in the other.
.CS
proc caller {} {
  set v 1
  callee v
  puts $v;   # v now holds 2
}
proc callee {parameter} {
  upvar v $parameter
  set v 2
}
.CE
.LP
Using upvar in this way amounts to passing parameters by reference.
In L, we support both of these modes of parameter passing -- by value and
by reference.
Atomic types like int and string are passed by value by default.
.CS
caller() {
  int v = 1;
  callee(v);
  puts(v);    // v still holds 1
}
callee(int parameter) {
  parameter = 2;
}
.CE
.LP
To get the pass by reference behavior, that is, to use upvar from L, you
must use an & both on the formal parameter and on the actual parameter:
.CS
caller() {
  int v = 1;
  callee(v);
  puts(v);    // v now holds 2
}
callee(int &parameter) {
  parameter = 2;
.CE
.LP
The ampersand can also be used when a Tcl proc is expecting a variable
name, for example:
.CS
  string buf;
  gets("stdin", &buf);
.CE
.LP
Arrays and hashes are passed by reference by default, so they don't
require an &.
This is the way that C arrays behave, and it is generally more useful
than passing them by value.
.CS
caller() {
  int v[] = { 0, 1, 2, 3, 4 };
  callee(v);
  puts(v[0]);    // v[0] now holds 2 instead of 0
}
callee(int parameter[]) {
  parameter[0] = 2;
}
.LP
However, sometimes when calling a Tcl proc it is necessary to pass an L
array or hash by value.
For example, when calling [llength] on an L array (which is a Tcl list),
due to the pass-by-reference nature of arrays, the result is not what you
want:
.CS
  int v[] = { 0, 1, 2, 3, 4 };
  puts(llength(v));    // prints 1
.CE
.LP
What was actually passed to [llength] was the string "v", not the array
itself.
To handle these cases, L provides a special (tcl) typecast.
Casting an array or hash to (tcl) causes L to pass the variable value
instead of its name.
.CS
  int v[] = { 0, 1, 2, 3, 4 };
  puts(llength((tcl)v));    // prints 5
.CE
..
.NH 1
Longer Examples
.NH 2
Fibonacci
.CS
int[]
fib(int n)
{
	int	fib[] = { 0, 1 };
	int	i;
	
	for (i=2; i<n; i++) {
		fib[i] = fib[i-1] + fib[i-2];
	}
	return fib;
}

int
main()
{
	int fib[] = fib(100);
	for (i=0; i<length(fib); i++) {
		printf("%d\\t%d\\n", i, fib[i]);
	}
}
.CE	
.ne 30
.NH 2
A simple grep
.CS
int
main(int ac, string av[])
{
	int     i;
	string  regex;
	FILE    fd;
	
	if (ac < 2) {
		// Tcl's [error]
		error("Not enough arguments.");
	}
	regex = av[1];
	ac--;
	if (ac == 1) {
		grep(regex, &stdin);
	} else {
		for (i = 2; i < ac; i++) {
			fd = open(av[i], "r");
			grep(regex, fd);
			close(fd);
		}
	}
	
}

void
grep(string regex, FILE in)
{
	string	buf;
	
	while (gets(in, &buf) >= 0) {
		if (buf =~ /${regex}/) {
			printf("%s\\n", buf);
		}
	}
}
.CE	


.NH 2
Changes to Tcl
.NH 3
Toplevel Compilation
.LP
Toplevel code in Tcl, i.e., code that isn't contained in a proc body,
is now passed to the bytecode compiler.
We require this so that the L compiler can emit bytecode for toplevel L
code.
It could be useful in the future for saving Tcl bytecode between
invocations, similar to the TclPro compiler.
.NH 3
Changes to the Tcl Parser
.NH 1
Status
.LP
The short summary is we are probably 2 months away from the language 
actually being useful.
What follows are a list of known issues.
.LI Type checking.
Is compile time only, run time checking is unimplemented.
XXX
.NH 1
Future work
.NH 2
Scoping
.LP
Like a C source file, a scope provides a container for private and/or
public variables and/or functions.
Could be used to provide a self contained "class".
.NH 2
Precompiled modules
.LP
Imagine that each scope is a module and each module could be precompiled.
The on disk format is in sections, there is a byte code section and a
sort of table of contents which can be thought of as a header file containing
function prototypes.
.NH 2
Optimizations
.LP
.NH 2
Debugging
.NH 2
L contest
.LP
Once the language is stable enough offer a $10K reward for the best new L
application as a way of drawing people to the language.
.NH 1
Licensing and availability
.LP
The license is the Tcl license; this is part of Tcl as far as we are
concerned.
.LP
The source is maintained in a BitKeeper repository which is a import of
the CVS Tcl repository.
For the 3 people in the world who won't use BK, we will do nightly tarballs
and make them available on ftp.
.NH 1
Conclusion
.LP
Ever since we switched to L the sun shines out of our asses and all our code
is fantastic.
Oh, and we get more nooky.
.[
$LIST$
.]
