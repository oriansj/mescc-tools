#! /bin/sh
set -x
./bin/M1 -f test/test3/defs -f test/test3/lisp.s --BigEndian --Architecture 0 -o test/test3/hold
./bin/hex2 -f test/test3/hold --BigEndian --Architecture 0 --BaseAddress 0 -o test/results/test3-binary

if [ "$(./bin/get_machine)" = "knight*" ]
then
	./test/results/test3-binary < test/test3/example.s >| test/test3/proof
	r=$?
	[ $r = 0 ] || exit 1
	out=$(sha256sum -c test/test3/proof.answer)
	[ "$out" = "test/test3/proof: OK" ] || exit 2
fi
exit 0
