/* Copyright (C) 2016 Jeremiah Orians
 * This file is part of mescc-tools.
 *
 * mescc-tools is free software: you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation, either version 3 of the License, or
 * (at your option) any later version.
 *
 * mescc-tools is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License
 * along with mescc-tools.  If not, see <http://www.gnu.org/licenses/>.
 */

#include <stdlib.h>
#include <stdio.h>
#include <unistd.h>
#include <sys/wait.h>

#define FALSE 0
//CONSTANT FALSE 0
#define TRUE 1
//CONSTANT TRUE 1
#define MAX_STRING 4096
//CONSTANT MAX_STRING 4096
#define MAX_ARGS 256
//CONSTANT MAX_ARGS 256

char* numerate_number(int a);
int match(char* a, char* b);
void collect_comment(FILE* input);
void collect_string(FILE* input, char* target);
char* collect_token(FILE* input, char** envp);
char* find_char(char* string, char a);
char* prematch(char* search, char* field);
char* env_lookup(char* token, char** envp);
char* find_executable(char* name, char* PATH);
int check_envar(char* token);
void cd(char* path);
void set(char** tokens);
char* collect_variable(char* input, char** envp, char** argv);
void execute_commands(FILE* script, char** envp, char** argv);

int command_done;
int VERBOSE;
int STRICT;
int envp_length;
int i_input;
int i_token;

/* Function for purging line comments */
void collect_comment(FILE* input)
{
	int c;
	do
	{
		c = fgetc(input);
		if(-1 == c)
		{
			file_print("IMPROPERLY TERMINATED LINE COMMENT!\nABORTING HARD\n", stderr);
			exit(EXIT_FAILURE);
		}
	} while('\n' != c);
}

/* Function for collecting RAW strings and removing the " that goes with them */
void collect_string(FILE* input, char* target)
{
	int c;
	do
	{
		require(MAX_STRING > i_input, "LINE IS TOO LONG\nABORTING HARD\n");
		require(MAX_STRING > i_token, "LINE IS TOO LONG\nABORTING HARD\n");
		c = fgetc(input);
		if(-1 == c)
		{ /* We never should hit EOF while collecting a RAW string */
			file_print("IMPROPERLY TERMINATED RAW string!\nABORTING HARD\n", stderr);
			exit(EXIT_FAILURE);
		}
		else if('"' == c)
		{ /* Made it to the end */
			c = 0;
		}
		target[i_token] = c;
		i_token = i_token + 1;
		i_input = i_input + 1;
	} while(0 != c);
}

/* Function to collect an individual argument or purge a comment */
char* collect_token(FILE* input, char** envp)
{
	char* token = calloc(MAX_STRING, sizeof(char));
	char c;
	i_input = 0;
	i_token = 0;
	do
	{
		c = fgetc(input);
		/* Bounds checking */
		require(MAX_STRING > i_input, "LINE IS TOO LONG\nABORTING HARD\n");
		require(MAX_STRING > i_token, "LINE IS TOO LONG\nABORTING HARD\n");
		if(-1 == c)
		{ /* Deal with end of file */
			file_print("execution complete\n", stderr);
			exit(EXIT_SUCCESS);
		}
		else if((' ' == c) || ('\t' == c))
		{ /* space and tab are token seperators */
			c = 0;
		}
		else if('\n' == c)
		{ /* Command terminates at end of line */
			c = 0;
			command_done = 1;
		}
		else if('"' == c)
		{ /* RAW strings are everything between a pair of "" */
			collect_string(input, token);
			c = 0;
		}
		else if('#' == c)
		{ /* Line comments to aid the humans */
			collect_comment(input);
			c = 0;
			command_done = 1;
		}
		else if('\\' == c)
		{ /* Support for end of line escapes, drops the char after */
			fgetc(input);
			c = 0;
		}
		token[i_token] = c;
		i_token = i_token + 1;
		i_input = i_input + 1;
	} while (0 != c);

	if(1 >= i_input)
	{ /* Nothing worth returning */
		free(token);
		return NULL;
	}
	return token;
}

char* find_char(char* string, char a)
{
	if(0 == string[0]) return NULL;
	while(a != string[0])
	{
		string = string + 1;
		if(0 == string[0]) return string;
	}
	return string;
}

char* prematch(char* search, char* field)
{
	do
	{
		if(search[0] != field[0]) return NULL;
		search = search + 1;
		field = field + 1;
	} while(0 != search[0]);
	return field;
}

int array_length(char** array)
{
	int length = 0;
	while(array[length] != NULL)
	{
		length = length + 1;
	}
	return length;
}

char* env_lookup(char* token, char** envp)
{
	if(NULL == envp) return NULL;
	int i = 0;
	char* ret = NULL;
	do
	{
		ret = prematch(token, envp[i]);
		if(NULL != ret) return ret;
		i = i + 1;
	} while(0 != envp[i]);
	return NULL;
}

char* find_executable(char* name, char* PATH)
{
	if(('.' == name[0]) || ('/' == name[0]))
	{ /* assume names that start with . or / are relative or absolute */
		return name;
	}

	char* next = find_char(PATH, ':');
	char* trial = calloc(MAX_STRING, sizeof(char));
	FILE* t;
	while(NULL != next)
	{
		next[0] = 0;
		trial = prepend_string(PATH, prepend_string("/", name));

		t = fopen(trial, "r");
		if(NULL != t)
		{
			fclose(t);
			return trial;
		}
		PATH = next + 1;
		next = find_char(PATH, ':');
		free(trial);
	}
	return NULL;
}

/* Function to check if the token is an envar */ 
int check_envar(char* token)
{
	int j;
	int equal_found;
	equal_found = 0;
	for(j = 0; j < string_length(token); j = j + 1)
	{
		if(token[j] == '=')
		{ /* After = can be anything */
			equal_found = 1;
			break;
		}
		else
		{ /* Should be A-z */
			int found;
			found = 0;
			char c;
			/* Represented numerically; 0 = 48 through 9 = 57 */
			for(c = 48; c <= 57; c = c + 1)
			{
				if(token[j] == c)
				{
					found = 1;
				}
			}
			/* Represented numerically; A = 65 through z = 122 */
			for(c = 65; c <= 122; c = c + 1)
			{
				if(token[j] == c)
				{
					found = 1;
				}
			}
			if(found == 0)
			{ /* In all likelihood this isn't actually an environment variable */
				return 1;
			}
		}
	}
	if(equal_found == 0)
	{ /* Not an envar */
		return 1;
	}
	return 0;
}

/* cd builtin */
void cd(char* path)
{
	require(NULL != path, "INVALID CD PATH\nABORTING HARD\n");
	chdir(path);
}

/* pwd builtin */
char* pwd()
{
	file_print(get_current_dir_name(), stdout);
	file_print("\n", stdout);
}

/* set builtin */
void set(char** tokens)
{
	/* Get the options */
	char* raw = calloc(MAX_STRING, sizeof(char));
	copy_string(raw, tokens[1]);
	char* options = calloc(MAX_STRING, sizeof(char));
	int i;
	for(i = 0; i < string_length(raw) - 1; i = i + 1)
	{
		options[i] = raw[i + 1];
	}
	/* Parse the options */
	for(i = 0; i < string_length(options); i = i + 1)
	{
		if(options[i] == 'a')
		{ /* set -a is on by default and cannot be disabled at this time */
			continue;
		}
		else if(options[i] == 'e')
		{ /* Fail on failure */
			STRICT = TRUE;
		}
		else if(options[i] == 'v')
		{ /* Same as -x currently */
			options[i] == 'x';
			continue;
		}
		else if(options[i] == 'x')
		{ /* Show commands as executed */
			/* TODO: this currently behaves like -v. Make it do what it should */
			VERBOSE = TRUE;
			file_print(" +> set -x\n", stdout);
		}
		else
		{
			char* erroneous_option = calloc(2, sizeof(char));
			erroneous_option[0] = options[i];
			file_print(erroneous_option, stderr);
			file_print(" is an invalid set option!\n", stderr);
			exit(EXIT_FAILURE);
		}
	}
}

/* echo builtin */
void echo(char** tokens)
{
	int i;
	for(i = 1; i < array_length(tokens); i = i + 1)
	{
		file_print(tokens[i], stdout);
		file_print(" ", stdout);
	}
	file_print("\n", stdout);
}

int execute(char** tokens, char** envp, char* PATH)
{
	int status;
	char* program = find_executable(tokens[0], PATH);
	if(NULL == program)
	{
		file_print(tokens[0], stderr);
		file_print("\nfailed to execute\n", stderr);
		exit(EXIT_FAILURE);
	}

	int f = fork();
	if (f == -1)
	{
		file_print("fork() failure", stderr);
		exit(EXIT_FAILURE);
	}
	else if (f == 0)
	{ /* child */
		/* execve() returns only on error */
		execve(program, tokens, envp);
		/* Prevent infinite loops */
		_exit(EXIT_SUCCESS);
	}

	/* Otherwise we are the parent */
	/* And we should wait for it to complete */
	waitpid(f, &status, 0);

	return status;
}

char* variable_substitute(char* input, char** envp)
{
	char* output = calloc(MAX_STRING, sizeof(char));
	char* var_name = calloc(MAX_STRING, sizeof(char));
	int eval_var = 0;
	int i = 2;
	while(i < string_length(input))
	{
		char c = input[i];
		require(MAX_STRING > i_input, "LINE IS TOO LONG\nABORTING HARD\n");
		require(MAX_STRING > i_token, "LINE IS TOO LONG\nABORTING HARD\n");
		if(-1 == c)
		{ /* We never should hit EOF while collecting a variable */
			file_print("IMPROPERLY TERMINATED VARIABLE!\nABORTING HARD\n", stderr);
			exit(EXIT_FAILURE);
		}
		else if('\n' == c)
		{ /* Why are we hitting a EOL */
			file_print("IMPROPERLY TERMINATED VARIABLE!\nABORTING HARD\n", stderr);
			exit(EXIT_FAILURE);
		}
		else if('\\' == c)
		{ /* Drop the char after */
			i = i + 2;
		}
		else if(':' == c)
		{ /* Special stuff */
			i = i + 1;
			c = input[i];
			if('-' == c)
			{ /* ${var1-$var2} if var1 is unset substitute var2 */
				var_name = postpend_char(var_name, '=');
				if(env_lookup(var_name, envp) == NULL)
				{ /* var1 is unset */
					memset(var_name, 0, MAX_STRING);
					var_name = ""; /* Reset and get the rest */
					eval_var = 1;
				}
				else
				{
					/* We've collected everything */
					break;
				}
				i = i + 1;
			}
			else
			{
				var_name = postpend_char(var_name, input[i - 1]);
			}
		}
		else if('}' == c)
		{ /* End of variable name */
			if(eval_var == 0)
			{
				var_name = postpend_char(var_name, '=');
			}
			break;
		}
		else
		{
			var_name = postpend_char(var_name, c);
			i = i + 1;
		}
	}

	/* Substitute the variable */
	if(eval_var == 0)
	{
		output = env_lookup(var_name, envp);
		if(output == NULL)
		{
			output = "";
		}
	}
	else
	{
		copy_string(output, var_name);
	}

	return output;
}

/* Function to concatanate all variables */
char* variable_all(char* input, char** argv)
{
	char* output = calloc(MAX_STRING, sizeof(char));
	int i;
	int length = array_length(argv);
	for(i = 0; i < length; i = i + 1)
	{
		output = prepend_string(output, argv[i]);
		output = prepend_string(output, " ");
	}
	return output;
}


/* Function to substitute variables */
char* collect_variable(char* input, char** envp, char** argv)
{
	if(input[0] != '$')
	{
		char* output = calloc(MAX_STRING, sizeof(char));
		copy_string(output, input);
		return output;
	}

	if(input[1] == '{')
	{
		return variable_substitute(input, envp);
	}
	else if(input[1] == '@')
	{
		return variable_all(input, argv);
	}
	else
	{
		file_print("IMPROPERLY USED VARIABLE!\nABORTING HARD\n", stderr);
		exit(EXIT_FAILURE);
	}

	/* Get the name of the variable */
}

/* Function for executing our programs with desired arguments */
void execute_commands(FILE* script, char** envp, char** argv)
{
	while(1)
	{
		char** tokens = calloc(MAX_ARGS, sizeof(char*));

		char* PATH = env_lookup("PATH=", envp);
		if(NULL != PATH)
		{
			PATH = calloc(MAX_STRING, sizeof(char));
			copy_string(PATH, env_lookup("PATH=", envp));
		}

		char* USERNAME = env_lookup("LOGNAME=", envp);
		if((NULL == PATH) && (NULL == USERNAME))
		{
			PATH = calloc(MAX_STRING, sizeof(char));
			copy_string(PATH, "/root/bin:/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin");
		}
		else if(NULL == PATH)
		{
			PATH = prepend_string("/home/", prepend_string(USERNAME,"/bin:/usr/local/bin:/usr/bin:/bin:/usr/local/games:/usr/games"));
		}

		int i = 0;
		command_done = 0;
		do
		{
			char* result = calloc(MAX_STRING, sizeof(char));
			result = collect_token(script, envp);
			if(NULL != result)
			{ /* Not a comment string but an actual argument */
				if(i >= MAX_ARGS)
				{ /* Prevent segfaults */
					file_print("Script too long\n", stderr);
					exit(EXIT_FAILURE);
				}
				tokens[i] = result;
				i = i + 1;
			}
		} while(0 == command_done);

		if(VERBOSE && (0 < i))
		{
			file_print(" +> ", stdout);
			int j;
			for(j = 0; j < i; j = j + 1)
			{
				file_print(tokens[j], stdout);
				fputc(' ', stdout);
			}
			file_print("\n", stdout);
		}

		int j = 0;
		while(tokens[j] != NULL)
		{
			char* output = calloc(MAX_STRING, sizeof(char));
			output = collect_variable(tokens[j], envp, argv);
			int h;
			memset(tokens[j], 0, MAX_STRING);
			copy_string(tokens[j], output);
			j = j + 1;
		}

		if(0 < i)
		{ /* Not a line comment */
			/* Find what it is */
			int skip = 0;
			if(check_envar(tokens[0]) == 0)
			{ /* It's an envar! */
				if(string_length(tokens[0]) > MAX_STRING)
				{ /* String is too long; prevent buffer overflow */
					file_print(tokens[0], stderr);
					file_print("\nis too long to fit in envp\n", stderr);
				}
				envp[envp_length] = tokens[0]; /* Since arrays are 0 indexed */
				envp_length = envp_length + 1;
			}
			else if(match(tokens[0], "cd"))
			{ /* cd builtin */
				cd(tokens[1]);
			}
			else if(match(tokens[0], "pwd"))
			{ /* pwd builtin */
				pwd();
			}
			else if(match(tokens[0], "set"))
			{ /* set builtin */
				set(tokens);
			}
			else if(match(tokens[0], "echo"))
			{ /* echo builtin */
				echo(tokens);
			}
			else if(match(tokens[0], ""))
			{ /* Well, that's weird, but can happen, and leads to segfaults in exec */
				skip = 1;
			}
			else if(skip == 0)
			{ /* Stuff to exec */
				int status = execute(tokens, envp, PATH);
				if(STRICT && (0 != status))
				{ /* Clearly the script hit an issue that should never have happened */
					file_print("Subprocess error ", stderr);
					file_print(numerate_number(status), stderr);
					file_print("\nABORTING HARD\n", stderr);
					/* stop to prevent damage */
					exit(EXIT_FAILURE);
				}
			}
		}
		/* Does nothing in M2-Planet but otherwise GCC-compiled kaem segfaults */
		free(tokens);
		/* Then go again */
	}
}


int main(int argc, char** argv, char** envp)
{
	VERBOSE = FALSE;
	STRICT = FALSE;
	char* filename = "kaem.run";
	FILE* script = NULL;

	/* Get envp_length */
	envp_length = 1;
	while(envp[envp_length] != NULL)
	{
		envp_length = envp_length + 1;
	}
	char** nenvp = calloc(envp_length + MAX_ARGS, sizeof(char*));
	int i;
	for(i = 0; i < envp_length; i = i + 1)
	{
		nenvp[i] = envp[i];
	}

	for(i = envp_length; i < (envp_length + MAX_ARGS); i = i + 1)
	{
		nenvp[i] = 0;
	}

	i = 1;
	while(i <= argc)
	{
		if(NULL == argv[i])
		{
			i = i + 1;
		}
		else if(match(argv[i], "-h") || match(argv[i], "--help"))
		{
			file_print("kaem only accepts --help, --version, --file, --verbose, --nightmare-mode or no arguments\n", stdout);
			exit(EXIT_SUCCESS);
		}
		else if(match(argv[i], "-f") || match(argv[i], "--file"))
		{
			filename = argv[i + 1];
			i = i + 2;
		}
		else if(match(argv[i], "n") || match(argv[i], "--nightmare-mode"))
		{
			file_print("Begin nightmare", stdout);
			envp = NULL;
			i = i + 1;
		}
		else if(match(argv[i], "-V") || match(argv[i], "--version"))
		{
			file_print("kaem version 0.7.0\n", stdout);
			exit(EXIT_SUCCESS);
		}
		else if(match(argv[i], "--verbose"))
		{
			VERBOSE = TRUE;
			i = i + 1;
		}
		else if(match(argv[i], "--strict"))
		{
			STRICT = TRUE;
			i = i + 1;
		}
		else
		{
			file_print("UNKNOWN ARGUMENT\n", stdout);
			exit(EXIT_FAILURE);
		}
	}

	script = fopen(filename, "r");

	if(NULL == script)
	{
		file_print("The file: ", stderr);
		file_print(filename, stderr);
		file_print(" can not be opened!\n", stderr);
		exit(EXIT_FAILURE);
	}

	execute_commands(script, nenvp, argv);
	fclose(script);
	return EXIT_SUCCESS;
}
