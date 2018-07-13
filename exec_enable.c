#include <stdio.h>
#include <stdlib.h>
#include <unistd.h>
#include <sys/stat.h>

int main(int argc, char **argv)
{
	/************************************************
	 * 493 in decimal is 755 in Octal, which is the *
	 * value we need to set the execute and read    *
	 * bits for all users and the write bit for the *
	 * Owner of the files                           *
	 ************************************************/
	int m = 493;

	if(2 != argc)
	{
		printf("arg count\n");
		exit(EXIT_FAILURE);
	}

	if(0 != chmod(argv[1], m))
	{
		printf("Unable to change permissions\n");
		exit(EXIT_FAILURE);
	}

	exit(EXIT_SUCCESS);
}
