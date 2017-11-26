#! /bin/sh

HEX2=${HEX2-hex2}
M1=${M1-M1}
MES_PREFIX=${MES_PREFIX-../mes}
MESCC_TOOLS_SEED=${MESCC_TOOLS_SEED-../mescc-tools-seed}
MES_SEED=${MES_SEED-../mes-seed}

$M1 --LittleEndian --Architecture=1\
    -f $MES_PREFIX/stage0/x86.M1\
    -f $MESCC_TOOLS_SEED/hex2.M1\
    > hex2.hex2
$M1 --LittleEndian --Architecture=1\
    -f $MES_PREFIX/stage0/x86.M1\
    -f $MES_SEED/crt1.M1\
    > crt1.hex2
$M1 --LittleEndian --Architecture=1\
    -f $MES_PREFIX/stage0/x86.M1\
    -f $MES_SEED/libc-mes+tcc.M1\
    > libc-mes+tcc.hex2

$HEX2 --LittleEndian --Architecture=1 --BaseAddress=0x1000000\
      -f $MES_PREFIX/stage0/elf32-header.hex2\
      -f crt1.hex2\
      -f libc-mes+tcc.hex2\
      -f hex2.hex2\
      -f $MES_PREFIX/stage0/elf32-footer-single-main.hex2\
      > hex2
chmod +x hex2

$M1 --LittleEndian --Architecture=1\
    -f $MES_PREFIX/stage0/x86.M1\
    -f $MESCC_TOOLS_SEED/M1.M1\
    > hex2.hex2

./hex2 --LittleEndian --Architecture=1 --BaseAddress=0x1000000\
       -f $MES_PREFIX/stage0/elf32-header.hex2\
       -f crt1.hex2\
       -f libc-mes+tcc.hex2\
       -f M1.hex2\
       -f $MES_PREFIX/stage0/elf32-footer-single-main.hex2\
       > M1

chmod +x M1
