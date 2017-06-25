# Prevent rebuilding
VPATH = bin:test:test/results

all: M0 hex2

M0: M0-macro.c | bin
	gcc -ggdb M0-macro.c -o bin/M0

hex2: hex2_linker.c | bin
	gcc -ggdb hex2_linker.c -o bin/hex2

# Clean up after ourselves
.PHONY: clean
clean:
	rm -rf bin/ test/results/

# Directories
bin:
	mkdir -p bin

results:
	mkdir -p test/results

# tests
test: test0-binary test1-binary | results
	sha256sum -c test/test.answers

test0-binary: results hex2
	test/test0/hello.sh

test1-binary: results hex2 M0
	test/test1/hello.sh

test2-binary: results hex2 M0
	test/test2/hello.sh

# Generate test answers
.PHONY: Generate-test-answers
Generate-test-answers:
	sha256sum test/results/* >| test/test.answers

DESTDIR:=
PREFIX:=/usr/local
bindir:=$(DESTDIR)$(PREFIX)/bin
.PHONY: install
install: M0 hex2
	mkdir -p $(bindir)
	cp $^ $(bindir)
