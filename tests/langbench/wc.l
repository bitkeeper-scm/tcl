string []
wordsplit(string str)
{
	string	chars[];
	string	list[];
	string	word;
	int	i;

	word = "";
	chars = split(str, "");
	for (i = 0; defined(chars[i]); i++) {
		if (string("is", "space", chars[i])) {
			if (String_length(word) > 0) {
				lappend(&list, word);
			}
			word = "";
		} else {
			append(&word, chars[i]);
		}
	}
	if (String_length(word) > 0) {
		lappend(&list, word);
	}
	return (list);
}

int
doit(string file)
{
	FILE	f = open(file, "rb");
	string	buf;
	string	words[];
	int	n;

	while (gets(f, &buf) >= 0) {
		words = wordsplit(buf);
		n += llength(words);
	}
	close(f);
	return (n);
}

main(int ac, string av[])
{
	int	total, i;

	for (i = 1; i < ac; ++i) {
		total += doit(av[i]);
	}
	printf("%d\n", total);
}
