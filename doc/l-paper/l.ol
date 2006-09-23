Outline
	What is it?
	Why did we do it?
	Details
	Code examples
	How does it work?
	Status or what doesn't work yet
	Future directions
	License and Availability
What is it?
	C-like syntax with a compiler that generates tcl byte codes
	Does not change tcl system
	Interoperates with the tcl system
	Leverages the tcl runtime
	An example of a multi-syntax system (can have tcl & L in same file)
Why did we do it?
	Already comitted to tcl/tk
	Tcl pros
		Stable runtime
		Easy to extend in C
		Powerful, dynamic language
	Tcl cons
		Hard to read (for us)
		No structs - probably the single biggest reason
		Lots of missing syntactic sugar
			foo[3] or [lindex foo 3]
			if (buf =~ /blah.*blech/)
			or
			if {[regexp blah.*blah buf]}
			etc.
	We're a conservative development organization.	We sell
	to enterprise customers and we support releases going back
	indefinitely in some cases.  All code goes through peer review and
	is optimized for ease of reading more than for ease of writing.
	We found tcl to be suboptimal in this environment, particularly
	because of the lack of structs but also because of the lack of 
	syntactic sugar - calling procs to do array indexing is way over
	our threshold of pain for readability.
Details
	C-like syntax compiled to tcl byte code
		L can call tcl, tcl can call L
	Additions over C
		perl like regex in expressions
		associative arrays
		defined() for variables, hashes, arrays
			defined(foo)		[info exists] or winfo ???
			defined(foo{"bar"})
			defined(blech[2])
		strings are a basic type like int/float
	Additions over tcl
		structs
		type checking
	Types
		string (same as tcl string)
		int, float (type checked)
		var (unknown type, strongly typed on first assignment)
		poly (like tcl variable, no type checking)
		hash (associative array, currently string types for key/val)
			XXX - need syntax for saying what data type is,
			currently it is var/var, i.e., indexed by whatever,
			returns whatever, but first assignment determines
			type for all later assignments.
			We could allow
				hash	poly foo{poly}
			if we ever want that fucked up syntax.
	Pass by reference or value?
		base types are all by value, COW, like tcl
		arrays and hashes are references
			pass an array to a proc, modify array[3], caller sees
		strings are a mess
			think upvar in gets
