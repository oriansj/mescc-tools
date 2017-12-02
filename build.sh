#! /bin/sh

HEX2=${HEX2-hex2}
M1=${M1-M1}
BLOOD_ELF=${BLOOD_ELF-blood-elf}
MES_PREFIX=${MES_PREFIX-../mes}
MESCC_TOOLS_SEED=${MESCC_TOOLS_SEED-../mescc-tools-seed}
MES_SEED=${MES_SEED-../mes-seed}

# crt1
$M1 --LittleEndian --Architecture=1\
    -f $MES_PREFIX/stage0/x86.M1\
    -f $MES_SEED/crt1.M1\
    -o crt1.hex2

# mlibc
$M1 --LittleEndian --Architecture=1\
    -f $MES_PREFIX/stage0/x86.M1\
    -f $MES_SEED/libc-mes+tcc.M1\
    -o libc-mes+tcc.hex2

# blood-elf
$M1 --LittleEndian --Architecture=1\
    -f $MES_PREFIX/stage0/x86.M1\
    -f $MESCC_TOOLS_SEED/blood-elf.M1\
    -o blood-elf.hex2

$BLOOD_ELF\
    -f $MES_PREFIX/stage0/x86.M1\
    -f $MESCC_TOOLS_SEED/blood-elf.M1\
    -f $MES_SEED/libc-mes+tcc.M1\
    -o blood-elf-blood-elf-footer.M1

$M1 --LittleEndian --Architecture=1\
    -f blood-elf-blood-elf-footer.M1\
    -o blood-elf-blood-elf-footer.hex2

$HEX2 --LittleEndian --Architecture=1 --BaseAddress=0x1000000\
       -f $MES_PREFIX/stage0/elf32-header.hex2\
       -f crt1.hex2\
       -f libc-mes+tcc.hex2\
       -f blood-elf.hex2\
       -f blood-elf-blood-elf-footer.hex2\
       --exec_enable\
       -o blood-elf

# hex2
$M1 --LittleEndian --Architecture=1\
    -f $MES_PREFIX/stage0/x86.M1\
    -f $MESCC_TOOLS_SEED/hex2.M1\
    -o hex2.hex2
$M1 --LittleEndian --Architecture=1\
    -f $MES_PREFIX/stage0/x86.M1\
    -f $MES_SEED/libc-mes+tcc.M1\
    -o  hex2

$HEX2 --LittleEndian --Architecture=1 --BaseAddress=0x1000000\
      -f $MES_PREFIX/stage0/elf32-header.hex2\
      -f crt1.hex2\
      -f libc-mes+tcc.hex2\
      -f hex2.hex2\
      -f $MES_PREFIX/stage0/elf32-footer-single-main.hex2\
       --exec_enable\
      -o hex2

# M1
$M1 --LittleEndian --Architecture=1\
    -f $MES_PREFIX/stage0/x86.M1\
    -f $MESCC_TOOLS_SEED/M1.M1\
    -o M1.hex2

./blood-elf\
    -f $MES_PREFIX/stage0/x86.M1\
    -f $MESCC_TOOLS_SEED/M1.M1\
    -f $MES_SEED/libc-mes+tcc.M1\
    -o M1-blood-elf-footer.M1

$M1 --LittleEndian --Architecture=1\
    -f M1-blood-elf-footer.M1\
    -o M1-blood-elf-footer.hex2

./hex2 --LittleEndian --Architecture=1 --BaseAddress=0x1000000\
       -f $MES_PREFIX/stage0/elf32-header.hex2\
       -f crt1.hex2\
       -f libc-mes+tcc.hex2\
       -f M1.hex2\
       -f M1-blood-elf-footer.hex2\
       --exec_enable\
       -o M1
