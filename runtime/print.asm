; print.asm - Implementation of print function for D2GEN
; This function prints a string + value to the console
; Arguments:
;   4(SP) - Address of string
;   8(SP) - Value to print (int, bool, etc.)

print:
    ; Function prologue
    link    A6, #0          ; Setup stack frame
    movem.l D0-D7/A0-A5, -(SP) ; Save all registers

    ; Print the string part
    move.l  8(A6), A1       ; Get string address from first parameter
    move.l  #13, D0         ; Task 13 - print string without newline
    trap    #15             ; Call OS

    ; Print the value (second parameter)
    move.l  12(A6), D1      ; Get the value to print
    move.l  #3, D0          ; Task 3 - display number in D1.L
    trap    #15             ; Call OS

    ; Print a newline
    move.l  #11, D0         ; Task 11 - print CR/LF
    trap    #15             ; Call OS

    ; Function epilogue
    movem.l (SP)+, D0-D7/A0-A5 ; Restore all registers
    unlk    A6              ; Restore stack frame
    rts                     ; Return from subroutine

; Simplified version for a single string argument
printString:
    ; Function prologue
    link    A6, #0          ; Setup stack frame
    movem.l D0-D7/A0-A5, -(SP) ; Save all registers

    ; Print the string part
    move.l  8(A6), A1       ; Get string address from parameter
    move.l  #13, D0         ; Task 13 - print string without newline
    trap    #15             ; Call OS

    ; Print a newline
    move.l  #11, D0         ; Task 11 - print CR/LF
    trap    #15             ; Call OS

    ; Function epilogue
    movem.l (SP)+, D0-D7/A0-A5 ; Restore all registers
    unlk    A6              ; Restore stack frame
    rts                     ; Return from subroutine
