/* Copyright (C) 2016 Jeremiah Orians
 * This file is part of stage0.
 *
 * stage0 is free software: you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation, either version 3 of the License, or
 * (at your option) any later version.
 *
 * stage0 is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License
 * along with stage0.  If not, see <http://www.gnu.org/licenses/>.
 */

#include <stdlib.h>
#include <stdio.h>
#include <unistd.h>
#include <sys/wait.h>
#define FALSE 0
#define TRUE 1

char** tokens;
int command_done;
int arguments;
int VERBOSE;

int match(char* a, char* b)
{
	int i = -1;
	do
	{
		i = i + 1;
		if(a[i] != b[i])
		{
			return FALSE;
		}
	} while((0 != a[i]) && (0 !=b[i]));
	return TRUE;
}

void collect_comment(FILE* input)
{
	int c;
	do
	{
		c = fgetc(input);
		if(-1 == c)
		{
			fprintf(stderr, "IMPROPERLY TERMINATED LINE COMMENT!\nABORTING HARD\n");
			exit(EXIT_FAILURE);
		}
	} while('\n' != c);
}

int collect_string(FILE* input, int index, char* target)
{
	int c;
	do
	{
		c = fgetc(input);
		if(-1 == c)
		{
			fprintf(stderr, "IMPROPERLY TERMINATED RAW string!\nABORTING HARD\n");
			exit(EXIT_FAILURE);
		}
		else if('"' == c)
		{
			c = 0;
		}
		target[index] = c;
		index = index + 1;
	} while(0 != c);
	return index;
}

char* collect_token(FILE* input)
{
	char* token = calloc(1024, sizeof(char));
	char c;
	int i = 0;
	do
	{
		c = fgetc(input);
		if(-1 == c)
		{
			fprintf(stderr, "execution complete\n");
			exit(EXIT_SUCCESS);
		}
		else if((' ' == c) || ('\t' == c))
		{
			c = 0;
		}
		else if('\n' == c)
		{
			c = 0;
			command_done = 1;
		}
		else if('"' == c)
		{
			i = collect_string(input, i, token);
			c = 0;
		}
		else if('#' == c)
		{
			arguments = i;
			collect_comment(input);
			command_done = 1;
			return token;
		}
		token[i] = c;
		i = i + 1;
	} while (0 != c);
	arguments = i;
	return token;
}

void execute_command(FILE* script, char** envp)
{
	tokens = calloc(1024, sizeof(char*));
	int i = 0;
	arguments = 0;
	int status = 0;
	command_done = 0;
	do
	{
		char* result = collect_token(script);
		if(0 != result)
		{
			tokens[i] = result;
		}
		i = i + 1;
	} while(0 == command_done);

	if((1 == VERBOSE) && (1 < i))
	{
		fprintf(stdout, " +> ");
		for(int j = 0; j < i; j = j + 1)
		{
			fprintf(stdout, "%s ", tokens[j]);
		}
		fprintf(stdout, "\n");
	}

	if(0 < arguments)
	{ // Not a line comment
		int f = fork();
		if (f == -1)
		{
			fprintf(stderr,"fork() failure");
			exit(EXIT_FAILURE);
		}
		else if (f == 0)
		{ // child
			/* execve() returns only on error */
			execve(tokens[0], tokens, envp);
			/* Prevent infinite loops */
			_exit(EXIT_SUCCESS);
		}
		// Otherwise we are the parent
		// And we should wait for it to complete
		waitpid(f, &status, 0);
		// Then go again
	}
	else
	{
//		fprintf(stderr, "Recieved and dropped line comment\n");
	}
}

int main(int argc, char** argv, char** envp)
{
	VERBOSE = 0;
	if((argc == 2) && match(argv[1], "--version"))
	{
		fprintf(stdout, "kaem version 0.1\n");
		exit(EXIT_SUCCESS);
	}
	else if((argc == 2) && match(argv[1], "--help"))
	{
		fprintf(stdout, "kaem only accepts --help, --version, --verbose or no arguments\n");
		exit(EXIT_SUCCESS);
	}
	else if((argc == 2) && match(argv[1], "--verbose"))
	{
		VERBOSE = 1;
	}
	else if(argc != 1)
	{
		fprintf(stderr, "kaem only accepts --help, --version, --verbose or no arguments\n");
		exit(EXIT_FAILURE);
	}
	FILE* script = fopen("kaem.run", "r");
	while(1)
	{
		execute_command(script, envp);
	}
	fclose(script);
	return EXIT_SUCCESS;
}
