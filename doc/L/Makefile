TITLE="L Programmer's Reference Guide"

all: little.1 little.txt little.html

little.man: little.pod pod2man
	./pod2man -r L-beta -c $(TITLE) $< $@

little.html: little.doc pod2html.l
	./pod2html.l --title=$(TITLE) $< > $@

%.pod: %.doc
	sed s/=proto/=item/ < $< > $@

%.1: %.man
	nroff -man $< > $@

%.txt: %.1
	colcrt $< > $@

%.ps: %.man
	groff -man $< > $@

x: little.ps
	gv little.ps

clean:
	rm -rf little.man little.pod little.1 little.txt little.ps \
	    little.shar L-docs little.html

shar: little.doc pod2man Makefile
	rm -rf L-docs
	mkdir L-docs
	cp little.doc pod2man Makefile L-docs
	shar L-docs > little.shar
