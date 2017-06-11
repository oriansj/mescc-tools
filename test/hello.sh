#! /bin/sh
set -x
bin/hex2 -f stage0/elf32.hex2  -f test/data/mini-libc-mes.hex2 -f test/data/hello.hex2 --LittleEndian --Architecture 1 --BaseAddress 0x8048000 > hello
chmod +x hello
out=$(./hello 2>&1)
r=$?
[ $r = 42 ] || exit 1
[ "$out" = "Hello, Mescc!" ] || exit 2
exit 0
