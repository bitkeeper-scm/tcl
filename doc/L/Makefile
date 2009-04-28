all: L.1 L.txt

L.man: L.pod pod2man
	./pod2man $< $@

L.1: L.man
	nroff -man $< >$@

L.txt: L.man
	nroff -man $< | colcrt - > $@

clean:
	rm -f L.man L.1 
	bk clean

shar:
	shar L.pod pod2man Makefile > l.shar
