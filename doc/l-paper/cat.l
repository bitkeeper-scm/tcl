main(int ac, string av[])
{
	int	i;
	FILE	fd;

	if (ac == 1) {
		puts("-nonewline", read("stdin"));
	} else {
		for (i = 0; defined(argv[i]); i++) {
			fd = open(argv[i], "r");
			puts("-nonewline", read(fd));
		}
	}
}
