main(int ac, string av[])
{
	int	i;
	FILE	fd;

	if (ac == 1) {
		puts("-nonewline", read("stdin"));
	} else {
		for (i = 0; defined(av[i]); i++) {
			fd = open(av[i], "r");
			puts("-nonewline", read(fd));
		}
	}
}
