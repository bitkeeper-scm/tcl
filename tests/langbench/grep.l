main(int ac, string av[])
{
	string	buf;
	int	i;
	FILE	f;

	fconfigure("stdout", buffering:"full", translation:"binary");
	for (i = 1; i < ac; ++i) {
		f = open(av[i], "rb");
		while (gets(f, &buf) >= 0) {
			if (buf =~ /[^A-Za-z]fopen\\(.*\\)/) puts(buf);
		}
		close(f);
	}
}
