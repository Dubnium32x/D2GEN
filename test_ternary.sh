#!/bin/bash
# Run tests to see if the ternary operator is working

echo "Compiling ternary_test.dl"
./bin/d2gen tests/ternary_test.dl

echo "Output assembly file:"
cat output/generated.asm
