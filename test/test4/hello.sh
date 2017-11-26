#! /bin/sh
set -x
./bin/M1 -f test/test4/MES_defs.M1 -f test/test4/mini-libc-mes.M1 -f test/test4/hello.M1 --LittleEndian --Architecture 1 -o test/test4/hold
./bin/hex2 -f elf_headers/elf32.hex2 -f test/test4/hold --LittleEndian --Architecture 1 --BaseAddress 0x8048000 -o test/results/test4-binary --exec_enable
if [ "$(./bin/get_machine)" = "x86_64" ]
then
	out=$(./test/results/test4-binary 2>&1)
	r=$?
	[ $r = 42 ] || exit 1
	[ "$out" = "Hello, Mescc!" ] || exit 2
fi
exit 0
