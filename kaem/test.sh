#!/bin/bash
# Copyright (C) 2020 fosslinux
# This file is part of mescc-tools.
#
# mescc-tools is free software: you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation, either version 3 of the License, or
# (at your option) any later version.
#
# mescc-tools is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with mescc-tools.  If not, see <http://www.gnu.org/licenses/>.

echo "Starting kaem tests"
for i in $(seq 0 15) ; do
	TEST=$(printf "%02d" $i)
	../bin/kaem -f "test/test${TEST}/kaem.test" >| "test/results/test${TEST}-output" 2>&1
done
. ../sha256.sh
sha256_check test/test.answers
echo "kaem tests complete"
