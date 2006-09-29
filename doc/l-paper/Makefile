l.ps: l.ms references
	groff -R -ms -p -t l.ms > l.ps

g: l.ms
	g groff -R -ms -p -t l.ms 

l-language.ps: l-language.me references
	groff -R -me l-language.me > l-language.ps
