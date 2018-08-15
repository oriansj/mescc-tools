#! /bin/sh
## Copyright (C) 2017 Jeremiah Orians
## This file is part of stage0.
##
## stage0 is free software: you an redistribute it and/or modify
## it under the terms of the GNU General Public License as published by
## the Free Software Foundation, either version 3 of the License, or
## (at your option) any later version.
##
## stage0 is distributed in the hope that it will be useful,
## but WITHOUT ANY WARRANTY; without even the implied warranty of
## MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
## GNU General Public License for more details.
##
## You should have received a copy of the GNU General Public License
## along with stage0.  If not, see <http://www.gnu.org/licenses/>.

set -x
./bin/blood-elf -f test/test9/M1.M1 -o test/test9/footer.M1
./bin/M1 --LittleEndian --Architecture 1 -f test/test9/x86.M1 -f test/test9/M1.M1 -f test/test9/footer.M1 -o test/test9/M1.hex2
./bin/hex2 --LittleEndian --Architecture 1 --BaseAddress 0x1000000 -f elf_headers/elf32-debug.hex2 -f test/test9/crt1.hex2 -f test/test9/libc-mes+tcc.hex2 -f test/test9/M1.hex2 -o test/results/test9-binary --exec_enable
exit 0
