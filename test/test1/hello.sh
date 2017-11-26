#! /bin/sh
set -x
./bin/M1 -f test/test1/hex.M1 --LittleEndian --Architecture 2 -o test/test1/hold
./bin/hex2 -f elf_headers/elf64.hex2 -f test/test1/hold --LittleEndian --Architecture 2 --BaseAddress 0x00600000 -o test/results/test1-binary --exec_enable

if [ "$(./bin/get_machine)" = "x86_64" ]
then
	./test/results/test1-binary < test/test1/hex0.hex0 > test/test1/proof1
	r=$?
	[ $r = 0 ] || exit 1
	out=$(sha256sum -c test/test1/proof1.answer)
	[ "$out" = "test/test1/proof1: OK" ] || exit 2
	./bin/exec_enable test/test1/proof1
	./test/test1/proof1 < test/test1/hex1.hex0 > test/test1/proof2
	r=$?
	[ $r = 0 ] || exit 3
	out=$(sha256sum -c test/test1/proof2.answer)
	[ "$out" = "test/test1/proof2: OK" ] || exit 4
fi
exit 0
