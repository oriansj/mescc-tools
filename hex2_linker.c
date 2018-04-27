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
#define max_string 4096
#define TRUE 1
#define FALSE 0

#if __MESC__
	#include <fcntl.h>
	int output;
#else
	FILE* output;
#endif

struct input_files
{
	struct input_files* next;
	char* filename;
};

struct entry
{
	struct entry* next;
	unsigned target;
	char name[max_string + 1];
};

struct entry* jump_table;
int BigEndian;
int Base_Address;
int Architecture;
int ByteMode;
int exec_enable;
int ip;

int consume_token(FILE* source_file, char* s)
{
	int i = 0;
	int c = fgetc(source_file);
	do
	{
		s[i] = c;
		i = i + 1;
		c = fgetc(source_file);
	} while((' ' != c) && ('\t' != c) && ('\n' != c) && '>' != c);

	return c;
}

unsigned GetTarget(char* c)
{
	for(struct entry* i = jump_table; NULL != i; i = i->next)
	{
		if(0 == strcmp(c, i->name))
		{
			return i->target;
		}
	}
	fprintf(stderr, "Target label %s is not valid\n", c);
	exit(EXIT_FAILURE);
}

int storeLabel(FILE* source_file, int ip)
{
	struct entry* entry = calloc(1, sizeof(struct entry));

	/* Prepend to list */
	entry->next = jump_table;
	jump_table = entry;

	/* Store string */
	int c = consume_token(source_file, entry->name);

	/* Ensure we have target address */
	entry->target = ip;
	return c;
}

void range_check(int displacement, int number_of_bytes)
{
	switch(number_of_bytes)
	{
		case 4: break;
		case 3:
		{
			if((8388607 < displacement) || (displacement < -8388608))
			{
				fprintf(stderr, "A displacement of %d does not fit in 3 bytes", displacement);
				exit(EXIT_FAILURE);
			}
			break;
		}
		case 2:
		{
			if((32767 < displacement) || (displacement < -32768))
			{
				fprintf(stderr, "A displacement of %d does not fit in 2 bytes", displacement);
				exit(EXIT_FAILURE);
			}
			break;
		}
		case 1:
		{
			if((127 < displacement) || (displacement < -128))
			{
				fprintf(stderr, "A displacement of %d does not fit in 1 byte", displacement);
				exit(EXIT_FAILURE);
			}
			break;
		}
		default: exit(EXIT_FAILURE);
	}
}

void outputPointer(int displacement, int number_of_bytes)
{
	unsigned value = displacement;

	/* HALT HARD if we are going to do something BAD*/
	range_check(displacement, number_of_bytes);

	if(BigEndian)
	{ /* Deal with BigEndian */
		switch(number_of_bytes)
		{
			case 4: fprintf(output, "%c", value >> 24);
			case 3: fprintf(output, "%c", (value >> 16)%256);
			case 2: fprintf(output, "%c", (value >> 8)%256);
			case 1: fprintf(output, "%c", value % 256);
			default: break;
		}
	}
	else
	{ /* Deal with LittleEndian */
		while(number_of_bytes > 0)
		{
			unsigned byte = value % 256;
			value = value / 256;
			fprintf(output, "%c", byte);
			number_of_bytes = number_of_bytes - 1;
		}
	}
}

int Architectural_displacement(int target, int base)
{
	switch (Architecture)
	{
		case 0:
		case 1:
		case 2: return (target - base);
		default:
		{
			fprintf(stderr, "Unknown Architecture, aborting before harm is done\n");
			exit(EXIT_FAILURE);
		}
	}
}

int ConsumePointer(char ch, FILE* source_file, char* s)
{
	/* Calculate pointer size*/
	if((37 == ch) || (38 == ch)) ip = ip + 4; /* Deal with % and & */
	else if((64 == ch) || (36 == ch)) ip = ip + 2; /* Deal with @ and $ */
	else if(33 == ch) ip = ip + 1; /* Deal with ! */
	else
	{
		fprintf(stderr, "storePointer given unknown\n");
		exit(EXIT_FAILURE);
	}

	return consume_token(source_file, s);
}

void storePointer(char ch, FILE* source_file)
{
	/* Get string of pointer */
	char temp[max_string + 1] = {0};
	#if __MESC__
		memset (temp, 0, max_string + 1);
	#endif

	int base_sep_p = (ConsumePointer(ch, source_file, temp) == 62); // '>'

	/* Lookup token */
	int target = GetTarget(temp);
	int displacement;

	int base = ip;
	/* Change relative base address to :<base> */
	if (base_sep_p)
	{
		char temp2[max_string + 1] = {0};
		#if __MESC__
			memset (temp2, 0, max_string + 1);
		#endif
		consume_token (source_file, temp2);
		base = GetTarget (temp2);
	}

	displacement = Architectural_displacement(target, base);

	/* output calculated difference */
	if(33 == ch) outputPointer(displacement, 1); /* Deal with ! */
	else if(36 == ch) outputPointer(target, 2); /* Deal with $ */
	else if(64 == ch) outputPointer(displacement, 2); /* Deal with @ */
	else if(38 == ch) outputPointer(target, 4); /* Deal with & */
	else if(37 == ch) outputPointer(displacement, 4);  /* Deal with % */
	else
	{
		fprintf(stderr, "storePointer reached impossible case: ch=%c\n", ch);
		exit(EXIT_FAILURE);
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

int hex(int c, FILE* source_file)
{
	if (c >= '0' && c <= '9') return (c - 48);
	else if (c >= 'a' && c <= 'z') return (c - 87);
	else if (c >= 'A' && c <= 'Z') return (c - 55);
	else if (c == '#' || c == ';') line_Comment(source_file);
	return -1;
}

int octal(int c, FILE* source_file)
{
	if (c >= '0' && c <= '7') return (c - 48);
	else if (c == '#' || c == ';') line_Comment(source_file);
	return -1;
}

int binary(int c, FILE* source_file)
{
	if (c == '0' || c == '1') return (c - 48);
	else if (c == '#' || c == ';') line_Comment(source_file);
	return -1;
}


int hold;
int toggle;
void process_byte(char c, FILE* source_file, int write)
{
	if(16 == ByteMode)
	{
		if(0 <= hex(c, source_file))
		{
			if(toggle)
			{
				if(write) fprintf(output, "%c",((hold * 16)) + hex(c, source_file));
				ip = ip + 1;
				hold = 0;
			}
			else
			{
				hold = hex(c, source_file);
			}
			toggle = !toggle;
		}
	}
	else if(8 ==ByteMode)
	{
		if(0 <= octal(c, source_file))
		{
			if(2 == toggle)
			{
				if(write) fprintf(output, "%c",((hold * 8)) + octal(c, source_file));
				ip = ip + 1;
				hold = 0;
				toggle = 0;
			}
			else if(1 == toggle)
			{
				hold = ((hold * 8) + octal(c, source_file));
				toggle = 2;
			}
			else
			{
				hold = octal(c, source_file);
				toggle = 1;
			}
		}
	}
	else if(2 == ByteMode)
	{
		if(0 <= binary(c, source_file))
		{
			if(7 == toggle)
			{
				if(write) fprintf(output, "%c",(hold * 2) + binary(c, source_file));
				ip = ip + 1;
				hold = 0;
				toggle = 0;
			}
			else
			{
				hold = ((hold * 2) + binary(c, source_file));
				toggle = toggle + 1;
			}
		}
	}
}

void first_pass(struct input_files* input)
{
	if(NULL == input) return;
	first_pass(input->next);

	#if __MESC__
		int source_file = open(input->filename, O_RDONLY);
	#else
		FILE* source_file = fopen(input->filename, "r");
	#endif

	if(NULL == source_file)
	{
		fprintf(stderr, "The file: %s can not be opened!\n", input->filename);
		exit(EXIT_FAILURE);
	}

	toggle = FALSE;
	int c;
	char token[max_string + 1];
	for(c = fgetc(source_file); EOF != c; c = fgetc(source_file))
	{
		/* Check for and deal with label */
		if(58 == c)
		{
			c = storeLabel(source_file, ip);
		}

		/* check for and deal with relative/absolute pointers to labels */
		if((33 == c) || (64 == c) || (36 == c) || (37 == c) || (38 == c))
		{ /* deal with 1byte pointer !; 2byte pointers (@ and $); 4byte pointers (% and &) */
			c = ConsumePointer(c, source_file, token);
			if (62 == c)
			{ /* deal with label>base */
				c = consume_token (source_file, token);
			}
		}
		else process_byte(c, source_file, FALSE);
	}
	fclose(source_file);
}

void second_pass(struct input_files* input)
{
	if(NULL == input) return;
	second_pass(input->next);

	#if __MESC__
		int source_file = open(input->filename, O_RDONLY);
	#else
		FILE* source_file = fopen(input->filename, "r");
	#endif

	/* Something that should never happen */
	if(NULL == source_file)
	{
		fprintf(stderr, "The file: %s can not be opened!\nWTF-pass2\n", input->filename);
		exit(EXIT_FAILURE);
	}

	toggle = FALSE;
	hold = 0;
	char token[max_string + 1];

	int c;
	for(c = fgetc(source_file); EOF != c; c = fgetc(source_file))
	{
		if(58 == c) c = consume_token(source_file, token); /* Deal with : */
		else if((33 == c) || (64 == c) || (36 == c) || (37 == c) || (38 == c)) storePointer(c, source_file);  /* Deal with !, @, $, %  and & */
		else process_byte(c, source_file, TRUE);
	}

	fclose(source_file);
}

int hex_numerate(int c)
{
	if (c >= '0' && c <= '9') return (c - 48);
	else if (c >= 'a' && c <= 'f') return (c - 87);
	else if (c >= 'A' && c <= 'F') return (c - 55);
	else return -1;
}

int decimal(int c)
{
	if (c >= '0' && c <= '9') return (c - 48);
	else return -1;
}

int numerate_string(char *a)
{
	int count = 0;
	int index;
	int negative;

	/* If NULL string */
	if(0 == a[0])
	{
		return 0;
	}
	/* Deal with hex */
	else if (a[0] == '0' && a[1] == 'x')
	{
		if('-' == a[2])
		{
			negative = TRUE;
			index = 3;
		}
		else
		{
			negative = FALSE;
			index = 2;
		}

		while(0 != a[index])
		{
			if(-1 == hex_numerate(a[index])) return 0;
			count = (16 * count) + hex_numerate(a[index]);
			index = index + 1;
		}
	}
	/* Deal with decimal */
	else
	{
		if('-' == a[0])
		{
			negative = TRUE;
			index = 1;
		}
		else
		{
			negative = FALSE;
			index = 0;
		}

		while(0 != a[index])
		{
			if(-1 == decimal(a[index])) return 0;
			count = (10 * count) + decimal(a[index]);
			index = index + 1;
		}
	}

	if(negative)
	{
		count = count * -1;
	}
	return count;
}

struct option long_options[] = {
	{"BigEndian", no_argument, &BigEndian, TRUE},
	{"LittleEndian", no_argument, &BigEndian, FALSE},
	{"exec_enable", no_argument, &exec_enable, TRUE},
	{"file", required_argument, 0, 'f'},
	{"Architecture", required_argument, 0, 'A'},
	{"BaseAddress",required_argument, 0, 'B'},
	{"binary",no_argument, 0, 'b'},
	{"output",required_argument, 0, 'o'},
	{"octal",no_argument, 0, 'O'},
	{"help", no_argument, 0, 'h'},
	{"version", no_argument, 0, 'V'},
	{0, 0, 0, 0}
};

/* Standard C main program */
int main(int argc, char **argv)
{
/* Default endianness is that of the native host */
#if defined(__BYTE_ORDER) && __BYTE_ORDER == __BIG_ENDIAN || \
	defined(__BIG_ENDIAN__) || \
	defined(__ARMEB__) || \
	defined(__THUMBEB__) || \
	defined(__AARCH64EB__) || \
	defined(_MIBSEB) || defined(__MIBSEB) || defined(__MIBSEB__)
// It's a big-endian target architecture
		BigEndian = true;
#elif defined(__BYTE_ORDER) && __BYTE_ORDER == __LITTLE_ENDIAN || \
	defined(__LITTLE_ENDIAN__) || \
	defined(__ARMEL__) || \
	defined(__THUMBEL__) || \
	defined(__AARCH64EL__) || \
	defined(_MIPSEL) || defined(__MIPSEL) || defined(__MIPSEL__)
// It's a little-endian target architecture
	BigEndian = FALSE;
#else
#error "I don't know what architecture this is!"
	exit(EXIT_FAILURE);
#endif

	jump_table = NULL;
	Architecture = 0;
	Base_Address = 0;
	struct input_files* input = NULL;
	output = stdout;
	char* output_file = "";
	exec_enable = FALSE;
	ByteMode = 16;

	int c;
	int option_index = 0;
	while ((c = getopt_long(argc, argv, "B:f:h:o:V", long_options, &option_index)) != -1)
	{
		switch(c)
		{
			case 0: break;
			case 'A':
			{
				Architecture = atoi(optarg);
				break;
			}
			case 'b':
			{
				ByteMode = 2;
			}
			case 'B':
			{
				Base_Address = numerate_string(optarg);
				break;
			}
			case 'h':
			{
				fprintf(stderr, "Usage: %s -f FILENAME1 {-f FILENAME2} (--BigEndian|--LittleEndian) [--BaseAddress 12345] [--Architecture 12345]\n", argv[0]);
				fprintf(stderr, "Architecture 0: Knight; 1: x86; 2: AMD64\n");
				exit(EXIT_SUCCESS);
			}
			case 'f':
			{
				struct input_files* temp = calloc(1, sizeof(struct input_files));
				temp->filename = optarg;
				temp->next = input;
				input = temp;
				break;
			}
			case 'o':
			{
				output_file = optarg;
				#if __MESC__
					output = open(output_file, O_CREAT|O_TRUNC|O_WRONLY, S_IRUSR|S_IWUSR);
				#else
					output = fopen(output_file, "w");
				#endif

				if(NULL == output)
				{
					fprintf(stderr, "The file: %s can not be opened!\n", optarg);
					exit(EXIT_FAILURE);
				}
				break;
			}
			case 'O':
			{
				ByteMode = 8;
				break;
			}
			case 'V':
			{
				fprintf(stdout, "hex2 0.3\n");
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
	ip = Base_Address;
	first_pass(input);

	/* Fix all the references*/
	ip = Base_Address;
	second_pass(input);

	/* Set file as executable */
	if(exec_enable)
	{
		if(0 != chmod(output_file, 0750))
		{
			fprintf(stderr,"Unable to change permissions\n");
			exit(EXIT_FAILURE);
		}
	}

	return EXIT_SUCCESS;
}
