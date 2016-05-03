ifeq "$(shell uname -s)" "Darwin"
	PS2PDF	:= pstopdf
	OUT	= -o $@
else
	PS2PDF	:= ps2pdf
endif

little.pdf: little.ps little.ms
	-$(PS2PDF) $(OUT) $<

little.ps: little.ms references
	-groff -e -R -ms -p -t $< > $@

g: little.ms references
	g groff -e -R -ms -p -t $<
