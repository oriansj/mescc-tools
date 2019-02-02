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

set -eux
{
	./bin/M1 -f test/test8/sample.M1 --LittleEndian --Architecture 2
	./bin/M1 -f test/test8/sample.M1 --BigEndian --Architecture 2
	./bin/M1 -f test/test8/sample.M1 --LittleEndian --Architecture 1
	./bin/M1 -f test/test8/sample.M1 --BigEndian --Architecture 1
} >| test/test8/proof

out=$(sha256sum -c test/test8/proof.answer)
[ "$out" = "test/test8/proof: OK" ] || exit 2

./bin/hex2 -f test/test8/proof --BigEndian --Architecture 0 --BaseAddress 0 -o test/results/test8-binary

exit 0
