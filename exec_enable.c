#include <stdio.h>
#include <stdlib.h>
#include <unistd.h>
#include <sys/stat.h>

int main(int argc, char *argv[])
{
	/************************************************
	 * Note that the leading 0 makes it Octal       *
	 * not base 10 or base 16.                      *
	 * hex numbers begin with 0x                    *
	 * 777 indicates that we want read, write and   *
	 * execute permissions applied to the file      *
	 * For the owner, group and all users           *
	 ************************************************/
	int m = 0755;

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
