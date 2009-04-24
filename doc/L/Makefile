all: L.1

L.man: L.pod
	./pod2man $< $@

L.1: L.man
	nroff -man $< >$@

clean:
	rm -f L.man L.1
