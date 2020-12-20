/* -*- c-file-style: "linux";indent-tabs-mode:t -*- */
/* Copyright (C) 2017 Jeremiah Orians
 * Copyright (C) 2017 Jan Nieuwenhuizen <janneke@gnu.org>
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
#include <string.h>
#include <getopt.h>
#include <unistd.h>
#include <sys/stat.h>


#define max_string 4096
//CONSTANT max_string 4096
#define TRUE 1
//CONSTANT TRUE 1
#define FALSE 0
//CONSTANT FALSE 0
int BITSIZE;

int in_set(int c, char* s);
int match(char* a, char* b);
void file_print(char* s, FILE* f);
void require(int bool, char* error);
char* numerate_number(int a);

struct entry
{
	struct entry* next;
	char* name;
};

FILE* output;
struct entry* jump_table;
int count;
char* entry;

void consume_token(FILE* source_file, char* s)
{
	int i = 0;
	int c = fgetc(source_file);
	require(EOF != c, "Can not have an EOF token\n");
	do
	{
		s[i] = c;
		i = i + 1;
		require(max_string > i, "Token exceeds token length restriction\n");
		c = fgetc(source_file);
		if(EOF == c) break;
	} while(!in_set(c, " \t\n>"));
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

	count = count + 1;
}

void line_Comment(FILE* source_file)
{
	int c = fgetc(source_file);
	while(!in_set(c, "\n\r"))
	{
		if(EOF == c) break;
		c = fgetc(source_file);
	}
}

void purge_string(FILE* source_file)
{
	int c = fgetc(source_file);
	while((EOF != c) && ('"' != c))
	{
		c = fgetc(source_file);
	}
}

void first_pass(struct entry* input)
{
	if(NULL == input) return;
	first_pass(input->next);

	FILE* source_file = fopen(input->name, "r");

	if(NULL == source_file)
	{
		file_print("The file: ", stderr);
		file_print(input->name, stderr);
		file_print(" can not be opened!\n", stderr);
		exit(EXIT_FAILURE);
	}

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
		else if ('"' == c)
		{
			purge_string(source_file);
		}
	}
	fclose(source_file);
}

void output_string_table(struct entry* node)
{
	file_print("\n# Generated string table\n:ELF_str\n!0\t# NULL string\n", output);
	struct entry* i;
	for(i = node; NULL != i; i = i->next)
	{
		file_print(":ELF_str_", output);
		file_print(i->name, output);
		file_print("\t\"", output);
		file_print(i->name, output);
		file_print("\"\n", output);
	}
	file_print("# END Generated string table\n\n", output);
}

void output_symbol_table(struct entry* node)
{
	file_print("\n# Generated symbol table\n:ELF_sym\n# Required NULL symbol entry\n", output);
	if(64 == BITSIZE)
	{
		file_print("%0\t# st_name\n", output);
		file_print("!0\t# st_info\n", output);
		file_print("!0\t# st_other\n", output);
		file_print("@1\t# st_shndx\n", output);
		file_print("%0 %0\t# st_value\n", output);
		file_print("%0 %0\t# st_size\n\n", output);
	}
	else
	{
		file_print("%0\t# st_name\n", output);
		file_print("%0\t# st_value\n", output);
		file_print("%0\t# st_size\n", output);
		file_print("!0\t# st_info\n", output);
		file_print("!0\t# st_other\n", output);
		file_print("@1\t# st_shndx\n\n", output);
	}

	struct entry* i;
	for(i = node; NULL != i; i = i->next)
	{
		file_print("%ELF_str_", output);
		file_print(i->name, output);
		file_print(">ELF_str\t# st_name\n", output);

		if(64 == BITSIZE)
		{
			file_print("!2\t# st_info (FUNC)\n", output);
			if(('_' == i->name[0]) && !match(entry, i->name)) file_print("!2\t# st_other (hidden)\n", output);
			else file_print("!0\t# st_other (other)\n", output);
			file_print("@1\t# st_shndx\n", output);
			file_print("&", output);
			file_print(i->name, output);
			file_print(" %0\t# st_value\n", output);
			file_print("%0 %0\t# st_size (unknown size)\n\n", output);
		}
		else
		{
			file_print("&", output);
			file_print(i->name, output);
			file_print("\t#st_value\n", output);
			file_print("%0\t# st_size (unknown size)\n", output);
			file_print("!2\t# st_info (FUNC)\n", output);
			if(('_' == i->name[0]) && !match(entry, i->name)) file_print("!2\t# st_other (hidden)\n", output);
			else file_print("!0\t# st_other (default)\n", output);
			file_print("@1\t# st_shndx\n\n", output);
		}
	}

	file_print("# END Generated symbol table\n", output);
}

struct entry* reverse_list(struct entry* head)
{
	struct entry* root = NULL;
	struct entry* next;
	while(NULL != head)
	{
		next = head->next;
		head->next = root;
		root = head;
		head = next;
	}
	return root;
}

void write_int(char* field, char* label)
{
	file_print(field, output);
	file_print("\t#", output);
	file_print(label, output);
	fputc('\n', output);
}

void write_register(char* field, char* label)
{
	/* $field section in the section headers are different size for 32 and 64bits */
	/* The below is broken for BigEndian */
	file_print(field, output);
	if(64 == BITSIZE) file_print(" %0\t#", output);
	else file_print("\t#", output);
	file_print(label, output);
	fputc('\n', output);
}

void write_section(char* label, char* name, char* type, char* flags, char* address, char* offset, char* size, char* link, char* info, char* entry)
{
	/* Write label */
	fputc('\n', output);
	file_print(label, output);
	fputc('\n', output);

	write_int(name, "sh_name");
	write_int(type, "sh_type");
	write_register(flags, "sh_flags");
	write_register(address, "sh_addr");
	write_register(offset, "sh_offset");
	write_register(size, "sh_size");
	write_int(link, "sh_link");

	/* Deal with the ugly case of stubs */
	fputc('%', output);
	file_print(info, output);
	file_print("\t#sh_info\n", output);

	/* Alignment section in the section headers are different size for 32 and 64bits */
	/* The below is broken for BigEndian */
	if(64 == BITSIZE) file_print("%1 %0\t#sh_addralign\n", output);
	else file_print("%1\t#sh_addralign\n", output);

	write_register(entry, "sh_entsize");
}

/* Standard C main program */
int main(int argc, char **argv)
{
	jump_table = NULL;
	struct entry* input = NULL;
	output = stdout;
	char* output_file = "";
	entry = "";
	BITSIZE = 32;
	count = 1;
	struct entry* temp;
	struct entry* head;

	int option_index = 1;
	while(option_index <= argc)
	{
		if(NULL == argv[option_index])
		{
			option_index = option_index + 1;
		}
		else if(match(argv[option_index], "-h") || match(argv[option_index], "--help"))
		{
			file_print("Usage: ", stderr);
			file_print(argv[0], stderr);
			file_print(" --file FILENAME1 {--file FILENAME2} --output FILENAME\n", stderr);
			exit(EXIT_SUCCESS);
		}
		else if(match(argv[option_index], "--64"))
		{
			BITSIZE = 64;
			option_index = option_index + 1;
		}
		else if(match(argv[option_index], "-f") || match(argv[option_index], "--file"))
		{
			temp = calloc(1, sizeof(struct entry));
			temp->name = argv[option_index + 1];
			temp->next = input;
			input = temp;
			option_index = option_index + 2;
		}
		else if(match(argv[option_index], "-o") || match(argv[option_index], "--output"))
		{
			output_file = argv[option_index + 1];
			output = fopen(output_file, "w");

			if(NULL == output)
			{
				file_print("The file: ", stderr);
				file_print(input->name, stderr);
				file_print(" can not be opened!\n", stderr);
				exit(EXIT_FAILURE);
			}
			option_index = option_index + 2;
		}
		else if(match(argv[option_index], "-V") || match(argv[option_index], "--version"))
		{
			file_print("blood-elf 1.0.0\n(Basically Launches Odd Object Dump ExecutabLe Files\n", stdout);
			exit(EXIT_SUCCESS);
		}
		else if(match(argv[option_index], "--entry"))
		{
			head = calloc(1, sizeof(struct entry));
			/* Include _start or any other entry from your .hex2 */
			head->next = jump_table;
			jump_table = head;
			jump_table->name = argv[option_index + 1];
			/* However only the last one will be exempt from the _name hidden rule */
			entry = argv[option_index + 1];
			option_index = option_index + 2;
			count = count + 1;
		}
		else
		{
			file_print("Unknown option\n", stderr);
			exit(EXIT_FAILURE);
		}
	}

	/* Make sure we have a program tape to run */
	if (NULL == input)
	{
		return EXIT_FAILURE;
	}

	/* Get all of the labels */
	first_pass(input);

	/* Reverse their order */
	jump_table = reverse_list(jump_table);

	/* Create sections */
	/* Create string names for sections */
	file_print("# Generated sections\n:ELF_shstr\n!0\t# NULL\n", output);
	file_print(":ELF_shstr__text\n\".text\"\n", output);
	file_print(":ELF_shstr__shstr\n\".shstrtab\"\n", output);
	file_print(":ELF_shstr__sym\n\".symtab\"\n", output);
	file_print(":ELF_shstr__str\n\".strtab\"\n", output);

	/* Create NULL section header as is required by the Spec. So dumb and waste of bytes*/
	write_section(":ELF_section_headers", "%0", "%0", "%0", "%0", "%0", "%0", "%0", "0", "%0");
	write_section(":ELF_section_header_text", "%ELF_shstr__text>ELF_shstr", "%1", "%6", "&ELF_text", "%ELF_text>ELF_base", "%ELF_data>ELF_text", "%0", "0", "%0");
	write_section(":ELF_section_header_shstr", "%ELF_shstr__shstr>ELF_shstr", "%3", "%0", "&ELF_shstr", "%ELF_shstr>ELF_base", "%ELF_section_headers>ELF_shstr", "%0", "0", "%0");
	write_section(":ELF_section_header_str", "%ELF_shstr__str>ELF_shstr", "%3", "%0", "&ELF_str", "%ELF_str>ELF_base", "%ELF_sym>ELF_str", "%0", "0", "%0");
	if(64 == BITSIZE) write_section(":ELF_section_header_sym", "%ELF_shstr__sym>ELF_shstr", "%2", "%0", "&ELF_sym", "%ELF_sym>ELF_base", "%ELF_end>ELF_sym", "%3", numerate_number(count), "%24");
	else write_section(":ELF_section_header_sym", "%ELF_shstr__sym>ELF_shstr", "%2", "%0", "&ELF_sym", "%ELF_sym>ELF_base", "%ELF_end>ELF_sym", "%3", numerate_number(count), "%16");

	/* Create dwarf stubs needed for objdump -d to get function names */
	output_string_table(jump_table);
	output_symbol_table(jump_table);
	file_print("\n:ELF_end\n", output);

	/* Close output file */
	fflush(output);
	fclose(output);

	return EXIT_SUCCESS;
}
