#!/bin/bash

for i in $(seq 0 15) ; do
    TEST=$(printf "%02d" $i)
    bin/kaem -f kaem/test/test${TEST}/kaem.test > kaem/test/results/test${TEST}-output 2>&1
done
sha256sum -c kaem/test/test.answers  
