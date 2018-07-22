#! /bin/sh
set -x
./bin/blood-elf -f test/test11/hello.M1 -o test/test11/footer.M1 || exit 1
./bin/M1 --LittleEndian --Architecture 40 -f test/test11/hello.M1 -f test/test11/footer.M1 -o test/test11/hello.hex2 || exit 2
./bin/hex2 --LittleEndian --Architecture 40 --BaseAddress 0x10000 -f elf_headers/elf32-ARM-debug.hex2 -f test/test11/hello.hex2 -o test/results/test11-binary --exec_enable || exit 3
exit 0
