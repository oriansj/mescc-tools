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
./bin/blood-elf -f test/test11/hello.M1 -o test/test11/footer.M1 || exit 1
./bin/M1 --LittleEndian --Architecture 40 -f test/test11/hello.M1 -f test/test11/footer.M1 -o test/test11/hello.hex2 || exit 2
./bin/hex2 --LittleEndian --Architecture 40 --BaseAddress 0x10000 -f elf_headers/elf32-ARM-debug.hex2 -f test/test11/hello.hex2 -o test/results/test11-binary --exec_enable || exit 3
exit 0
