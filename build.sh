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
M2=${M2-../M2-Planet}
MESCC_TOOLS_SEED=${MESCC_TOOLS_SEED-../mescc-tools-seed}

#########################################
# Phase-0 Build from external binaries  #
# To be replaced by a trusted path      #
#########################################

# Make sure we have our required output directory
[ -e bin ] || mkdir -p bin

# blood-elf
$M2/bin/M2-Planet \
	-f $M2/functions/exit.c \
	-f $M2/functions/file.c \
	-f functions/file_print.c \
	-f $M2/functions/malloc.c \
	-f $M2/functions/calloc.c \
	-f functions/match.c \
	-f blood-elf.c \
	--debug \
	-o blood-elf.M1 || exit 1

# Build debug footer
$MESCC_TOOLS_SEED/blood-elf-0 \
	-f blood-elf.M1 \
	-o blood-elf-footer.M1 || exit 2

# Macro assemble with libc written in M1-Macro
$MESCC_TOOLS_SEED/M1-0 \
	-f $M2/test/common_x86/x86_defs.M1 \
	-f $M2/functions/libc-core.M1 \
	-f blood-elf.M1 \
	-f blood-elf-footer.M1 \
	--LittleEndian \
	--Architecture 1 \
	-o blood-elf.hex2 || exit 3

# Resolve all linkages
$MESCC_TOOLS_SEED/hex2-0 \
	-f elf_headers/elf32-debug.hex2 \
	-f blood-elf.hex2 \
	--LittleEndian \
	--Architecture 1 \
	--BaseAddress 0x8048000 \
	-o bin/blood-elf-0 \
	--exec_enable || exit 4

# Build
# M1-macro phase
$M2/bin/M2-Planet \
	-f $M2/functions/exit.c \
	-f $M2/functions/file.c \
	-f functions/file_print.c \
	-f $M2/functions/malloc.c \
	-f $M2/functions/calloc.c \
	-f functions/match.c \
	-f functions/numerate_number.c \
	-f functions/string.c \
	-f M1-macro.c \
	--debug \
	-o M1-macro.M1 || exit 5

# Build debug footer
$MESCC_TOOLS_SEED/blood-elf-0 \
	-f M1-macro.M1 \
	-o M1-macro-footer.M1 || exit 6

# Macro assemble with libc written in M1-Macro
$MESCC_TOOLS_SEED/M1-0 \
	-f $M2/test/common_x86/x86_defs.M1 \
	-f $M2/functions/libc-core.M1 \
	-f M1-macro.M1 \
	-f M1-macro-footer.M1 \
	--LittleEndian \
	--Architecture 1 \
	-o M1-macro.hex2 || exit 7

# Resolve all linkages
$MESCC_TOOLS_SEED/hex2-0 \
	-f elf_headers/elf32-debug.hex2 \
	-f M1-macro.hex2 \
	--LittleEndian \
	--Architecture 1 \
	--BaseAddress 0x8048000 \
	-o bin/M1-0 \
	--exec_enable || exit 8

# hex2
$M2/bin/M2-Planet \
	-f $M2/functions/exit.c \
	-f $M2/functions/file.c \
	-f functions/file_print.c \
	-f $M2/functions/malloc.c \
	-f $M2/functions/calloc.c \
	-f functions/match.c \
	-f functions/numerate_number.c \
	-f $M2/functions/stat.c \
	-f hex2_linker.c \
	--debug \
	-o hex2_linker.M1 || exit 9

# Build debug footer
$MESCC_TOOLS_SEED/blood-elf-0 \
	-f hex2_linker.M1 \
	-o hex2_linker-footer.M1 || exit 10

# Macro assemble with libc written in M1-Macro
$MESCC_TOOLS_SEED/M1-0 \
	-f $M2/test/common_x86/x86_defs.M1 \
	-f $M2/functions/libc-core.M1 \
	-f hex2_linker.M1 \
	-f hex2_linker-footer.M1 \
	--LittleEndian \
	--Architecture 1 \
	-o hex2_linker.hex2|| exit 11

# Resolve all linkages
$MESCC_TOOLS_SEED/hex2-0 \
	-f elf_headers/elf32-debug.hex2 \
	-f hex2_linker.hex2 \
	--LittleEndian \
	--Architecture 1 \
	--BaseAddress 0x8048000 \
	-o bin/hex2-0 \
	--exec_enable || exit 12


#########################
# Phase-1 Self-host     #
#########################

# blood-elf
# Build debug footer
./bin/blood-elf-0 \
	-f blood-elf.M1 \
	-o blood-elf-footer.M1 || exit 13

# Macro assemble with libc written in M1-Macro
./bin/M1-0 \
	-f $M2/test/common_x86/x86_defs.M1 \
	-f $M2/functions/libc-core.M1 \
	-f blood-elf.M1 \
	-f blood-elf-footer.M1 \
	--LittleEndian \
	--Architecture 1 \
	-o blood-elf.hex2 || exit 14

# Resolve all linkages
./bin/hex2-0 \
	-f elf_headers/elf32-debug.hex2 \
	-f blood-elf.hex2 \
	--LittleEndian \
	--Architecture 1 \
	--BaseAddress 0x8048000 \
	-o bin/blood-elf \
	--exec_enable || exit 15

# M1-macro
# Build debug footer
./bin/blood-elf \
	-f M1-macro.M1 \
	-o M1-macro-footer.M1 || exit 16

# Macro assemble with libc written in M1-Macro
./bin/M1-0 \
	-f $M2/test/common_x86/x86_defs.M1 \
	-f $M2/functions/libc-core.M1 \
	-f M1-macro.M1 \
	-f M1-macro-footer.M1 \
	--LittleEndian \
	--Architecture 1 \
	-o M1-macro.hex2 || exit 17

# Resolve all linkages
./bin/hex2-0 \
	-f elf_headers/elf32-debug.hex2 \
	-f M1-macro.hex2 \
	--LittleEndian \
	--Architecture 1 \
	--BaseAddress 0x8048000 \
	-o bin/M1 \
	--exec_enable || exit 18

# hex2
# Build debug footer
./bin/blood-elf \
	-f hex2_linker.M1 \
	-o hex2_linker-footer.M1 || exit 19

# Macro assemble with libc written in M1-Macro
./bin/M1 \
	-f $M2/test/common_x86/x86_defs.M1 \
	-f $M2/functions/libc-core.M1 \
	-f hex2_linker.M1 \
	-f hex2_linker-footer.M1 \
	--LittleEndian \
	--Architecture 1 \
	-o hex2_linker.hex2|| exit 20

# Resolve all linkages
./bin/hex2-0 \
	-f elf_headers/elf32-debug.hex2 \
	-f hex2_linker.hex2 \
	--LittleEndian \
	--Architecture 1 \
	--BaseAddress 0x8048000 \
	-o bin/hex2 \
	--exec_enable || exit 21

# Clean up after ourself
rm -f bin/blood-elf-0 bin/M1-0 bin/hex2-0

# Build pieces that were not needed in bootstrap
# but are generally useful

# get_machine
$M2/bin/M2-Planet \
	-f $M2/functions/exit.c \
	-f $M2/functions/file.c \
	-f functions/file_print.c \
	-f $M2/functions/malloc.c \
	-f $M2/functions/calloc.c \
	-f $M2/functions/uname.c \
	-f get_machine.c \
	--debug \
	-o get_machine.M1 || exit 22

# Build debug footer
./bin/blood-elf \
	-f get_machine.M1 \
	-o get_machine-footer.M1 || exit 23

# Macro assemble with libc written in M1-Macro
./bin/M1 \
	-f $M2/test/common_x86/x86_defs.M1 \
	-f $M2/functions/libc-core.M1 \
	-f get_machine.M1 \
	-f get_machine-footer.M1 \
	--LittleEndian \
	--Architecture 1 \
	-o get_machine.hex2 || exit 24

# Resolve all linkages
./bin/hex2 \
	-f elf_headers/elf32-debug.hex2 \
	-f get_machine.hex2 \
	--LittleEndian \
	--Architecture 1 \
	--BaseAddress 0x8048000 \
	-o bin/get_machine \
	--exec_enable || exit 25

# exec_enable
$M2/bin/M2-Planet \
	-f $M2/functions/file.c \
	-f functions/file_print.c \
	-f $M2/functions/exit.c \
	-f $M2/functions/stat.c \
	-f exec_enable.c \
	--debug \
	-o exec_enable.M1 || exit 26

# Build debug footer
./bin/blood-elf \
	-f exec_enable.M1 \
	-o exec_enable-footer.M1 || exit 27

# Macro assemble with libc written in M1-Macro
./bin/M1 \
	-f $M2/test/common_x86/x86_defs.M1 \
	-f $M2/functions/libc-core.M1 \
	-f exec_enable.M1 \
	-f exec_enable-footer.M1 \
	--LittleEndian \
	--Architecture 1 \
	-o exec_enable.hex2 || exit 28

# Resolve all linkages
./bin/hex2 \
	-f elf_headers/elf32-debug.hex2 \
	-f exec_enable.hex2 \
	--LittleEndian \
	--Architecture 1 \
	--BaseAddress 0x8048000 \
	-o bin/exec_enable \
	--exec_enable || exit 29

# TODO
# kaem
