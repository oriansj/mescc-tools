# Prevent rebuilding
VPATH = bin:test:test/results

all: M1 hex2

M1: M1-macro.c | bin
	gcc -ggdb M1-macro.c -o bin/M1

hex2: hex2_linker.c | bin
	gcc -ggdb hex2_linker.c -o bin/hex2

# Clean up after ourselves
.PHONY: clean
clean:
	rm -rf bin/ test/results/
	./test/test1/cleanup.sh
	./test/test2/cleanup.sh
	./test/test3/cleanup.sh
	./test/test4/cleanup.sh

# Directories
bin:
	mkdir -p bin

results:
	mkdir -p test/results

# tests
test: test0-binary test1-binary test2-binary test3-binary test4-binary | results
	sha256sum -c test/test.answers

test0-binary: results hex2
	test/test0/hello.sh

test1-binary: results hex2 M1
	test/test1/hello.sh

test2-binary: results hex2 M1
	test/test2/hello.sh

test3-binary: results hex2 M1
	test/test3/hello.sh

test4-binary: results hex2 M1
	test/test4/hello.sh

# Generate test answers
.PHONY: Generate-test-answers
Generate-test-answers:
	sha256sum test/results/* >| test/test.answers

DESTDIR:=
PREFIX:=/usr/local
bindir:=$(DESTDIR)$(PREFIX)/bin
.PHONY: install
install: M1 hex2
	mkdir -p $(bindir)
	cp $^ $(bindir)
