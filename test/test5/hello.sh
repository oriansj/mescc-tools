#! /bin/sh
set -x
./bin/M1 -f test/test5/exec_enable_amd64.M1 --LittleEndian --Architecture 2 -o test/test5/hold
./bin/hex2 -f elf_headers/elf64.hex2 -f test/test5/hold --LittleEndian --Architecture 2 --BaseAddress 0x00600000 -o test/results/test5-binary --exec_enable
exit 0
