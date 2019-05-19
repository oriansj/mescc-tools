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

#include <stdio.h>
#include <stdlib.h>
#include <unistd.h>
#include <sys/stat.h>
void file_print(char* s, FILE* f);

int main(int argc, char **argv)
{
	/************************************************
	 * 493 in decimal is 755 in Octal, which is the *
	 * value we need to set the execute and read    *
	 * bits for all users and the write bit for the *
	 * Owner of the files                           *
	 ************************************************/
	int m = 493;

	if(2 != argc)
	{
		file_print("arg count\n", stderr);
		exit(EXIT_FAILURE);
	}

	if(0 != chmod(argv[1], m))
	{
		file_print("Unable to change permissions\n", stderr);
		exit(EXIT_FAILURE);
	}

	exit(EXIT_SUCCESS);
}
