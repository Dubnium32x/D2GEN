#!/bin/bash
# D2GEN Linux Build Script
# Requires: dmd (modern version), git, make

# Configuration
DMD=$(which dmd)  # Use system DMD
OUTPUT="bin/d2gen"
SOURCES=(
    "source/main.d"
    "source/compiler/lexer.d"
    "source/compiler/parser.d"
    "source/compiler/ast.d"
    "source/compiler/codegen.d"
    "source/compiler/semantic.d"
)

# Clean previous build
echo "Cleaning..."
rm -f ${OUTPUT} *.o

# Build command
echo "Compiling with ${DMD}..."
${DMD} -of=${OUTPUT} "${SOURCES[@]}" -g -w -version=LinuxBuild

# Verify
if [ -f "${OUTPUT}" ]; then
    echo -e "\033[32m✓ Build successful!\033[0m"
    echo "Output: $(realpath ${OUTPUT})"
else
    echo -e "\033[31m✗ Build failed!\033[0m"
    exit 1
fi
