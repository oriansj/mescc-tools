#! /bin/sh
set -x
./bin/M1 -f test/test4/MES_defs.M1 -f test/test4/mini-libc-mes.M1 -f test/test4/hello.M1 --LittleEndian --Architecture 1 >| test/test4/hold
./bin/hex2 -f test/test4/elf32.hex2 -f test/test4/hold --LittleEndian --Architecture 1 --BaseAddress 0x8048000 >| test/results/test4-binary
chmod +x test/results/test4-binary
out=$(./test/results/test4-binary 2>&1)
r=$?
[ $r = 42 ] || exit 1
[ "$out" = "Hello, Mescc!" ] || exit 2
exit 0
