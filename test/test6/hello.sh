#! /bin/sh
set -x
./bin/M1 -f test/test6/exec_enable_i386.M1 --LittleEndian --Architecture 1 >| test/test6/hold
./bin/hex2 -f elf_headers/elf32.hex2 -f test/test6/hold --LittleEndian --Architecture 1 --BaseAddress 0x8048000 >| test/results/test6-binary
chmod +x test/results/test6-binary
exit 0
