void
push(string &l[], string val)
{
	lappend(&l, val);
}

main(int ac, string av[])
{
	int	i;
	FILE	f;
	string	buf;
	string	l[];
	string	s[];

	fconfigure("stdout", buffering: "full", translation: "binary");
	for (i = 1; i < ac; ++i) {
		f = open(av[i], "rb");
		while (gets(f, &buf) >= 0) {
			// Not until we compile push.  Too slow.
			// push(&l, buf);
			lappend(&l, buf);
		}
	}
	s = lsort(l);
	for (i = 0; defined(s[i]); i++) {
		puts(s[i]);
	}
}
