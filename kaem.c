#include <stdlib.h>
#include <stdio.h>
#include <unistd.h>

char** tokens;
int command_done;
int FINISHED;

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
			FINISHED = 1;
			return NULL;
		}
		if((' ' == c) || ('\t' == c))
		{
			c = 0;
		}
		if('\n' == c)
		{
			c = 0;
			command_done = 1;
		}
		token[i] = c;
		i = i + 1;
	} while (0 != c);
	return token;
}

void execute_command(FILE* script)
{
	tokens = calloc(1024, sizeof(char*));
	int i = 0;
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

	int f = fork();
	if (f == -1)
	{
		fprintf(stderr,"fork() failure");
		exit(EXIT_FAILURE);
	}
	else if (f == 0)
	{ // child
		execve(tokens[0], tokens, NULL);
		exit(EXIT_SUCCESS);
	}
	// Otherwise we are the parent and need to go again
}

int main()
{
	FILE* script = fopen("kaem.run", "r");
	FINISHED = 0;
	do
	{
		execute_command(script);
	} while(0 == FINISHED);
	fclose(script);
	return EXIT_SUCCESS;
}
