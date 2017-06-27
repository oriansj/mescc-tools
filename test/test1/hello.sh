#! /bin/sh
set -x
./bin/M1 -f test/test1/hex.M1 --LittleEndian --Architecture 2 >| test/test1/hold
./bin/hex2 -f test/test1/elf64 -f test/test1/hold --LittleEndian --Architecture 1 --BaseAddress 0x00600000 >| test/results/test1-binary
chmod u+x test/results/test1-binary
./test/results/test1-binary < test/test1/example_test.hex > test/test1/proof
r=$?
[ $r = 0 ] || exit 1
out=$(sha256sum -c test/test1/proof.answer)
[ "$out" = "test/test1/proof: OK" ] || exit 2
exit 0
