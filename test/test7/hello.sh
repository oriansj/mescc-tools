#! /bin/sh
set -x
./bin/M1 -f test/test7/hex1_amd64.M1 --LittleEndian --Architecture 2 >| test/test7/hold
./bin/hex2 -f elf_headers/elf64.hex2 -f test/test7/hold --LittleEndian --Architecture 2 --BaseAddress 0x00600000 -o test/results/test7-binary --exec_enable
./test/results/test7-binary test/test7/hex1.hex1 > test/test7/proof
r=$?
[ $r = 0 ] || exit 1
out=$(sha256sum -c test/test7/proof.answer)
[ "$out" = "test/test7/proof: OK" ] || exit 2
exit 0
