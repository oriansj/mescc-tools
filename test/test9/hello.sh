#! /bin/sh
set -x
./bin/blood-elf -f test/test9/M1.M1 -o test/test9/footer.M1
./bin/M1 --LittleEndian --Architecture=1 -f test/test9/x86.M1 -f test/test9/M1.M1 -f test/test9/footer.M1 -o test/test9/M1.hex2
./bin/hex2 --LittleEndian --Architecture=1 --BaseAddress=0x1000000 -f test/test9/elf32-header.hex2 -f test/test9/crt1.hex2 -f test/test9/libc-mes+tcc.hex2 -f test/test9/M1.hex2 -o test/results/test9-binary --exec_enable
exit 0
