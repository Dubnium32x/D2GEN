#!/bin/bash
# Build script for D2GEN in Cygwin environment

# Convert to Windows paths if needed
DMD_PATH=$(which dmd)
if [[ -z "$DMD_PATH" ]]; then
    echo "DMD compiler not found. Make sure it's installed and in your PATH."
    exit 1
fi

# Ensure the bin directory exists
mkdir -p bin

# Build the project with correct module handling for Windows paths
echo "Building D2GEN with $DMD_PATH..."
$DMD_PATH -m32 -ofbin/d2gen.exe \
    source/main.d \
    source/frontend/lexer.d \
    source/frontend/parser.d \
    source/backend/codegen.d \
    source/ast/nodes.d \
    source/globals/globals.d \
    source/ast/conditional_expr.d

# Check if the build was successful
if [ $? -eq 0 ]; then
    echo "Build successful! Executable created at bin/d2gen.exe"
    # Make the executable accessible for testing
    chmod +x bin/d2gen.exe
else
    echo "Build failed. Please check the errors above."
fi

# Keep the terminal window open in Windows
read -p "Press [Enter] to continue..."
