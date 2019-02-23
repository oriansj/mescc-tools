#! /bin/sh
## Copyright (C) 2017 Jeremiah Orians
## This file is part of stage0.
##
## stage0 is free software: you can redistribute it and/or modify
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
./bin/M1 -f test/test4/MES_defs.M1 -f test/test4/mini-libc-mes.M1 -f test/test4/hello.M1 --LittleEndian --architecture x86 -o test/test4/hold
./bin/hex2 -f elf_headers/elf32.hex2 -f test/test4/hold --LittleEndian --architecture x86 --BaseAddress 0x8048000 -o test/results/test4-binary --exec_enable
if [ "$(./bin/get_machine)" = "x86_64" ]
then
	out=$(./test/results/test4-binary 2>&1)
	r=$?
	[ $r = 42 ] || exit 1
	[ "$out" = "Hello, Mescc!" ] || exit 2
fi
exit 0
