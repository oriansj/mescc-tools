#!/bin/sh
set -eu

check_no_crash()
{
	name=$1
	shift

	set +e
	"$@" >/dev/null 2>&1
	status=$?
	set -e

	if [ "$status" -ge 128 ]; then
		echo "$name crashed with status $status"
		exit 1
	fi
}

check_stdout()
{
	name=$1
	shift

	out="/tmp/mescc-tools-cli-fuzz-stdout"
	"$@" > "$out"

	if [ ! -s "$out" ]; then
		echo "$name did not write to stdout"
		exit 1
	fi
}

hex2_input="/tmp/mescc-tools-cli-fuzz.hex2"
printf '00\n' > "$hex2_input"

check_no_crash hex2-missing-short-file ./bin/hex2 -f
check_no_crash hex2-missing-long-file ./bin/hex2 --file
check_no_crash hex2-missing-short-output ./bin/hex2 -o
check_no_crash hex2-missing-long-output ./bin/hex2 --output
check_no_crash hex2-missing-short-architecture ./bin/hex2 -A
check_no_crash hex2-missing-long-architecture ./bin/hex2 --architecture
check_no_crash hex2-missing-short-base-address ./bin/hex2 -B
check_no_crash hex2-missing-long-base-address ./bin/hex2 --base-address

check_no_crash blood-elf-missing-short-file ./bin/blood-elf --little-endian -f
check_no_crash blood-elf-missing-long-file ./bin/blood-elf --little-endian --file
check_no_crash blood-elf-missing-short-output ./bin/blood-elf --little-endian -o
check_no_crash blood-elf-missing-long-output ./bin/blood-elf --little-endian --output
check_no_crash blood-elf-missing-entry ./bin/blood-elf --little-endian --entry

check_stdout hex2-missing-short-output-stdout ./bin/hex2 -f "$hex2_input" -o
check_stdout hex2-missing-long-output-stdout ./bin/hex2 -f "$hex2_input" --output
check_stdout blood-elf-missing-short-output-stdout ./bin/blood-elf --little-endian -f test/test11/hello.M1 -o
check_stdout blood-elf-missing-long-output-stdout ./bin/blood-elf --little-endian -f test/test11/hello.M1 --output
