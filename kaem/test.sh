#!/bin/bash

pwd > kaem/test/test07/answer # Generate test07 answer

for i in $(seq 15) ; do
    TEST=$(printf "%02d" $i)
    bin/kaem -f kaem/test/test${TEST}/kaem.test > kaem/test/test${TEST}/output 2>&1
    if cmp kaem/test/test${TEST}/answer kaem/test/test${TEST}/output > /dev/null 2>&1 ; then
        printf "%s: PASSED\\n" "${TEST}"
    else
        printf "%s: FAILED\\n" "${TEST}"
    fi
done
