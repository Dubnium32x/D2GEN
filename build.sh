#!/bin/bash
# D2GEN Linux Build Script
# Requires: dmd (modern version), git, make

# Determine script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Configuration
DMD=$(which dmd)  # Use system DMD
OUTPUT="${SCRIPT_DIR}/bin/d2gen"
MAIN_DIR="${SCRIPT_DIR}/tests/simple_program"
D2GEN_DIR="${SCRIPT_DIR}/source"
SOURCES=(
    "${D2GEN_DIR}/gen_compiler.d"
    "${D2GEN_DIR}/compiler/lexer.d"
    "${D2GEN_DIR}/compiler/parser.d"
    "${D2GEN_DIR}/compiler/ast.d"
    "${D2GEN_DIR}/compiler/codegen.d"
    "${D2GEN_DIR}/compiler/semantic.d"
    "${D2GEN_DIR}/compiler/instructions.d"
)

# Clean previous build
echo "Cleaning..."
rm -f "${OUTPUT}" "${SCRIPT_DIR}"/*.o "${MAIN_DIR}/output.s"

# Check for gen_compiler file
if [ ! -f "${D2GEN_DIR}/gen_compiler.d" ]; then
    echo -e "\033[31m✗ gen_compiler.d not found!\033[0m"
    exit 1
fi
echo -e "\033[32m✓ gen_compiler.d found!\033[0m"

# Build gen_compiler
echo "Compiling gen_compiler with ${DMD}..."
${DMD} -of="${OUTPUT}" "${SOURCES[@]}" -g -w -version=LinuxBuild

# Verify build
if [ -f "${OUTPUT}" ]; then
    echo -e "\033[32m✓ Build successful!\033[0m"
else
    echo -e "\033[31m✗ Build failed!\033[0m"
    exit 1
fi

# Run gen_compiler to generate assembly
echo "Running gen_compiler to generate assembly..."
"${OUTPUT}" "${MAIN_DIR}"

# Verify output
if [ -f "${MAIN_DIR}/output.s" ]; then
    echo -e "\033[32m✓ Assembly generated: ${MAIN_DIR}/output.s\033[0m"
else
    echo -e "\033[31m✗ Assembly generation failed!\033[0m"
    exit 1
fi