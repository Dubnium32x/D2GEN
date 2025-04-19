#!/usr/bin/env bash
# Exit immediately if a command exits with a non-zero status
set -e

# Ensure output directory exists
mkdir -p bin

# Compile D sources into a 32-bit executable named bin/d2gen.exe
dmd -m32 -ofbin/d2gen.exe \
    source/main.d \
    source/frontend/lexer.d \
    source/frontend/parser.d \
    source/backend/codegen.d \
    source/ast/nodes.d

# Pause until the user presses any key
read -n1 -r -p "Press any key to continue..." key
echo
