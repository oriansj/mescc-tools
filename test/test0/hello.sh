#! /bin/sh
set -x
bin/hex2 -f test/test0/elf32.hex2  -f test/test0/mini-libc-mes.hex2 -f test/test0/hello.hex2 --LittleEndian --Architecture 1 --BaseAddress 0x8048000 >| test/results/test0-binary
chmod +x test/results/test0
out=$(./test/results/test0 2>&1)
r=$?
[ $r = 42 ] || exit 1
[ "$out" = "Hello, Mescc!" ] || exit 2
exit 0
