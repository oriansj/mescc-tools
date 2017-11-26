#! /bin/sh
set -x
bin/hex2 -f elf_headers/elf32.hex2  -f test/test0/mini-libc-mes.hex2 -f test/test0/hello.hex2 --LittleEndian --Architecture 1 --BaseAddress 0x8048000 -o test/results/test0-binary --exec_enable
if [ "$(./bin/get_machine)" = "x86_64" ]
then
	out=$(./test/results/test0-binary 2>&1)
	r=$?
	[ $r = 42 ] || exit 1
	[ "$out" = "Hello, Mescc!" ] || exit 2
fi
exit 0
