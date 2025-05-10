** GENERATED CODE USING DLANG AND D2GEN COMPILER **
        ORG $1000
        jsr __global_init
        jmp main

; ===== FUNCTION DEFINITIONS =====
__global_init:
        moveq #100, D1  ; Optimized small constant
        move.l D1, MAX_SCORE
        moveq #0, D1  ; Optimized small constant
        move.l D1, MIN_SCORE
        moveq #99, D1  ; Optimized small constant
        move.b D1, MAX_LEVEL
        moveq #1, D1  ; Boolean value
        move.l D1, IS_ENABLED
        move.l MAX_SCORE, D1
        moveq #2, D2  ; Optimized small constant
        move.l D1, D0
        muls D2, D0
        move.l D0, DOUBLE_MAX
        move.l MAX_SCORE, D1
        moveq #2, D2  ; Optimized small constant
        move.l D1, D3  ; Prepare for division by 2
        asr.l #1, D3  ; Optimized division by power of 2 (2)
        move.l D3, HALF_MAX
        ; Constant variable: PUBLIC_CONST
        moveq #42, D1  ; Optimized small constant
        move.l D1, PUBLIC_CONST
        ; Constant variable: PRIVATE_CONST
        moveq #84, D1  ; Optimized small constant
        move.l D1, PRIVATE_CONST
        rts
testConstModification:
        ; Function prologue
        link A6, #0  ; Setup stack frame (saves A6 and sets up new frame in one instruction)
        move.l #200, D1
        move.l D1, MAX_SCORE
        ; Function epilogue
        unlk A6       ; Restore stack frame (restores A6 and SP in one instruction)
        rts           ; Return from subroutine
useConstants:
        ; Function prologue
        link A6, #0  ; Setup stack frame (saves A6 and sets up new frame in one instruction)
        move.l MAX_SCORE, D1
        move.l D1, score
        move.l IS_ENABLED, D1
        move.l D1, enabled
        move.l MAX_SCORE, D1
        move.l D1, -(SP)
        lea strAA, A2  ; Load effective address
        move.l A2, -(SP)
        bsr print
        add.l #8, SP
        move.l MIN_SCORE, D1
        move.l D1, -(SP)
        lea strAB, A2  ; Load effective address
        move.l A2, -(SP)
        bsr print
        add.l #8, SP
        move.l MAX_LEVEL, D1
        move.l D1, -(SP)
        lea strAC, A2  ; Load effective address
        move.l A2, -(SP)
        bsr print
        add.l #8, SP
        move.l IS_ENABLED, D1
        move.l D1, -(SP)
        lea strAD, A2  ; Load effective address
        move.l A2, -(SP)
        bsr print
        add.l #8, SP
        move.l DOUBLE_MAX, D1
        move.l D1, -(SP)
        lea strAE, A2  ; Load effective address
        move.l A2, -(SP)
        bsr print
        add.l #8, SP
        move.l HALF_MAX, D1
        move.l D1, -(SP)
        lea strAF, A2  ; Load effective address
        move.l A2, -(SP)
        bsr print
        add.l #8, SP
        move.l MAX_SCORE, D1
        move.l MIN_SCORE, D2
        move.l D1, D3
        sub.l D2, D3
        move.l D3, range
        move.l range, D1
        move.l D1, -(SP)
        lea strAG, A2  ; Load effective address
        move.l A2, -(SP)
        bsr print
        add.l #8, SP
        ; Function epilogue
        unlk A6       ; Restore stack frame (restores A6 and SP in one instruction)
        rts           ; Return from subroutine
localConstants:
        ; Function prologue
        link A6, #0  ; Setup stack frame (saves A6 and sets up new frame in one instruction)
        ; Constant variable: LOCAL_MAX
        moveq #50, D1  ; Optimized small constant
        move.l D1, LOCAL_MAX
        ; Constant variable: LOCAL_FLAG
        moveq #0, D1  ; Boolean value
        move.l D1, LOCAL_FLAG
        move.l LOCAL_MAX, D1
        move.l D1, -(SP)
        lea strAH, A2  ; Load effective address
        move.l A2, -(SP)
        bsr print
        add.l #8, SP
        move.l LOCAL_FLAG, D1
        move.l D1, -(SP)
        lea strAI, A2  ; Load effective address
        move.l A2, -(SP)
        bsr print
        add.l #8, SP
        ; Function epilogue
        unlk A6       ; Restore stack frame (restores A6 and SP in one instruction)
        rts           ; Return from subroutine
main:
        ; Function prologue
        link A6, #0  ; Setup stack frame (saves A6 and sets up new frame in one instruction)
        lea strAJ, A1  ; Load effective address
        move.l A1, -(SP)
        bsr print
        add.l #4, SP
        bsr useConstants
        bsr localConstants
        lea strAK, A1  ; Load effective address
        move.l A1, -(SP)
        bsr print
        add.l #4, SP
        ; Function epilogue
        unlk A6       ; Restore stack frame (restores A6 and SP in one instruction)
        rts           ; Return from subroutine

; ===== DATA SECTION =====
; String literals
strAC:
        dc.b 'MAX_LEVEL: ', 0
strAI:
        dc.b 'LOCAL_FLAG: ', 0
strAH:
        dc.b 'LOCAL_MAX: ', 0
strAE:
        dc.b 'DOUBLE_MAX: ', 0
strAB:
        dc.b 'MIN_SCORE: ', 0
strAJ:
        dc.b 'Testing constant variables', 0
strAA:
        dc.b 'MAX_SCORE: ', 0
strAK:
        dc.b 'Constant test completed', 0
strAF:
        dc.b 'HALF_MAX: ', 0
strAG:
        dc.b 'Score range: ', 0
strAD:
        dc.b 'IS_ENABLED: ', 0
; Scalar and struct variables
MAX_SCORE:    ds.l 1
MIN_SCORE:    ds.l 1
MAX_LEVEL:    ds.b 1
IS_ENABLED:    ds.l 1
DOUBLE_MAX:    ds.l 1
HALF_MAX:    ds.l 1
; Constant: PUBLIC_CONST
PUBLIC_CONST:    ds.l 1
; Constant: PRIVATE_CONST
PRIVATE_CONST:    ds.l 1
LOCAL_MAX:    ds.l 1
score:    ds.l 1
enabled:    ds.l 1
range:    ds.l 1
LOCAL_FLAG:    ds.l 1
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
        END