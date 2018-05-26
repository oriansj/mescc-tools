#! /usr/bin/env bash
set -eux
[ -e bin ] || mkdir -p bin
[ -f bin/M1 ] || gcc -D_GNU_SOURCE -std=c99 -ggdb M1-macro.c -o bin/M1
[ -f bin/hex2 ] || gcc -D_GNU_SOURCE -std=c99 -ggdb hex2_linker.c -o bin/hex2
[ -f bin/exec_enable ] || gcc -D_GNU_SOURCE -std=c99 -ggdb exec_enable.c -o bin/exec_enable
[ -f bin/get_machine ] || gcc -D_GNU_SOURCE -std=c99 -ggdb get_machine.c -o bin/get_machine
[ -f bin/blood-elf ] || gcc -D_GNU_SOURCE -std=c99 -ggdb blood-elf.c -o bin/blood-elf
[ -f bin/kaem ] || gcc -D_GNU_SOURCE -std=c99 -ggdb kaem.c -o bin/kaem
[ -e test/results ] || mkdir -p test/results
./test/test0/hello.sh
./test/test1/hello.sh
./test/test2/hello.sh
./test/test3/hello.sh
./test/test4/hello.sh
./test/test5/hello.sh
./test/test6/hello.sh
./test/test7/hello.sh
./test/test8/hello.sh
./test/test9/hello.sh
sha256sum -c test/test.answers
