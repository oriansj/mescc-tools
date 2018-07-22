#include <stdio.h>
#include <stdlib.h>
#include <unistd.h>
#include <sys/stat.h>
void file_print(char* s, FILE* f);

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
		file_print("arg count\n", stderr);
		exit(EXIT_FAILURE);
	}

	if(0 != chmod(argv[1], m))
	{
		file_print("Unable to change permissions\n", stderr);
		exit(EXIT_FAILURE);
	}

	exit(EXIT_SUCCESS);
}
