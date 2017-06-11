# Prevent rebuilding
VPATH = bin

all: M0 hex2

M0: M0-macro.c | bin
	gcc -ggdb M0-macro.c -o bin/M0

hex2: hex2_linker.c | bin
	gcc -ggdb hex2_linker.c -o bin/hex2

# Clean up after ourselves
.PHONY: clean
clean:
	rm -rf bin/

# Directories
bin:
	mkdir -p bin
