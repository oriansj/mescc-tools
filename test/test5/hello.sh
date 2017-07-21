#! /bin/sh
set -x
./bin/M1 -f test/test5/exec_enable_amd64.M1 --LittleEndian --Architecture 2 >| test/test5/hold
./bin/hex2 -f elf_headers/elf64.hex2 -f test/test5/hold --LittleEndian --Architecture 2 --BaseAddress 0x8048000 >| test/results/test5-binary
chmod +x test/results/test5-binary
exit 0
