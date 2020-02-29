/* Copyright (C) 2016 Jeremiah Orians
 * Copyright (C) 2020 fosslinux
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

/*
 * INCLUDES
 */

#include <stdlib.h>
#include <stdio.h>
#include <unistd.h>
#include <sys/wait.h>

/*
 * DEFINES
 */

#define FALSE 0
//CONSTANT FALSE 0
#define TRUE 1
//CONSTANT TRUE 1
#define MAX_STRING 4096
//CONSTANT MAX_STRING 4096
#define MAX_ARGS 256
//CONSTANT MAX_ARGS 256

/*
 * FUNCTION PROTOTYPES
 */

/* Utility */
char* find_char(char* string, char a);
char* prematch(char* search, char* field);
int array_length(char** array);
char* env_lookup(char* variable);
char* find_executable(char* name);
char** tokens_to_array();
char** env_to_array();
/* Token */
void collect_comment(FILE* input);
void collect_string(FILE* input);
void collect_token(FILE* input);
/* Variable */
void variable_substitute_ifset(char* input);
void variable_substitute(char* input);
void variable_all(char** argv);
void collect_variable(char** argv);
/* Execute */
int is_envar(char* token);
void add_envar(char* token);
void cd(char* path);
void pwd();
void set();
void echo();
int execute();
void run_script(FILE* script, char** argv);
int main(int argc, char** argv, char** envp);

/*
 * GLOBALS 
 */

int command_done;
int script_done;
int VERBOSE;
int STRICT;
int NIGHTMARE;
int FUZZING;
char* PATH;
char* USERNAME;

/* Token struct */
struct Token {
	char* value;
	int pos;
	int is_comment;
	struct Token* next;
	struct Token* prev;
};
struct Token* token;
struct Token* token_head;
struct Token* token_tail;


/* Environment struct */
struct Environment {
	char* var;
	char* value;
	struct Environment* next;
	struct Environment* prev;
};
struct Environment* env;
struct Environment* env_head;
struct Environment* env_tail;

/*
 * UTILITY FUNCTIONS
 */

/* Function to find a character in a string */
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

/* Function to match for a string */
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

/* Function to find the length of an array */
int array_length(char** array)
{
	int length = 0;
	while(array[length] != NULL)
	{
		length = length + 1;
	}
	return length;
}

/* Search for a variable in the env linked-list */
char* env_lookup(char* variable)
{
	char* ret = calloc(MAX_STRING, sizeof(char));
	/* Start at the head */
	env = env_head;
	do
	{ /* Loop over the linked-list */
		if(match(variable, env->var))
		{ /* We have found the correct node */
			ret = env->value;
			/* Move back to the head */
			env = env_head;
			return ret; /* Done */
		}
		/* Nope, try the next */
		env = env->next;
	} while(env != NULL); /* Until we reach the end of the linked-list */
	/* We didn't find anything! */
	return NULL;
}

/* Find the full path to an executable */
char* find_executable(char* name)
{
	if(('.' == name[0]) || ('/' == name[0]))
	{ /* assume names that start with . or / are relative or absolute */
		return name;
	}

	char* next = find_char(PATH, ':');
	char* trial = calloc(MAX_STRING, sizeof(char));
	char* MPATH = calloc(MAX_STRING, sizeof(char)); /* Modified PATH */
	copy_string(MPATH, PATH);
	FILE* t;
	while(NULL != next)
	{
		next[0] = 0;
		trial = prepend_string(MPATH, prepend_string("/", name));

		require(string_length(trial) < MAX_STRING, "COMMAND TOO LONG!\nABORTING HARD\n");
		t = fopen(trial, "r");
		if(NULL != t)
		{
			fclose(t);
			return trial;
		}
		MPATH = next + 1;
		next = find_char(MPATH, ':');
		free(trial);
	}
	return NULL;
}

/* Function to convert the tokens struct into an array */
char** tokens_to_array()
{
	char** array = calloc(MAX_ARGS, sizeof(char*));
	int i = 0;
	token = token_head;
	do
	{ /* Loop through each node and assign it to an array index */
		/* Bounds checking */
		require(i < MAX_ARGS, "LINE TOO LONG\nABORTING HARD\n");
		array[i] = calloc(MAX_STRING, sizeof(char));
		copy_string(array[i], token->value);
		token = token->next;
		i = i + 1;
	} while(token != NULL);
	token = token_head;
	return array;
}

/* Function to convert the env struct into an array */
char** env_to_array()
{
	char** array = calloc(MAX_ARGS, sizeof(char*));
	int i = 0;
	env = env_head;
	while(env->next != NULL)
	{ /* Loop through each node and assign it to node->value */
		/* Bounds checking */
		require(i < MAX_ARGS, "TOO MANY ARGUMENTS\nABORTING HARD\n");
		array[i] = prepend_string(env->var, prepend_string("=", env->value));
		env = env->next;
		i = i + 1;
	}
	env = env_head;
	return array;
}

/*
 * TOKEN COLLECTION FUNCTIONS
 */

/* Function for purging line comments */
void collect_comment(FILE* input)
{
	char c;
	token->is_comment = TRUE;
	do
	{ /* Sanity check that the comment ends with \n and purge the comment from the FILE* */
		c = fgetc(input);
		if(-1 == c)
		{ /* We reached an EOF!! */
			file_print("IMPROPERLY TERMINATED LINE COMMENT!\nABORTING HARD\n", stderr);
			exit(EXIT_FAILURE);
		}
	} while('\n' != c); /* We can now be sure it ended with \n -- and have purged the comment */
}

/* Function for collecting RAW strings and removing the " that goes with them */
void collect_string(FILE* input)
{
	int string_done = FALSE;
	char c;
	do
	{
		/* Bounds check */
		require(MAX_STRING > token->pos, "LINE IS TOO LONG\nABORTING HARD\n");
		c = fgetc(input);
		if(-1 == c)
		{ /* We never should hit EOF while collecting a RAW string */
			file_print("IMPROPERLY TERMINATED RAW STRING!\nABORTING HARD\n", stderr);
			exit(EXIT_FAILURE);
		}
		else if('"' == c)
		{ /* End of string */
			string_done = TRUE;
		}
		else
		{
			token->value = postpend_char(token->value, c);
			token->pos = token->pos + 1;
		}
	} while(string_done == FALSE);
}

/* Function to parse and assign token->value */
void collect_token(FILE* input)
{
	char c;
	int token_done = FALSE;
	do
	{ /* Loop over each character in the token */
		c = fgetc(input);
		/* Bounds checking */
		require(MAX_STRING > token->pos, "LINE IS TOO LONG\nABORTING HARD\n");
		if(-1 == c)
		{ /* End of file -- this means script complete */
			/* We don't actually exit here. This logically makes more sense;
			 * let the code follow its natural path of execution and exit
			 * sucessfuly at the end of main().
			 * However we set the done marker.
			 */
			script_done = TRUE;
			command_done = TRUE;
			token_done = TRUE;
		}
		else if((' ' == c) || ('\t' == c))
		{ /* Space and tab are token seperators */
			token_done = TRUE;
		}
		else if('\n' == c)
		{ /* Command terminates at end of a line */
			command_done = TRUE;
			token_done = TRUE;
		}
		else if('"' == c)
		{ /* Handle RAW strings -- everything between a pair of "" */
			collect_string(input);
			token_done = TRUE;
		}
		else if('#' == c)
		{ /* Handle line comments */
			collect_comment(input);
			command_done = TRUE;
			token_done = TRUE;
		}
		else if('\\' == c)
		{ /* Support for escapes; drops the char after */
			fgetc(input); /* Skips over \, gets the next char */
		}
		else if(0 == c)
		{ /* We have come to the end of the token */
			token_done = TRUE;
		}
		else
		{ /* It's a character to assign */
			token->value = postpend_char(token->value, c);
			token->pos = token->pos + 1;
		}
	} while (token_done == FALSE);

	/* Initialize the next node */
	if(command_done == FALSE)
	{
		token->next = calloc(1, sizeof(struct Token));
		token->next->prev = token;
		token = token->next;
		/* Check if our efforts yielded nothing */
		/* This might be confusing... it is because the next node initializing happens before
		 * So our data is actually in token->prev
		 */
		if(match(token->prev->value, "") || token->prev->value == NULL)
		{ /* That was useless! */
			/* Let's remove ourselves from the linked-list */
			if(token->prev == token_head)
			{
				/* Literally make a new linked-list */
				token = calloc(1, sizeof(struct Token));
				token->pos = 0;
				token->value = calloc(1, sizeof(struct Token));
				/* Get is_comment from old token */
				token->is_comment = token_head->is_comment;
				token_head = token;
				token_tail = token;
			}
			else if(token->prev == token_tail)
			{
				token_tail = token->prev;
				token = token->prev;
			}
			else
			{
				token = token->prev;
			}
		}
	}
	token_tail = token;
}

/*
 * VARIABLE FUNCTIONS
 */

void variable_substitute_ifset(char* input)
{
	int pos_old = token->pos;

	/* Get the variable name */
	char* var_name = calloc(MAX_STRING, sizeof(char));
	while(input[token->pos] != ':')
	{ /* Copy into var_name until :- */
		var_name = postpend_char(var_name, input[token->pos]);
		token->pos = token->pos + 1;
	}

	/* Get the alternative text */
	char* text = calloc(MAX_STRING, sizeof(char));
	token->pos = token->pos + 2; /* Skip over :- */
	while(input[token->pos] != '}')
	{ /* Copy into text until \} */
		text = postpend_char(text, input[token->pos]);
		token->pos = token->pos + 1;
	}

	/* Do the substitution */
	if(env_lookup(var_name) != NULL)
	{ /* var_name is valid, subsitute it */
		token->value = prepend_string(token->value, env_lookup(var_name));
	}
	else
	{ /* Not valid, subsitute alternative text */
		token->value = prepend_string(token->value, text);
	}
}

void variable_substitute(char* input)
{
	/* NOTE: token->pos is the pos of input */
	/* Initialize stuff */
	char* var_name = calloc(MAX_STRING, sizeof(char));
	token->pos = token->pos + 1; /* We don't want the { */

	/* Check for "special" types 
	 * If we do find a special type we return here.
	 * We don't want to go through the rest of the code for a normal
	 * substitution.
	 */
	int pos_old = token->pos;
	while(token->pos < string_length(input))
	{ /* Loop over each character */
		if(input[token->pos] == ':')
		{ /* Special stuffs! */
			token->pos = token->pos + 1;
			if(input[token->pos] == '-')
			{ /* ${VARNAME:-text} if varname is not set substitute text */
				token->pos = pos_old; /* Reset token->pos */
				variable_substitute_ifset(input);
				return; /* We are done here */
			}
		}
		token->pos = token->pos + 1;
	}
	token->pos = pos_old; /* Reset token->pos */

	/* If we reach here it is a normal substitution
	 * Let's do it!
	 */
	/* Get the variable name */
	int substitute_done = FALSE;
	while(substitute_done == FALSE)
	{
		char c = input[token->pos];
		require(MAX_STRING > token->pos, "LINE IS TOO LONG\nABORTING HARD\n");
		if(-1 == c)
		{ /* We never should hit EOF while collecting a variable */
			file_print("IMPROPERLY TERMINATED VARIABLE!\nABORTING HARD\n", stderr);
			exit(EXIT_FAILURE);
		}
		else if('\n' == c)
		{ /* We should not hit EOL */
			/* This also catches token->pos > string_length(input) */
			file_print("IMPROPERLY TERMINATED VARIABLE!\nABORTING HARD\n", stderr);
			exit(EXIT_FAILURE);
		}
		else if('\\' == c)
		{ /* Drop the \\ */
			token->pos = token->pos + 1;
		}
		else if('}' == c)
		{ /* End of variable name */
			substitute_done = TRUE;
		}
		else
		{
			var_name = postpend_char(var_name, c);
			token->pos = token->pos + 1;
		}
	}

	/* Reset token->pos */
	token->pos = pos_old;

	/* Substitute the variable */
	char* value = calloc(MAX_STRING, sizeof(char));
	value = env_lookup(var_name);
	if(value != NULL)
	{
		/* If there is nothing to substitute, don't substitute anything! */
		token->value = prepend_string(token->value, value);
	}
}

/* Function to concatanate all variables */
void variable_all(char** argv)
{
	int length = array_length(argv);
	int i;
	/* We don't want argv[0], as that contains the path to kaem */
	for(i = 1; i < length; i = i + 1)
	{
		token->value = prepend_string(token->value, argv[i]);
		token->value = prepend_string(token->value, " ");
	}
}

/* Function to substitute variables */
void collect_variable(char** argv)
{
	/* NOTE: token->pos is the position of input */
	token->pos = 0;

	/* Create input */
	char* input = calloc(MAX_STRING, sizeof(char));
	copy_string(input, token->value);
	/* Reset token->value */
	token->value = calloc(MAX_STRING, sizeof(char));

	while(input[token->pos] != '$')
	{ /* Copy over everything up to the $ */
		if(input[token->pos] == 0)
		{ /* No variable in it */
			token->value = input;
			return; /* We don't need to do anything more */
		}
		token->value = postpend_char(token->value, input[token->pos]);
		token->pos = token->pos + 1;
	}
		
	token->pos = token->pos + 1; /* We are uninterested in the $ */

	/* Run the substitution */
	if(input[token->pos] == '{')
	{ /* Handles everything ${ related */
		variable_substitute(input);
		token->pos = token->pos + 1; /* We don't want the closing } */
	}
	else if(input[token->pos] == '@')
	{ /* Handles $@ */
		variable_all(argv);
		token->pos = token->pos + 1; /* We don't want the @ */
	}
	else
	{ /* We don't know that */
		file_print("IMPROPERLY USED VARIABLE!\nABORTING HARD\n", stderr);
		exit(EXIT_FAILURE);
	}

	/* Now, get the rest */
	while(input[token->pos] != 0)
	{ /* Copy everything from the end of the variable to the end of the token */
		postpend_char(token->value, input[token->pos]);
		token->pos = token->pos + 1;
	}
}

/*
 * EXECUTION FUNCTIONS
 */

/* Function to check if the token is an envar */ 
int is_envar(char* token)
{
	int i = 0;
	int equal_found;
	equal_found = FALSE;
	while(equal_found == FALSE && i < string_length(token))
	{
		if(token[i] == '=')
		{ /* After = can be anything */
			equal_found = 1;
		}
		i = i + 1;
	}
	return equal_found;
}

/* Add an envar */
void add_envar(char* token)
{
	/* Initialize new node */
	env = env_tail;
	env->next = calloc(1, sizeof(struct Token));
	env->next->prev = env;
	env = env->next;
	env_tail = env;

	/* Get env->var */
	int i = 0;
	env->var = calloc(MAX_STRING, sizeof(char));
	while(token[i] != '=')
	{ /* Copy into env->var up to = */
		require(i < string_length(token), "ERROR IN ENVAR PARSING!\nABORTING HARD\n");
		env->var = postpend_char(env->var, token[i]);
		i = i + 1;
	}

	/* Get env->value */
	i = i + 1; /* Skip over = */
	env->value = calloc(MAX_STRING, sizeof(char));
	while(token[i] != 0)
	{ /* Copy into env->value up to end of token */
		require(i < string_length(token), "ERROR IN ENVAR PARSING!\nABORTING HARD\n");
		env->value = postpend_char(env->value, token[i]);
		i = i + 1;
	}
}

/* cd builtin */
void cd(char* path)
{
	require(NULL != path, "INVALID CD PATH\nABORTING HARD\n");
	chdir(path);
}

/* pwd builtin */
void pwd()
{
	char* path = calloc(MAX_STRING, sizeof(char));
	getcwd(path, MAX_STRING);
	file_print(path, stdout);
	file_print("\n", stdout);
}

/* set builtin */
void set()
{
	/* Get the options */
	char* options = calloc(MAX_STRING, sizeof(char));
	int i;
	/* We have to do two things here because of differing behaviour in
	 * M2-Planet -- it does not short-circuit the OR.
	 * M2-Planet will evaluate both expressions before performing the OR.
	 * Hence, this would cause a segfault if the first evaluated false,
	 * since the second will still evaluate.
	 * To mitigate this, we have two seperate if blocks to force the 
	 * evaluation of one before the other.
	 */
	if(token->next == NULL) 
	{
		file_print("INVALID set COMMAND\nABORTING HARD\n", stderr);
		exit(EXIT_FAILURE);
	}
	if(token->next->value == NULL)
	{
		file_print("INVALID set COMMAND\nABORTING HARD\n", stderr);
		exit(EXIT_FAILURE);
	}
	for(i = 0; i < string_length(token->next->value) - 1; i = i + 1)
	{
		options[i] = token->next->value[i + 1];
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
		else if(options[i] == 'x')
		{ /* Show commands as executed */
			/* TODO: this currently behaves like -v. Make it do what it should */
			VERBOSE = TRUE;
			/* Output the set -x because VERBOSE didn't catch it before */
			file_print(" +> set -", stdout);
			file_print(options, stdout);
			file_print("\n", stdout);
		}
		else
		{ /* Invalid */
			fputc(options[i], stderr);
			file_print(" is an invalid set option!\n", stderr);
			exit(EXIT_FAILURE);
		}
	}
}

/* echo builtin */
void echo()
{
	if(token->next == NULL || token->next->value == NULL)
	{ /* No arguments */
		file_print("\n", stdout);
		return;
	}
	token = token->next; /* Skip the actual echo */
	do
	{ /* Output each argument to echo to stdout */
		file_print(token->value, stdout);
		file_print(" ", stdout);
		token = token->next;
	} while(token != NULL);
	file_print("\n", stdout);
}

/* Execute program */
int execute()
{
	int status; /* i.e. return code */
	/* Get the full path to the program */
	char* program = find_executable(token->value);
	if(NULL == program)
	{ /* Sanity check */
		if(STRICT == TRUE)
		{
			file_print("WHILE EXECUTING ", stderr);
			file_print(token->value, stderr);
			file_print(" NOT FOUND!\nABORTING HARD\n", stderr);
			exit(EXIT_FAILURE);
		}
		else
		{
			return 0;
		}
	}

	int f = fork();
	if (f == -1)
	{ /* Another sanity check */
		file_print("WHILE EXECUTING ", stderr);
		file_print(token->value, stderr);
		file_print("fork() FAILED\nABORTING HARD\n", stderr);
		exit(EXIT_FAILURE);
	}
	else if (f == 0)
	{ /* Child */
		if(FUZZING == TRUE)
		{
			/* We are fuzzing.
			 * Fuzzing produces random stuff; we don't want it running
			 * dangerous commands. So we just don't execve.
			 * But, we still do tokens_to_array and env_to_array to check
			 * for segfaults.
			 */
			tokens_to_array();
			env_to_array();
		}
		else
		{ /* We are not fuzzing */
			/* execve() returns only on error */
			execve(program, tokens_to_array(), env_to_array());
		}
		/* Prevent infinite loops */
		_exit(EXIT_SUCCESS);
	}

	/* Otherwise we are the parent */
	/* And we should wait for it to complete */
	waitpid(f, &status, 0);

	return status;
}

/* Function for executing our programs with desired arguments */
void run_script(FILE* script, char** argv)
{
	command_done = FALSE;
	script_done = FALSE;
	while(script_done == FALSE)
	{
		/* Initialize token 
		 * ----------------
		 * This has to be reset each time, as we need a new linked-list for
		 * each line.
		 * See, the program flows like this as a high level overview:
		 * Get line -> Sanitize line and perform variable replacement etc ->
		 * Execute line -> Next.
		 * We don't need the previous lines once they are done with, so tokens
		 * are hence for each line.
		 */
		token = calloc(1, sizeof(struct Token));
		token_head = token;
		token_tail = token;

		/* Get the tokens */
		command_done = 0;
		do
		{
			token->pos = 0;
			token->is_comment = FALSE;
			token->value = calloc(MAX_STRING, sizeof(char));
			/* This does token advancing and everything */
			collect_token(script);
		} while(command_done == FALSE);
		/* Once we are done, we should remove anything dangling off the end of the
		 * list -- or the beginning.
		 */
		token_tail->next = NULL;
		token_head->prev = NULL;
		token = token_head;
		/* Edge case */
		if(match(token_head->value, "") || token_head->value == NULL)
		{
			continue;
		}
		/* Output the command if verbose is set */
		if(VERBOSE)
		{
			file_print(" +> ", stdout);
			/* Navigate to head */
			token = token_head;
			do
			{ /* Print out each token token */
				file_print(token->value, stdout);
				file_print(" ", stdout);
				token = token->next;
			} while(token != NULL);
			file_print("\n", stdout);
			token = token_head;
		}

		/* Run the command */
		token = token_head;
		do
		{ /* Substitute variables into each token */
			collect_variable(argv);
			/* Advance to next node */
			token = token->next;
		} while(token != NULL);

		token = token_head;
		/* Actually do the execution */
		if(token->is_comment == TRUE)
		{ 
			/* Do nothing */ 
		}
		else if(is_envar(token->value) == 1)
		{ /* It's an envar! */
			add_envar(token->value);
		}
		else if(match(token->value, "cd"))
		{ /* cd builtin */
			/* We have to do two things here because of differing behaviour in
			 * M2-Planet -- a lack of optomizaitons, AFAICT.
			 * M2-Planet will evaluate both expressions before performing the OR.
			 * Hence, this would cause a segfault if the first evaluated false,
			 * since the second will still evaluate.
			 * To mitigate this, we have two seperate if blocks to force the 
			 * evaluation of one before the other.
			 */
			if(token->next == NULL) 
			{
				file_print("INVALID set COMMAND\nABORTING HARD\n", stderr);
				exit(EXIT_FAILURE);
			}
			if(token->next->value == NULL)
			{
				file_print("INVALID set COMMAND\nABORTING HARD\n", stderr);
				exit(EXIT_FAILURE);
			}
			cd(token->next->value);
		}
		else if(match(token->value, "set"))
		{ /* set builtin */
			set();
		}
		else if(match(token->value, "pwd"))
		{ /* pwd builtin */
			pwd();
		}
		else if(match(token->value, "echo"))
		{ /* echo builtin */
			echo();
		}
		else
		{ /* Stuff to exec */
			int status = execute();
			if(STRICT == TRUE && (0 != status))
			{ /* Clearly the script hit an issue that should never have happened */
				file_print("Subprocess error ", stderr);
				file_print(numerate_number(status), stderr);
				file_print("\nABORTING HARD\n", stderr);
				/* Exit, we failed */
				exit(EXIT_FAILURE);
			}
		}
		/* Next line! 
		 * This restarts the loop and goes to the next line...
		 * assuming that we haven't finished :)
		 */
	}
}


int main(int argc, char** argv, char** envp)
{
	VERBOSE = FALSE;
	STRICT = FALSE;
	char* filename = "kaem.run";
	FILE* script = NULL;

	/* Initalize structs */
	token = calloc(1, sizeof(struct Token));
	require(token != NULL, "Memory initialization of token failed\n");
	token_head = token;
	token_tail = token;

	env = calloc(1, sizeof(struct Environment));
	require(token != NULL, "Memory initialization of env failed\n");
	env_head = env;
	env_tail = env;

	int i = 1;
	/* Loop over arguments */
	while(i <= argc)
	{
		if(NULL == argv[i])
		{ /* Ignore the argument */
			i = i + 1;
		}
		else if(match(argv[i], "-h") || match(argv[i], "--help"))
		{ /* Help information */
			file_print("kaem only accepts --help, --version, --file, --verbose, --nightmare-mode, --fuzz or no arguments\n", stdout);
			exit(EXIT_SUCCESS);
		}
		else if(match(argv[i], "-f") || match(argv[i], "--file"))
		{ /* Set the filename */
			if(argv[i + 1] != NULL)
			{
				filename = argv[i + 1];
			}
			i = i + 2;
		}
		else if(match(argv[i], "n") || match(argv[i], "--nightmare-mode"))
		{ /* Nightmare mode does not populate env */
			file_print("Begin nightmare\n", stdout);
			NIGHTMARE = TRUE;
			i = i + 1;
		}
		else if(match(argv[i], "-V") || match(argv[i], "--version"))
		{ /* Output version */
			file_print("kaem version 0.7.0\n", stdout);
			exit(EXIT_SUCCESS);
		}
		else if(match(argv[i], "--verbose"))
		{ /* Set verbose */
			VERBOSE = TRUE;
			i = i + 1;
		}
		else if(match(argv[i], "--strict"))
		{ /* Set strict */
			STRICT = TRUE;
			i = i + 1;
		}
		else if(match(argv[i], "--fuzz"))
		{ /* Set fuzzing */
			FUZZING = TRUE;
			i = i + 1;
		}
		else
		{ /* We don't know this argument */
			file_print("UNKNOWN ARGUMENT\n", stdout);
			exit(EXIT_FAILURE);
		}
	}

	/* Populate env */
	for(i = 0; i < array_length(envp); i = i + 1)
	{
		env->var = calloc(MAX_STRING, sizeof(char));
		env->value = calloc(MAX_STRING, sizeof(char));
		int j = 0;
		/* Gosh darn.
		 * envp is /weird/.
		 * Super strange stuff when referenceing envp[i].
		 * So just copy envp[i] to envp_line, and work with that.
		 */
		char* envp_line = calloc(MAX_STRING, sizeof(char));
		copy_string(envp_line, envp[i]);
		while(envp_line[j] != '=')
		{ /* Copy over everything up to = to var */
			env->var[j] = envp_line[j];
			j = j + 1;
		}
		j = j + 1; /* Skip over = */
		int k = 0; /* As envp[i] will continue as j but env->value begins at 0 */
		while(envp_line[j] != 0)
		{ /* Copy everything else to value */
			env->value[k] = envp_line[j];
			j = j + 1;
			k = k + 1;
		}
		/* Advance to next part of linked list */
		env->next = calloc(1, sizeof(struct Environment));
		require(token != NULL, "Memory initialization of env->next failed\n");
		env->next->prev = env;
		env = env->next;
		env_tail = env;
	}
	/* If we are here we have an unneeded node on the end */
	env_tail = env->prev;
	env = env->prev;
	env->next = NULL;
	/* And get rid of anything dangling before head */
	env_head->prev = NULL;
	/* Move back to head of env linked-list */
	env = env_head;

	/* Populate PATH variable
	 * We don't need to calloc() because env_lookup() does this for us.
	 */
	PATH = env_lookup("PATH");

	/* Populate USERNMAE variable */
	USERNAME = env_lookup("LOGNAME");

	/* Handle edge cases */
	if((NULL == PATH) && (NULL == USERNAME))
	{ /* We didn't find either of PATH or USERNAME -- use a generic PATH */
		PATH = calloc(MAX_STRING, sizeof(char));
		copy_string(PATH, "/root/bin:/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin");
	}
	else if(NULL == PATH)
	{ /* We did find a username but not a PATH -- use a generic PATH but with /home/USERNAME */
		PATH = prepend_string("/home/", prepend_string(USERNAME,"/bin:/usr/local/bin:/usr/bin:/bin:/usr/local/games:/usr/games"));
	}

	/* Open the script */
	script = fopen(filename, "r");
	if(NULL == script)
	{
		file_print("The file: ", stderr);
		file_print(filename, stderr);
		file_print(" can not be opened!\n", stderr);
		exit(EXIT_FAILURE);
	}

	/* Run the commands */
	run_script(script, argv);

	/* Cleanup */
	fclose(script);
	return EXIT_SUCCESS;
}
