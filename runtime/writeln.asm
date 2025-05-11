// This file contains implementation for writeln function to complement print
// in the D2GEN runtime library

// writeln function implementation - prints a string followed by a newline
writeln:
        ; Function prologue
        link    A6, #0          ; Setup stack frame
        movem.l D0-D7/A0-A5, -(SP) ; Save all registers

        ; Print the string part
        move.l  8(A6), A1       ; Get string address from first parameter
        move.l  #13, D0         ; Task 13 - print string without newline
        trap    #15             ; Call OS

        ; Print a newline
        move.l  #11, D0         ; Task 11 - print CR/LF
        trap    #15             ; Call OS

        ; Function epilogue
        movem.l (SP)+, D0-D7/A0-A5 ; Restore all registers
        unlk    A6              ; Restore stack frame
        rts                     ; Return from subroutine

// complex_expr function implementation - a placeholder for complex expressions
complex_expr:
        ; Function prologue
        link    A6, #0          ; Setup stack frame
        movem.l D0-D7/A0-A5, -(SP) ; Save all registers

        ; Just return the value in D0 (no-op function)
        moveq   #0, D0          ; Set default return value to 0

        ; Function epilogue
        movem.l (SP)+, D0-D7/A0-A5 ; Restore all registers
        unlk    A6              ; Restore stack frame
        rts                     ; Return from subroutine
