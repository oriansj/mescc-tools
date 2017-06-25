#! /bin/bash
set -x
./bin/M0 -f test/test1/hex.M0 --LittleEndian >| test/test1/hold
./bin/hex2 -f test/test1/elf64 -f test/test1/hold --LittleEndian --Architecture 1 --BaseAddress 0x00600000 >| test/results/test1-binary
chmod u+x test/results/test1-binary
./test/results/test1-binary < test/test1/example_test.hex > test/test1/proof
r=$?
[ $r = 0 ] || exit 1
out=$(sha256sum -c <(echo "4379770c34e718157f856d938f870ad8179b268e5454f9ff272aad4e43265149  test/test1/proof"))
[ "$out" = "test/test1/proof: OK" ] || exit 2
exit 0
