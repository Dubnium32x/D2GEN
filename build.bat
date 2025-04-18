@echo off
dmd -m32 -ofbin\d2gen.exe ^
    source\main.d ^
    source\frontend\lexer.d ^
    source\frontend\parser.d ^
    source\backend\codegen.d ^
    source\ast\nodes.d

pause
