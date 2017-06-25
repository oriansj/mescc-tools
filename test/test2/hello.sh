#! /bin/bash
set -x
./bin/M0 -f test/test2/hex.M1 --LittleEndian >| test/test2/hold
./bin/hex2 -f test/test2/elf32.hex2 -f test/test2/hold --LittleEndian --Architecture 1 --BaseAddress 0x8048000 >| test/results/test2-binary
chmod u+x test/results/test2-binary
./test/results/test2-binary < test/test2/example_test.hex > test/test2/proof
r=$?
[ $r = 0 ] || exit 1
out=$(sha256sum -c <(echo "4379770c34e718157f856d938f870ad8179b268e5454f9ff272aad4e43265149  test/test2/proof"))
[ "$out" = "test/test2/proof: OK" ] || exit 2
exit 0
