** GENERATED CODE USING DLANG AND D2GEN COMPILER **
        ORG $1000
        jsr __global_init
        jmp main

; ===== FUNCTION DEFINITIONS =====
__global_init:
        rts
main:
        ; Function prologue
        link A6, #0  ; Setup stack frame (saves A6 and sets up new frame in one instruction)
        lea strAA, A1  ; Load effective address
        move.l A1, -(SP)
        bsr writeln
        add.l #4, SP
        lea p, A1  ; Load effective address
        move.l 0(A1), D1  ; Optimized field access with direct displacement
        lea p, A2  ; Load effective address
        move.l 0(A2), D2  ; Optimized field access with direct displacement
        move.l D2, D1
        move.l D1, -(SP)
        add.l #4, SP
        move.l D0, D3
        move.l D3, -(SP)
        lea strAB, A3  ; Load effective address
        move.l A3, -(SP)
        bsr writeln
        add.l #8, SP
        lea p, A1  ; Load effective address
        move.l 4(A1), D1  ; Optimized field access with direct displacement
        lea p, A2  ; Load effective address
        move.l 4(A2), D2  ; Optimized field access with direct displacement
        move.l D2, D1
        move.l D1, -(SP)
        add.l #4, SP
        move.l D0, D3
        move.l D3, -(SP)
        lea strAC, A3  ; Load effective address
        move.l A3, -(SP)
        bsr writeln
        add.l #8, SP
        bsr complex_expr
        lea strAD, A1  ; Load effective address
        move.l A1, -(SP)
        bsr writeln
        add.l #4, SP
        ; Function epilogue
        unlk A6       ; Restore stack frame (restores A6 and SP in one instruction)
        rts           ; Return from subroutine

; ===== DATA SECTION =====
; String literals
strAA:
        dc.b 'Testing mixin functionality with parameters and structs', 0
strAC:
        dc.b 'Scaled y:', 0
strAB:
        dc.b 'Scaled x:', 0
strAD:
        dc.b 'Mixin test completed', 0
; Scalar and struct variables
p:    ds.l 2
; Array labels
; Loop variables

        SIMHALT

; ===== RUNTIME FUNCTIONS =====
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
writeln:
        ; Function prologue
        link    A6, #0          ; Setup stack frame
        movem.l D0-D7/A0-A5, -(SP) ; Save all registers

        ; Get the string address from the parameter
        move.l  8(A6), A1       ; Get string address from parameter
        move.l  #13, D0         ; Task 13 - print string without newline
        trap    #15             ; Call OS

        ; Check if there's a second parameter
        move.l  12(A6), D1      ; Get the second parameter (if any)
        cmpi.l  #0, D1          ; Check if it's zero (no second parameter)
        beq     .no_second_param

        ; Print a separator
        lea     separator, A1  ; Load effective address
        move.l  #13, D0
        trap    #15

        ; Print the second value
        move.l  12(A6), D1
        move.l  #3, D0          ; Task 3 - display number in D1.L
        trap    #15

        ; Check for third parameter (for structs with multiple fields)
        move.l  16(A6), D1
        cmpi.l  #0, D1
        beq     .no_third_param

        ; Print another separator and the third value
        lea     separator, A1  ; Load effective address
        move.l  #13, D0
        trap    #15

        ; Print the third value
        move.l  16(A6), D1
        move.l  #3, D0
        trap    #15

.no_third_param:
.no_second_param:
        ; Print a newline
        move.l  #11, D0         ; Task 11 - print CR/LF
        trap    #15             ; Call OS

        ; Function epilogue
        movem.l (SP)+, D0-D7/A0-A5 ; Restore all registers
        unlk    A6              ; Restore stack frame
        rts                     ; Return from subroutine
separator:
        dc.b ' ', 0
complex_expr:
        ; Function prologue
        link    A6, #0          ; Setup stack frame
        movem.l D0-D7/A0-A5, -(SP) ; Save all registers

        ; Print point struct contents
        lea     strPoint, A1    ; Load struct name
        move.l  #13, D0         ; Task 13 - print string without newline
        trap    #15             ; Call OS

        ; Print x value
        move.l  #11, D0         ; Task 11 - print CR/LF
        trap    #15             ; Call OS
        lea     strX, A1        ; Load 'x:' string
        move.l  #13, D0         ; Task 13 - print string without newline
        trap    #15             ; Call OS
        lea     p, A0           ; Load p struct address
        move.l  0(A0), D1       ; Get p.x value
        move.l  #3, D0          ; Task 3 - display number in D1.L
        trap    #15             ; Call OS

        ; Print y value
        move.l  #11, D0         ; Task 11 - print CR/LF
        trap    #15             ; Call OS
        lea     strY, A1        ; Load 'y:' string
        move.l  #13, D0         ; Task 13 - print string without newline
        trap    #15             ; Call OS
        lea     p, A0           ; Load p struct address
        move.l  4(A0), D1       ; Get p.y value
        move.l  #3, D0          ; Task 3 - display number in D1.L
        trap    #15             ; Call OS
        move.l  #11, D0         ; Task 11 - print CR/LF
        trap    #15             ; Call OS

        ; Function epilogue
        movem.l (SP)+, D0-D7/A0-A5 ; Restore all registers
        unlk    A6              ; Restore stack frame
        rts                     ; Return from subroutine

strPoint:
        dc.b 'Point contents:', 0
strX:
        dc.b 'x: ', 0
strY:
        dc.b 'y: ', 0
        END