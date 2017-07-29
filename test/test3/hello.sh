#! /bin/sh
set -x
./bin/M1 -f test/test3/defs -f test/test3/lisp.s --BigEndian --Architecture 0 >| test/test3/hold
./bin/hex2 -f test/test3/hold --BigEndian --Architecture 0 --BaseAddress 0 -o test/results/test3-binary
