little.pdf: little.ps little.ms
	ps2pdf $<

little.ps: little.ms references
	groff -e -R -ms -p -t $< > $@

g: little.ms references
	g groff -e -R -ms -p -t $<
