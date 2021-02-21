## Copyright (C) 2017 Jeremiah Orians
## This file is part of mescc-tools.
##
## mescc-tools is free software: you can redistribute it and/or modify
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
VPATH = bin:test/results
PACKAGE = mescc-tools

all: M1 hex2 get_machine blood-elf kaem catm
.NOTPARALLEL:
CC=gcc
CFLAGS:=$(CFLAGS) -D_GNU_SOURCE -std=c99 -ggdb -fno-common

M1: M1-macro.c functions/match.c functions/numerate_number.c functions/string.c functions/require.c functions/in_set.c | bin
	$(CC) $(CFLAGS) M1-macro.c \
	functions/match.c \
	functions/numerate_number.c \
	functions/string.c \
	functions/require.c \
	functions/in_set.c \
	-o bin/M1

hex2: hex2_linker.c functions/match.c functions/numerate_number.c functions/require.c functions/in_set.c | bin
	$(CC) $(CFLAGS) hex2_linker.c \
	functions/match.c \
	functions/numerate_number.c \
	functions/require.c \
	functions/in_set.c \
	-o bin/hex2

get_machine: get_machine.c functions/match.c | bin
	$(CC) $(CFLAGS) functions/match.c get_machine.c -o bin/get_machine

blood-elf: blood-elf.c functions/match.c functions/require.c functions/numerate_number.c | bin
	$(CC) $(CFLAGS) blood-elf.c \
	functions/match.c \
	functions/require.c \
	functions/in_set.c \
	functions/numerate_number.c \
	-o bin/blood-elf

kaem: functions/string.c functions/require.c functions/match.c functions/in_set.c functions/numerate_number.c Kaem/kaem.c Kaem/variable.c Kaem/kaem_globals.c | bin
	cd Kaem && make kaem

catm: catm.c | bin
	$(CC) $(CFLAGS) catm.c -o bin/catm

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
	cd Kaem && make clean

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
	test11-binary \
	test12-binary \
	test13-binary | results
	./test.sh

test0-binary: results hex2 get_machine
	test/test0/hello.sh

test1-binary: results hex2 M1 get_machine
	test/test1/hello.sh

test2-binary: results hex2 M1 get_machine
	test/test2/hello.sh

test3-binary: results hex2 M1 get_machine
	test/test3/hello.sh

test4-binary: results hex2 M1 get_machine
	test/test4/hello.sh

test5-binary: results hex2 M1 get_machine
	test/test5/hello.sh

test6-binary: results hex2 M1 get_machine
	test/test6/hello.sh

test7-binary: results hex2 M1 get_machine
	test/test7/hello.sh

test8-binary: results hex2 M1 get_machine
	test/test8/hello.sh

test9-binary: results hex2 M1 blood-elf get_machine
	test/test9/hello.sh

test10-binary: results hex2 M1 get_machine
	test/test10/hello.sh

test11-binary: results hex2 M1 blood-elf get_machine
	test/test11/hello.sh

test12-binary: results hex2 M1 blood-elf get_machine
	test/test12/hello.sh

test13-binary: results hex2 M1 blood-elf get_machine
	test/test13/hello.sh

# Generate test answers
.PHONY: Generate-test-answers
Generate-test-answers:
	sha256sum test/results/* >| test/test.answers

DESTDIR:=
PREFIX:=/usr/local
bindir:=$(DESTDIR)$(PREFIX)/bin
.PHONY: install
install: M1 hex2 blood-elf kaem get_machine
	mkdir -p $(bindir)
	cp $^ $(bindir)

###  dist
.PHONY: dist

COMMIT=$(shell git describe --dirty)
TARBALL_VERSION=$(COMMIT:Release_%=%)
TARBALL_DIR:=$(PACKAGE)-$(TARBALL_VERSION)
TARBALL=$(TARBALL_DIR).tar.gz
# Be friendly to Debian; avoid using EPOCH
MTIME=$(shell git show HEAD --format=%ct --no-patch)
# Reproducible tarball
TAR_FLAGS=--sort=name --mtime=@$(MTIME) --owner=0 --group=0 --numeric-owner --mode=go=rX,u+rw,a-s

$(TARBALL):
	(git ls-files					\
	    --exclude=$(TARBALL_DIR);			\
	    echo $^ | tr ' ' '\n')			\
	    | tar $(TAR_FLAGS)				\
	    --transform=s,^,$(TARBALL_DIR)/,S -T- -cf-	\
	    | gzip -c --no-name > $@

dist: $(TARBALL)
