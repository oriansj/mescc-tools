/* Copyright (C) 2020 fosslinux
 * This file is part of mescc-tools
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

#include <stdio.h>
#include <stdlib.h>
#include <unistd.h>
#include <fcntl.h>

/* Define all of the constants */
// CONSTANT FALSE 0
#define FALSE 0
// CONSTANT TRUE 1
#define TRUE 1
// CONSTANT MAX_STRING 4096
#define MAX_STRING 4096

/* Prototypes for external funcs */
int match(char* a, char* b);
void file_print(char* s, FILE* f);
char* copy_string(char* target, char* source);
char* prepend_string(char* add, char* base);
void require(int bool, char* error);
char* postpend_char(char* s, char a);
int string_length(char* a);

/* Globals */
int verbose;

/* UTILITY FUNCTIONS */

/* Function to find a character's position in a string (last match) */
int find_last_char_pos(char* string, char a)
{
	int i = string_length(string) - 1;
	if(i < 0) return i;
	while(i >= 0)
	{
		/* 
		 * This conditional should be in the while conditional but we are
		 * running into the M2-Planet short-circuit bug.
		 */
		if(a == string[i]) break;
		i = i - 1;
	}
	return i;
}

/* PROCESSING FUNCTIONS */

char* directory_dest(char* dest, char* source)
{
	/*
	 * First, check if it is a directory to copy to.
	 * We have two ways of knowing this:
	 * - If the destination ends in a slash, the user has explicitly said
	 *   it is a directory.
	 * - Normally we would use stat() but we don't want to force support for
	 *   that syscall onto the kernel, so we just attempt to chdir() into it
	 *   and if it works then it must be a directory. A bit hacky, bit it
	 *   works.
	 */
	int isdirectory = FALSE;
	if(dest[string_length(dest) - 1] == '/')
	{
		isdirectory = TRUE;
	}
	if(!isdirectory)
	{ /* Use the other testing method */
		/*
		 * Get the current path so that we can chdir back to it if it does
		 * chdir successfully.
		 */
		char* current_path = calloc(MAX_STRING, sizeof(char));
		require(current_path != NULL, "Memory initialization of current_path in directory_dest failed\n");
		getcwd(current_path, MAX_STRING);
		require(!match("", current_path), "getcwd() failed\n");
		/*
		 * chdir expects an absolute path.
		 * If the first character is / then it is already absolute, otherwise
		 * it is relative and needs to be changed (by appending current_path
		 * to the dest path).
		 */
		char* chdir_dest = calloc(MAX_STRING, sizeof(char));
		if(dest[0] != '/')
		{ /* The path is relative, append current_path */
			copy_string(chdir_dest, prepend_string(prepend_string(current_path, "/"), dest));
		}
		else
		{ /* The path is absolute */
			copy_string(chdir_dest, dest);
		}
		if(0 <= chdir(chdir_dest))
		{ /* chdir returned successfully */
			/* 
			 * But because of M2-Planet, that dosen't mean anything actually
			 * happened, check that before we go any further.
			 */
			char* new_path = calloc(MAX_STRING, sizeof(char));
			require(new_path != NULL, "Memory initialization of new_path in directory_dest failed\n");
			getcwd(new_path, MAX_STRING);
			if(!match(current_path, new_path))
			{
				isdirectory = TRUE;
				chdir(current_path);
			}
		}
		free(chdir_dest);
		free(current_path);
	}

	/* If it isn't a directory, our work here is done. */
	if(!isdirectory) return dest;

	/* If it is, we need to make dest a full path. */
	/* 1. Get the basename of source. */
	char* basename = calloc(MAX_STRING, sizeof(char));
	require(basename != NULL, "Memory initialization of basename in directory_dest failed\n");
	int last_slash_pos = find_last_char_pos(source, '/');
	if(last_slash_pos >= 0)
	{ /* Yes, there is a slash in it, copy over everything after that pos */
		int spos; /* source pos */
		int bpos = 0; /* basename pos */
		int source_length = string_length(source);
		/* Do the actual copy */
		for(spos = last_slash_pos + 1; spos < string_length(source); spos = spos + 1)
		{
			basename[bpos] = source[spos];
			bpos = bpos + 1;
		}
	}
	else
	{ /* No, there is no slash in it, hence the basename is just the source */
		copy_string(basename, source);
	}
	/* 2. Ensure our dest (which is a directory) has a trailing slash. */
	if(dest[string_length(dest) - 1] != '/')
	{
		dest = postpend_char(dest, '/');
	}
	/* 3. Add the basename to the end of the directory. */
	dest = prepend_string(dest, basename);
	free(basename);

	/* Now we have a returnable path! */
	return dest;
}

int copy_file(char* source, char* dest)
{
	if(verbose)
	{ /* Output message */
		/* Of the form 'source' -> 'dest' */
		file_print("'", stdout);
		file_print(source, stdout);
		file_print("' -> '", stdout);
		file_print(dest, stdout);
		file_print("'\n", stdout);
	}

	/* Open source and dest as FILE*s */
	FILE* fsource = fopen(source, "r");
	require(fsource != NULL, prepend_string(
			prepend_string("Error opening source file ", source), "\n"));
	FILE* fdest = fopen(dest, "w");
	require(fdest >= 0, prepend_string(
			prepend_string("Error opening destination file", dest), "\n"));

	/*
	 * The following loop reads a character from the source and writes it to the
	 * dest file. This is all M2-Planet supports.
	 */
	char c = fgetc(fsource);
	while(c != EOF)
	{
		fputc(c, fdest);
		c = fgetc(fsource);
	}

	/* Cleanup */
	fclose(fsource);
	fclose(fdest);
}

int main(int argc, char** argv)
{
	/* Initialize variables */
	char* source = NULL;
	char* dest = NULL;

	/* Set defaults */
	verbose = FALSE;

	int i = 1;
	/* Loop arguments */
	while(i <= argc)
	{
		if(NULL == argv[i])
		{ /* Ignore and continue */
			i = i + 1;
		}
		else if(match(argv[i], "-h") || match(argv[i], "--help"))
		{
			file_print("Usage: ", stdout);
			file_print(argv[0], stdout);
			file_print(" [-h | --help] [-V | --version]\n", stdout);
			exit(EXIT_SUCCESS);
		}
		else if(match(argv[i], "-V") || match(argv[i], "--version"))
		{ /* Output version */
			file_print("cp version 1.1.0\n", stdout);
			exit(EXIT_SUCCESS);
		}
		else if(match(argv[i], "-v") || match(argv[i], "--verbose"))
		{
			verbose = TRUE;
			i = i + 1;
		}
		else if(argv[i][0] != '-')
		{ /* It is not an option */
			/*
			 * We can tell if this is the source file or the destination file
			 * through looking at whether the source file is already set. We
			 * require the source file to be given first so if the source file
			 * is already set we know it must be the destination.
			 */
			if(source != NULL)
			{ /* We are setting the destination */
				dest = calloc(MAX_STRING, sizeof(char));
				require(dest != NULL, "Memory initialization of dest failed\n");
				copy_string(dest, argv[i]);
			}
			else
			{ /* We are setting the source */
				source = calloc(MAX_STRING, sizeof(char));
				require(source != NULL, "Memory initialization of dest failed\n");
				copy_string(source, argv[i]);
			}
			i = i + 1;
		}
		else
		{ /* Unknown argument */
			file_print("UNKNOWN_ARGUMENT\n", stderr);
			exit(EXIT_FAILURE);
		}
	}

	/* Sanitize values */
	/* Ensure the two values have values */
	require(source != NULL, "Provide a source file\n");
	require(dest != NULL, "Provide a destination file\n");

	/* Convert the dest variable to a full path if it's a directory copying to */
	dest = directory_dest(dest, source);

	/* Perform the actual copy */
	copy_file(source, dest);

	free(source);
	free(dest);
}
