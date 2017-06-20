#! /bin/bash
./bin/M0 -f test/test1/hex.M0 --LittleEndian >| test/test1/hold
cat test/test1/elf64 test/test1/hold >| test/test1/example.hex2
./bin/hex2 -f test/test1/example.hex2 --LittleEndian --Architecture 1 --BaseAddress 0x00600000 >| test/test1/example
chmod u+x test/test1/example
./test/test1/example < test/test1/example_test.hex > test/test1/proof
