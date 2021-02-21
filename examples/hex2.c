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
#include <unistd.h>
#include <sys/stat.h>

#define max_string 4096
#define TRUE 1
#define FALSE 0

int match(char* a, char* b);

struct entry
{
	struct entry* next;
	unsigned target;
	char* name;
};

FILE* output;
FILE* input;
struct entry* jump_table;
int ip;
char* scratch;

int in_set(int c, char* s)
{
	while(0 != s[0])
	{
		if(c == s[0]) return TRUE;
		s = s + 1;
	}
	return FALSE;
}

int consume_token()
{
	int i = 0;
	int c = fgetc(input);
	while(!in_set(c, " \t\n>"))
	{
		scratch[i] = c;
		i = i + 1;
		c = fgetc(input);
	}

	return c;
}

int Throwaway_token()
{
	int c;
	do
	{
		c = fgetc(input);
	} while(!in_set(c, " \t\n>"));

	return c;
}

int length(char* s)
{
	int i = 0;
	while(0 != s[i]) i = i + 1;
	return i;
}

void Clear_Scratch(char* s)
{
	do
	{
		s[0] = 0;
		s = s + 1;
	} while(0 != s[0]);
}

void Copy_String(char* a, char* b)
{
	while(0 != a[0])
	{
		b[0] = a[0];
		a = a + 1;
		b = b + 1;
	}
}

unsigned GetTarget(char* c)
{
	struct entry* i;
	for(i = jump_table; NULL != i; i = i->next)
	{
		if(match(c, i->name))
		{
			return i->target;
		}
	}
	exit(EXIT_FAILURE);
}

int storeLabel()
{
	struct entry* entry = calloc(1, sizeof(struct entry));

	/* Ensure we have target address */
	entry->target = ip;

	/* Prepend to list */
	entry->next = jump_table;
	jump_table = entry;

	/* Store string */
	int c = consume_token();
	entry->name = calloc(length(scratch) + 1, sizeof(char));
	Copy_String(scratch, entry->name);
	Clear_Scratch(scratch);

	return c;
}

void outputPointer(int displacement, int number_of_bytes)
{
	unsigned value = displacement;

	while(number_of_bytes > 0)
	{
		unsigned byte = value % 256;
		value = value / 256;
		fputc(byte, output);
		number_of_bytes = number_of_bytes - 1;
	}
}

void Update_Pointer(char ch)
{
	/* Calculate pointer size*/
	if(in_set(ch, "%&")) ip = ip + 4; /* Deal with % and & */
	else if(in_set(ch, "@$")) ip = ip + 2; /* Deal with @ and $ */
	else if('!' == ch) ip = ip + 1; /* Deal with ! */
}

void storePointer(char ch)
{
	/* Get string of pointer */
	Clear_Scratch(scratch);
	Update_Pointer(ch);
	int base_sep_p = consume_token();

	/* Lookup token */
	int target = GetTarget(scratch);
	int displacement;

	int base = ip;
	/* Change relative base address to :<base> */
	if ('>' == base_sep_p)
	{
		Clear_Scratch(scratch);
		consume_token();
		base = GetTarget (scratch);
	}

	displacement = (target - base);

	/* output calculated difference */
	if('!' == ch) outputPointer(displacement, 1); /* Deal with ! */
	else if('$' == ch) outputPointer(target, 2); /* Deal with $ */
	else if('@' == ch) outputPointer(displacement, 2); /* Deal with @ */
	else if('&' == ch) outputPointer(target, 4); /* Deal with & */
	else if('%' == ch) outputPointer(displacement, 4);  /* Deal with % */
}

void line_Comment()
{
	int c = fgetc(input);
	while(!in_set(c, "\n\r"))
	{
		c = fgetc(input);
	}
}

int hex(int c)
{
	if (in_set(c, "0123456789")) return (c - 48);
	else if (in_set(c, "abcdef")) return (c - 87);
	else if (in_set(c, "ABCDEF")) return (c - 55);
	else if (in_set(c, "#;")) line_Comment();
	return -1;
}

int hold;
int toggle;
void process_byte(char c, int write)
{
	if(0 <= hex(c))
	{
		if(toggle)
		{
			if(write) fputc(((hold * 16)) + hex(c), output);
			ip = ip + 1;
			hold = 0;
		}
		else
		{
			hold = hex(c);
		}
		toggle = !toggle;
	}
}

void first_pass()
{
	int c;
	for(c = fgetc(input); EOF != c; c = fgetc(input))
	{
		/* Check for and deal with label */
		if(':' == c)
		{
			c = storeLabel();
		}

		/* check for and deal with relative/absolute pointers to labels */
		if(in_set(c, "!@$%&"))
		{ /* deal with 1byte pointer !; 2byte pointers (@ and $); 4byte pointers (% and &) */
			Update_Pointer(c);
			c = Throwaway_token();
			if ('>' == c)
			{ /* deal with label>base */
				c = Throwaway_token();
			}
		}
		else process_byte(c, FALSE);
	}
	fclose(input);
}

void second_pass()
{
	int c;
	for(c = fgetc(input); EOF != c; c = fgetc(input))
	{
		if(':' == c) c = Throwaway_token(); /* Deal with : */
		else if(in_set(c, "!@$%&")) storePointer(c);  /* Deal with !, @, $, %  and & */
		else process_byte(c, TRUE);
	}

	fclose(input);
}

/* Standard C main program */
int main(int argc, char **argv)
{
	jump_table = NULL;
	input = fopen(argv[1], "r");
	output = fopen(argv[2], "w");
	scratch = calloc(max_string + 1, sizeof(char));

	/* Get all of the labels */
	ip = 0x8048000;
	toggle = FALSE;
	hold = 0;
	first_pass();

	/* Fix all the references*/
	rewind(input);
	ip = 0x8048000;
	toggle = FALSE;
	hold = 0;
	second_pass();

	return EXIT_SUCCESS;
}
