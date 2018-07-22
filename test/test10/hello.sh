#! /bin/sh
set -x
./bin/M1 --LittleEndian --Architecture 40 -f test/test10/exit_42.M1 -o test/test10/exit_42.hex2 || exit 1
./bin/hex2 --LittleEndian --Architecture 40 --BaseAddress 0x10000 -f elf_headers/elf32-ARM.hex2 -f test/test10/exit_42.hex2 -o test/results/test10-binary --exec_enable || exit 2
exit 0
