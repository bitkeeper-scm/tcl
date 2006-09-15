main(int argc, string argv[], hash env)
{
	string	p;

	foreach (p, keys(env)) {
		printf("env{%s} = %s\n", p, env{p});
	}
}
