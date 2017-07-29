#! /bin/sh
set -x
./bin/M1 -f test/test2/hex.M1 --LittleEndian --Architecture 1 >| test/test2/hold
./bin/hex2 -f elf_headers/elf32.hex2 -f test/test2/hold --LittleEndian --Architecture 1 --BaseAddress 0x8048000 -o test/results/test2-binary --exec_enable
./test/results/test2-binary < test/test2/example_test.hex > test/test2/proof
r=$?
[ $r = 0 ] || exit 1
out=$(sha256sum -c test/test2/proof.answer)
[ "$out" = "test/test2/proof: OK" ] || exit 2
exit 0
