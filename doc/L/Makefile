all: L.1 L.txt

L.man: L.pod pod2man
	./pod2man -r L-beta -c 'L Programmers Reference Guide' $< $@

L.1: L.man
	nroff -man $< >$@

L.txt: L.man
	nroff -man $< | colcrt - > $@

x: L.man
	groff -man $< > L.ps
	gv L.ps

clean:
	rm -rf L.man L.1 L.txt L.ps l.shar L-docs
	bk clean

shar: L.pod pod2man Makefile
	rm -rf L-docs
	mkdir L-docs
	cp L.pod pod2man Makefile L-docs
	shar L-docs > l.shar
