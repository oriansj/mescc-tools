#! /bin/sh
# Copyright © 2017 Jan Nieuwenhuizen <janneke@gnu.org>
# Copyright © 2017 Jeremiah Orians
#
# This file is part of mescc-tools.
#
# mescc-tools is free software; you can redistribute it and/or modify it
# under the terms of the GNU General Public License as published by
# the Free Software Foundation; either version 3 of the License, or (at
# your option) any later version.
#
# mescc-tools is distributed in the hope that it will be useful, but
# WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with mescc-tools.  If not, see <http://www.gnu.org/licenses/>.

set -eux
MES_PREFIX=${MES_PREFIX-../mes}
MES_SEED=${MES_SEED-../mes-seed}
MESCC_TOOLS_SEED=${MESCC_TOOLS_SEED-../mescc-tools-seed}

#########################################
# Phase-0 Build from external binaries  #
# To be replaced by a trusted path      #
#########################################

# Make sure we have our required output directory
[ -e bin ] || mkdir -p bin

# blood-elf
# Create proper debug segment
$MESCC_TOOLS_SEED/blood-elf\
    -f $MESCC_TOOLS_SEED/file_print.M1\
    -f $MESCC_TOOLS_SEED/match.M1\
    -f $MESCC_TOOLS_SEED/numerate_number.M1\
    -f $MESCC_TOOLS_SEED/string.M1\
    -f $MESCC_TOOLS_SEED/blood-elf.M1\
    -o blood-elf-blood-elf-footer.M1

# Build
# M1-macro phase
$MESCC_TOOLS_SEED/M1 --LittleEndian --Architecture 1\
    -f $MES_PREFIX/lib/x86-mes/x86.M1\
    -f $MES_SEED/x86-mes/crt1.S\
    -f $MES_SEED/x86-mes/libc+tcc.S\
    -f $MESCC_TOOLS_SEED/file_print.M1\
    -f $MESCC_TOOLS_SEED/match.M1\
    -f $MESCC_TOOLS_SEED/numerate_number.M1\
    -f $MESCC_TOOLS_SEED/string.M1\
    -f $MESCC_TOOLS_SEED/blood-elf.M1\
    -f blood-elf-blood-elf-footer.M1\
    -o blood-elf.hex2
# Hex2-linker phase
$MESCC_TOOLS_SEED/hex2\
    --LittleEndian\
    --Architecture 1\
    --BaseAddress 0x1000000\
    -f $MES_PREFIX/lib/x86-mes/elf32-header.hex2\
    -f blood-elf.hex2\
    --exec_enable\
    -o bin/blood-elf

# M1
# Create proper debug segment
./bin/blood-elf \
    -f $MESCC_TOOLS_SEED/M1.M1\
    -o M1-footer.M1

# Build
# M1-macro phase
$MESCC_TOOLS_SEED/M1 \
    --LittleEndian\
    --Architecture 1\
    -f $MES_PREFIX/lib/x86-mes/x86.M1\
    -f $MES_SEED/x86-mes/crt1.S\
    -f $MES_SEED/x86-mes/libc+tcc.S\
    -f $MESCC_TOOLS_SEED/file_print.M1\
    -f $MESCC_TOOLS_SEED/match.M1\
    -f $MESCC_TOOLS_SEED/numerate_number.M1\
    -f $MESCC_TOOLS_SEED/string.M1\
    -f $MESCC_TOOLS_SEED/M1.M1\
    -f M1-footer.M1\
    -o M1.hex2
# Hex2-linker phase
$MESCC_TOOLS_SEED/hex2 \
    --LittleEndian\
    --Architecture 1\
    --BaseAddress 0x1000000\
    -f $MES_PREFIX/lib/x86-mes/elf32-header.hex2\
    -f M1.hex2\
    --exec_enable\
    -o bin/M1

# hex2
# Create proper debug segment
./bin/blood-elf\
    -f $MESCC_TOOLS_SEED/hex2.M1\
    -o hex2-footer.M1

# Build
# M1-macro phase
./bin/M1 \
    --LittleEndian\
    --Architecture 1\
    -f $MES_PREFIX/lib/x86-mes/x86.M1\
    -f $MES_SEED/x86-mes/crt1.S\
    -f $MES_SEED/x86-mes/libc+tcc.S\
    -f $MESCC_TOOLS_SEED/file_print.M1\
    -f $MESCC_TOOLS_SEED/match.M1\
    -f $MESCC_TOOLS_SEED/numerate_number.M1\
    -f $MESCC_TOOLS_SEED/string.M1\
    -f $MESCC_TOOLS_SEED/hex2.M1\
    -f hex2-footer.M1\
    -o hex2.hex2
# Hex2-linker phase
$MESCC_TOOLS_SEED/hex2 \
      --LittleEndian\
      --Architecture 1\
      --BaseAddress 0x1000000\
      -f $MES_PREFIX/lib/x86-mes/elf32-header.hex2\
      -f hex2.hex2\
      --exec_enable\
      -o bin/hex2-0

#########################
# Phase-1 Self-host     #
#########################

# blood-elf
# Create proper debug segment
./bin/blood-elf \
    -f $MESCC_TOOLS_SEED/blood-elf.M1\
    -o blood-elf-blood-elf-footer.M1

# Build
# M1-macro phase
./bin/M1 \
    --LittleEndian\
    --Architecture 1\
    -f $MES_PREFIX/lib/x86-mes/x86.M1\
    -f $MES_SEED/x86-mes/crt1.S\
    -f $MES_SEED/x86-mes/libc+tcc.S\
    -f $MESCC_TOOLS_SEED/file_print.M1\
    -f $MESCC_TOOLS_SEED/match.M1\
    -f $MESCC_TOOLS_SEED/numerate_number.M1\
    -f $MESCC_TOOLS_SEED/string.M1\
    -f $MESCC_TOOLS_SEED/blood-elf.M1\
    -f blood-elf-blood-elf-footer.M1\
    -o blood-elf.hex2
# Hex2-linker phase
./bin/hex2-0 \
    --LittleEndian\
    --Architecture 1\
    --BaseAddress 0x1000000\
    -f $MES_PREFIX/lib/x86-mes/elf32-header.hex2\
    -f blood-elf.hex2\
    --exec_enable\
    -o blood-elf

# M1
# Create proper debug segment
./blood-elf \
    -f $MESCC_TOOLS_SEED/M1.M1\
    -o M1-footer.M1

# Build
# M1-macro phase
./bin/M1 \
    --LittleEndian\
    --Architecture 1\
    -f $MES_PREFIX/lib/x86-mes/x86.M1\
    -f $MES_SEED/x86-mes/crt1.S\
    -f $MES_SEED/x86-mes/libc+tcc.S\
    -f $MESCC_TOOLS_SEED/file_print.M1\
    -f $MESCC_TOOLS_SEED/match.M1\
    -f $MESCC_TOOLS_SEED/numerate_number.M1\
    -f $MESCC_TOOLS_SEED/string.M1\
    -f $MESCC_TOOLS_SEED/M1.M1\
    -f M1-footer.M1\
    -o M1.hex2
# Hex2-linker phase
./bin/hex2-0 \
    --LittleEndian\
    --Architecture 1\
    --BaseAddress 0x1000000\
    -f $MES_PREFIX/lib/x86-mes/elf32-header.hex2\
    -f M1.hex2\
    --exec_enable\
    -o bin/M1

# hex2
# Create proper debug segment
./bin/blood-elf\
    -f $MESCC_TOOLS_SEED/hex2.M1\
    -o hex2-footer.M1

# Build
# M1-macro phase
./bin/M1 \
    --LittleEndian\
    --Architecture 1\
    -f $MES_PREFIX/lib/x86-mes/x86.M1\
    -f $MES_SEED/x86-mes/crt1.S\
    -f $MES_SEED/x86-mes/libc+tcc.S\
    -f $MESCC_TOOLS_SEED/file_print.M1\
    -f $MESCC_TOOLS_SEED/match.M1\
    -f $MESCC_TOOLS_SEED/numerate_number.M1\
    -f $MESCC_TOOLS_SEED/string.M1\
    -f $MESCC_TOOLS_SEED/hex2.M1\
    -f hex2-footer.M1\
    -o hex2.hex2
# Hex2-linker phase
./bin/hex2-0 \
      --LittleEndian\
      --Architecture 1\
      --BaseAddress 0x1000000\
      -f $MES_PREFIX/lib/x86-mes/elf32-header.hex2\
      -f hex2.hex2\
      --exec_enable\
      -o bin/hex2

# TODO
touch bin/exec_enable
touch bin/get_machine
touch bin/kaem
