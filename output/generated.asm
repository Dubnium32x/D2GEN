** GENERATED CODE USING DLANG AND D2GEN COMPILER **
        ORG $1000
        JSR __global_init
        JMP main

; ===== FUNCTION DEFINITIONS =====
__global_init:
        rts
initMatrix:
        ; Function prologue
        move.l A6, -(SP)
        move.l SP, A6
        move.l #0, D1  ; Initialize constant
        move.l D1, i
.for_start_0:             ; Start of for loop
        move.l i, D2
        move.l #4, D3  ; Initialize constant
        cmp.l D3, D4
        blt .true_2
        move.l #0, D4
        bra .end_3
.true_2:
        move.l #1, D4
.end_3:
        move.l D4, D0  ; Move condition result to D0
        cmp.l #0, D4   ; Check if condition is false
        beq .for_end_1        ; Exit loop if condition is false
        move.l #0, D1
        move.l D1, j
.for_start_4:             ; Start of for loop
        move.l j, D2
        move.l #4, D3  ; Initialize constant
        cmp.l D3, D4
        blt .true_6
        move.l #0, D4
        bra .end_7
.true_6:
        move.l #1, D4
.end_7:
        move.l D4, D0  ; Move condition result to D0
        cmp.l #0, D4   ; Check if condition is false
        beq .for_end_5        ; Exit loop if condition is false
        move.l i, D1
        move.l j, D2
        cmp.l D2, D3
        beq .true_10
        move.l #0, D3
        bra .end_11
.true_10:
        move.l #1, D3
.end_11:
        move.l D3, D0  ; Move condition result to D0
        cmpa.l D3, A1  ; Check if condition is false
        beq .else_8       ; Branch to else if condition is false
        move.l #1, D1
        move.l j, D2
        move.l D2, D3
        mulu #4, D3  ; Compute array offset
        lea matrix_array, A0  ; Load effective address
        move.l D1, (A0,D3.l)
        bra .endif_9        ; Skip over else section when then section completes
.else_8:             ; Else section starts here
        move.l #0, D1
        move.l j, D2
        move.l D2, D3
        mulu #4, D3  ; Compute array offset
        lea matrix_array, A0  ; Load effective address
        move.l D1, (A0,D3.l)
.endif_9:             ; End of if-else statement
        move.l j, D1
        move.l #1, D2  ; Initialize constant
        move.l D1, D3
        add.l D2, D3
        move.l D3, j
        bra .for_start_4      ; Jump back to start of loop
.for_end_5:             ; End of for loop
        move.l i, D1
        move.l #1, D2  ; Initialize constant
        move.l D1, D3
        add.l D2, D3
        move.l D3, i
        bra .for_start_0      ; Jump back to start of loop
.for_end_1:             ; End of for loop
        ; Function epilogue
        move.l (SP)+, A6
        rts
setupModel:
        ; Function prologue
        move.l A6, -(SP)
        move.l SP, A6
        move.l 8(A6), D0
        move.l 12(A6), D1
        move.l 16(A6), D2
        move.l 20(A6), D3
        move.l #2, D1  ; Initialize constant
        move.l #10, D1
        muls D1, D0
        move.l #255, D1
        move.l #0, D2  ; Initialize constant
        move.l D2, D3
        mulu #4, D3  ; Compute array offset
        lea matrix_array, A0  ; Load effective address
        move.l D1, (A0,D3.l)
        move.l #128, D1  ; Initialize constant
        move.l #1, D2
        move.l D2, D3
        mulu #4, D3  ; Compute array offset
        lea matrix_array, A0  ; Load effective address
        move.l D1, (A0,D3.l)
        move.l #0, D1  ; Initialize constant
        move.l #2, D2
        move.l D2, D3
        mulu #4, D3  ; Compute array offset
        lea matrix_array, A0  ; Load effective address
        move.l D1, (A0,D3.l)
        move.l #0, D1  ; Initialize constant
        cmp.l D1, D2
        bgt .true_14
        move.l #0, D2
        bra .end_15
.true_14:
        move.l #1, D2
.end_15:
        move.l D2, D0  ; Move condition result to D0
        cmpa.l D2, A1  ; Check if condition is false
        beq .else_12       ; Branch to else if condition is false
        lea models, A1  ; Load effective address
        move.l #0, D2
        move.l D2, D3
        mulu #16, D3  ; Compute array offset
        add.l D3, A1
        move.l 0(A1), D1
        bra .endif_13        ; Skip over else section when then section completes
.else_12:             ; Else section starts here
        move.l #1, D1
        move.l #1, D1  ; Initialize constant
        move.l #1, D1
.endif_13:             ; End of if-else statement
        move.l #4, D1
        move.l D0, D2
        divs D1, D1
        muls D1, D1
        sub.l D1, D0
        move.l D2, D1
        mulu #4, D1  ; Compute array offset
        lea matrix_data, A0  ; Load matrix data base address
        move.l (A0,D1.l), D2  ; Get matrix element at computed offset
        move.l #100, D3
        move.l D2, D4
        add.l D3, D4
        ; Function epilogue
        move.l (SP)+, A6
        rts
main:
        ; Function prologue
        move.l A6, -(SP)
        move.l SP, A6
        bsr initMatrix
        move.l #0, D1
        move.l D1, i
.for_start_16:             ; Start of for loop
        move.l i, D2
        move.l #3, D3  ; Initialize constant
        cmp.l D3, D4
        blt .true_18
        move.l #0, D4
        bra .end_19
.true_18:
        move.l #1, D4
.end_19:
        move.l D4, D0  ; Move condition result to D0
        cmp.l #0, D4   ; Check if condition is false
        beq .for_end_17        ; Exit loop if condition is false
        move.l i, D1
        move.l #30, D2  ; Initialize constant
        move.l D1, D0
        muls D2, D0
        move.l D0, -(SP)
        move.l i, D1
        move.l #20, D2  ; Initialize constant
        move.l D1, D0
        muls D2, D0
        move.l D0, -(SP)
        move.l i, D1
        move.l #10, D2  ; Initialize constant
        move.l D1, D0
        muls D2, D0
        move.l D0, -(SP)
        move.l i, D1
        move.l D1, -(SP)
        bsr setupModel
        add.l #16, SP
        move.l i, D1
        move.l #1, D2  ; Initialize constant
        move.l D1, D3
        add.l D2, D3
        move.l D3, i
        bra .for_start_16      ; Jump back to start of loop
.for_end_17:             ; End of for loop
        move.l #1, D1
        move.l #1, D2  ; Initialize constant
        move.l D1, D3
        add.l D2, D3
        move.l D3, idx
        move.l idx, D1
        lea models, A2  ; Load effective address
        move.l idx, D3
        move.l #1, D4  ; Initialize constant
        move.l D3, D5
        sub.l D4, D5
        move.l D5, D3
        mulu #16, D3  ; Compute array offset
        add.l D3, A2
        move.l 0(A2), D2
        lea models, A3  ; Load effective address
        move.l #0, D4
        move.l D4, D5
        mulu #16, D5  ; Compute array offset
        add.l D5, A3
        move.l 0(A3), D3
        move.l D2, D4
        add.l D3, D4
        ; Function epilogue
        move.l (SP)+, A6
        rts

; ===== DATA SECTION =====
; String literals
; Scalar and struct variables
models:    ds.l 1
idx:    ds.l 1
i:    ds.l 1
matrix_data:    ds.l 100
matrix_array:    ds.l 100
j:    ds.l 1
; Array labels
; Loop variables

        SIMHALT
        END