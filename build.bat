@echo off
:: D2GEN Compiler Build Script - Debug Version
:: Save as build.bat in your project root

echo [D2GEN Build System]
echo --------------------

:: 1. Verify DMD exists
set DMD="C:\D\dmd2\windows\bin\dmd.exe"
if not exist %DMD% (
    echo ERROR: D compiler not found at %DMD%
    pause
    exit /b 1
)
echo [OK] DMD found at %DMD%

:: 2. Clean previous build
echo Cleaning previous build...
if exist bin\d2gen.exe (
    del bin\d2gen.exe
    echo [OK] Removed old executable
)
if exist *.obj (
    del *.obj
    echo [OK] Removed object files
)

:: 3. Build command
echo.
echo Compiling sources...
%DMD% -m32 ^
    source\app.d ^
    source\compiler\lexer.d ^
    source\compiler\parser.d ^
    source\compiler\ast.d ^
    source\compiler\semantic.d ^
    source\compiler\codegen.d ^
    -ofbin\d2gen.exe

:: 4. Verify result
if %errorlevel% equ 0 (
    echo.
    echo [OK] Build successful!
    echo Running compiler...
    echo -------------------
    bin\d2gen.exe
) else (
    echo.
    echo [!] Build failed (Error: %errorlevel%)
)

pause
