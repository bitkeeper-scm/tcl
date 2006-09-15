main(int ac, string av[])
{
	int	i;
	string	regex;
	FILE	fd;

	regex = argv[1];
	ac--;
	if (ac == 1) {
		grep(regex, "stdin");
	} else {
		for (i = 0; defined(argv[i]); i++) {
			fd = open(argv[i], "r");
			grep(regex, fd);
			close(fd);
		}
	}
}

void
grep(string regex, FILE in)
{
	string	buf;

	while (gets(fd, buf)) {
		if (buf =~ /${regex}/) {
			printf("%s\n", buf);
		}
	}
}
