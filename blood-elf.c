/* -*- c-file-style: "linux";indent-tabs-mode:t -*- */
/* Copyright (C) 2017 Jeremiah Orians
 * Copyright (C) 2017 Jan Nieuwenhuizen <janneke@gnu.org>
 * This file is part of MES
 *
 * MES is free software: you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation, either version 3 of the License, or
 * (at your option) any later version.
 *
 * MES is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License
 * along with stage0.  If not, see <http://www.gnu.org/licenses/>.
 */

#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <getopt.h>
#include <unistd.h>
#include <sys/stat.h>
#define max_string 255
#define TRUE 1
#define FALSE 0

#if __MESC__
	#include <fcntl.h>
	int output;
#else
	FILE* output;
#endif

struct entry
{
	struct entry* next;
	char* name;
};

struct entry* jump_table;

void consume_token(FILE* source_file, char* s)
{
	int i = 0;
	int c = fgetc(source_file);
	do
	{
		s[i] = c;
		i = i + 1;
		c = fgetc(source_file);
	} while((' ' != c) && ('\t' != c) && ('\n' != c) && '>' != c);
}

void storeLabel(FILE* source_file)
{
	struct entry* entry = calloc(1, sizeof(struct entry));

	/* Prepend to list */
	entry->next = jump_table;
	jump_table = entry;

	/* Store string */
	entry->name = calloc((max_string + 1), sizeof(char));
	consume_token(source_file, entry->name);

	/* Remove all entries that start with the forbidden char : */
	if(':' == entry->name[0])
	{
		jump_table = jump_table->next;
	}
}

void line_Comment(FILE* source_file)
{
	int c = fgetc(source_file);
	while((10 != c) && (13 != c))
	{
		c = fgetc(source_file);
	}
}

void purge_string(FILE* source_file)
{
	int c = fgetc(source_file);
	while((EOF != c) && (34 != c))
	{
		c = fgetc(source_file);
	}
}

void first_pass(struct entry* input)
{
	if(NULL == input) return;
	first_pass(input->next);

	#if __MESC__
		int source_file = open(input->filename, O_RDONLY);
	#else
		FILE* source_file = fopen(input->name, "r");
	#endif

	int c;
	for(c = fgetc(source_file); EOF != c; c = fgetc(source_file))
	{
		/* Check for and deal with label */
		if(58 == c)
		{
			storeLabel(source_file);
		}
		/* Check for and deal with line comments */
		else if (c == '#' || c == ';')
		{
			line_Comment(source_file);
		}
		else if (34 == c)
		{
			purge_string(source_file);
		}
	}
	fclose(source_file);
}

void output_debug(struct entry* node, int stage)
{
	if(NULL == node) return;
	output_debug(node->next, stage);
	if(stage)
	{
		fprintf(output, ":ELF_str_%s\n\"%s\"\n", node->name, node->name);
	}
	else
	{
		fprintf(output, "%cELF_str_%s>ELF_str\n&%s\n%c10\n!2\n!0\n@1\n", 37, node->name, node->name, 37);
	}
}

struct option long_options[] = {
	{"file", required_argument, 0, 'f'},
	{"output",required_argument, 0, 'o'},
	{"help", no_argument, 0, 'h'},
	{"version", no_argument, 0, 'V'},
	{0, 0, 0, 0}
};

/* Standard C main program */
int main(int argc, char **argv)
{
	jump_table = NULL;
	struct entry* input = NULL;
	output = stdout;
	char* output_file = "";

	int c;
	int option_index = 0;
	while ((c = getopt_long(argc, argv, "B:f:h:o:V", long_options, &option_index)) != -1)
	{
		switch(c)
		{
			case 0: break;
			case 'h':
			{
				fprintf(stderr, "Usage: %s -f FILENAME1 {-f FILENAME2}\n", argv[0]);
				exit(EXIT_SUCCESS);
			}
			case 'f':
			{
				struct entry* temp = calloc(1, sizeof(struct entry));
				temp->name = optarg;
				temp->next = input;
				input = temp;
				break;
			}
			case 'o':
			{
				output_file = optarg;
				#if __MESC__
					output = open(output_file, O_WRONLY);
				#else
					output = fopen(output_file, "w");
				#endif
				break;
			}
			case 'V':
			{
				fprintf(stdout, "blood-elf 0.1\n(Basically Launches Odd Object Dump ExecutabLe Files\n");
				exit(EXIT_SUCCESS);
			}
			default:
			{
				fprintf(stderr, "Unknown option\n");
				exit(EXIT_FAILURE);
			}
		}
	}

	/* Make sure we have a program tape to run */
	if (NULL == input)
	{
		return EXIT_FAILURE;
	}

	/* Get all of the labels */
	first_pass(input);

	fprintf(output, ":ELF_str\n!0\n");
	output_debug(jump_table, TRUE);
	fprintf(output, "%c0\n:ELF_sym\n%c0\n%c0\n%c0\n!0\n!0\n@1\n", 37, 37, 37, 37);
	output_debug(jump_table, FALSE);
	fprintf(output, "\n:ELF_end\n");

	return EXIT_SUCCESS;
}
