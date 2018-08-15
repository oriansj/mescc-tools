## Copyright (C) 2017 Jeremiah Orians
## This file is part of mescc-tools.
##
## mescc-tools is free software: you an redistribute it and/or modify
## it under the terms of the GNU General Public License as published by
## the Free Software Foundation, either version 3 of the License, or
## (at your option) any later version.
##
## mescc-tools is distributed in the hope that it will be useful,
## but WITHOUT ANY WARRANTY; without even the implied warranty of
## MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
## GNU General Public License for more details.
##
## You should have received a copy of the GNU General Public License
## along with mescc-tools.  If not, see <http://www.gnu.org/licenses/>.

# Prevent rebuilding
VPATH = bin:test:test/results

all: M1 hex2 exec_enable get_machine blood-elf kaem

CC=gcc
CFLAGS=-D_GNU_SOURCE -std=c99 -ggdb

M1: M1-macro.c functions/file_print.c functions/match.c functions/numerate_number.c functions/string.c | bin
	$(CC) $(CFLAGS) M1-macro.c functions/file_print.c functions/match.c functions/numerate_number.c functions/string.c -o bin/M1

hex2: hex2_linker.c functions/match.c functions/file_print.c functions/numerate_number.c | bin
	$(CC) $(CFLAGS) hex2_linker.c functions/match.c functions/file_print.c functions/numerate_number.c -o bin/hex2

exec_enable: exec_enable.c | bin
	$(CC) $(CFLAGS) functions/file_print.c exec_enable.c -o bin/exec_enable

get_machine: get_machine.c | bin
	$(CC) $(CFLAGS) functions/file_print.c get_machine.c -o bin/get_machine

blood-elf: blood-elf.c functions/file_print.c functions/match.c | bin
	$(CC) $(CFLAGS) blood-elf.c functions/file_print.c functions/match.c -o bin/blood-elf

kaem: kaem.c | bin
	$(CC) $(CFLAGS) kaem.c -o bin/kaem

# Clean up after ourselves
.PHONY: clean
clean:
	rm -rf bin/ test/results/
	./test/test1/cleanup.sh
	./test/test2/cleanup.sh
	./test/test3/cleanup.sh
	./test/test4/cleanup.sh
	./test/test5/cleanup.sh
	./test/test6/cleanup.sh
	./test/test7/cleanup.sh
	./test/test8/cleanup.sh
	./test/test9/cleanup.sh
	./test/test10/cleanup.sh
	./test/test11/cleanup.sh

# A cleanup option we probably don't need
.PHONY: clean-hard
clean-hard: clean
	git reset --hard
	git clean -fd

# Directories
bin:
	mkdir -p bin

results:
	mkdir -p test/results

# tests
test: test0-binary \
	test1-binary \
	test2-binary \
	test3-binary \
	test4-binary \
	test5-binary \
	test6-binary \
	test7-binary \
	test8-binary \
	test9-binary \
	test10-binary \
	test11-binary | results
	sha256sum -c test/test.answers

test0-binary: results hex2 get_machine
	test/test0/hello.sh

test1-binary: results hex2 M1 exec_enable get_machine
	test/test1/hello.sh

test2-binary: results hex2 M1
	test/test2/hello.sh

test3-binary: results hex2 M1
	test/test3/hello.sh

test4-binary: results hex2 M1
	test/test4/hello.sh

test5-binary: results hex2 M1
	test/test5/hello.sh

test6-binary: results hex2 M1
	test/test6/hello.sh

test7-binary: results hex2 M1
	test/test7/hello.sh

test8-binary: results hex2 M1
	test/test8/hello.sh

test9-binary: results hex2 M1 blood-elf
	test/test9/hello.sh

test10-binary: results hex2 M1
	test/test10/hello.sh

test11-binary: results hex2 M1 blood-elf
	test/test11/hello.sh

# Generate test answers
.PHONY: Generate-test-answers
Generate-test-answers:
	sha256sum test/results/* >| test/test.answers

DESTDIR:=
PREFIX:=/usr/local
bindir:=$(DESTDIR)$(PREFIX)/bin
.PHONY: install
install: M1 hex2 blood-elf
	mkdir -p $(bindir)
	cp $^ $(bindir)
