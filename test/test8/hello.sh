#! /bin/sh
set -x
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
