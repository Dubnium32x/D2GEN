** GENERATED CODE USING DLANG AND D2GEN COMPILER **
        ORG $1000
        JMP main
sumArray:
        ; Function prologue
        move.l A6, -(SP)
        move.l SP, A6
        move.l 8(A6), D0
        move.l 12(A6), D1
        move.l #0, D1
        move.l D1, var_sum
        move.l #0, D1
        move.l D1, var_i
for_start_0:
        move.l var_i, D2
        cmp.l D1, D3
        blt Ltrue_2
        move.l #0, D3
        bra Lend_3
Ltrue_2:
        move.l #1, D3
Lend_3:
        move.l D3, D0
        cmp.l #0, D3
        beq for_end_1
        move.l var_i, D1
        addq.l #1, D1
        move.l D1, var_i
        bra for_start_0
for_end_1:
        move.l var_sum, D1
        move.l D1, D0 ; return
        ; Function epilogue
        move.l A6, SP
        move.l (SP)+, A6
        rts
main:
        ; Function prologue
        move.l A6, -(SP)
        move.l SP, A6
        move.l #5, D1
        move.l D1, arrArr_0
        move.l #3, D2
        move.l D2, arrArr_1
        move.l #8, D3
        move.l D3, arrArr_2
        move.l #1, D4
        move.l D4, arrArr_3
        move.l #4, D5
        move.l D5, arrArr_4
arrArr_len:    dc.l 5
        move.l #5, D1
        move.l D1, var_len
        lea strAA, A1
        move.b #9, D0
        trap #14
        move.l #0, D1
        move.l D1, var_i
for_start_4:
        move.l var_i, D2
        move.l var_len, D3
        cmp.l D3, D4
        blt Ltrue_6
        move.l #0, D4
        bra Lend_7
Ltrue_6:
        move.l #1, D4
Lend_7:
        move.l D4, D0
        cmp.l #0, D4
        beq for_end_5
        lea strAB, A1
        move.l A1, -(SP)
        move.l var_i, D1
        move.l D1, D3
        mulu #4, D3
        lea arrArr, A0
        move.l (A0, D3.l), D2
        move.l D2, D1
        move.l D1, -(SP)
        bsr write
        add.l #8, SP
        move.l D0, D4
        move.l var_i, D1
        addq.l #1, D1
        move.l D1, var_i
        bra for_start_4
for_end_5:
        move.l #0, D1
        move.l arr_0, D2
        move.l D2, var_max
        move.l #1, D1
        move.l D1, var_i
for_start_8:
        move.l var_i, D2
        move.l var_len, D3
        cmp.l D3, D4
        blt Ltrue_10
        move.l #0, D4
        bra Lend_11
Ltrue_10:
        move.l #1, D4
Lend_11:
        move.l D4, D0
        cmp.l #0, D4
        beq for_end_9
        move.l var_i, D1
        move.l D1, D3
        mulu #4, D3
        lea arrArr, A0
        move.l (A0, D3.l), D2
        move.l var_max, D4
        cmp.l D4, D5
        bgt Ltrue_14
        move.l #0, D5
        bra Lend_15
Ltrue_14:
        move.l #1, D5
Lend_15:
        move.l D5, D0
        cmpa.l D5, A1
        beq else_12
        move.l var_i, D1
        move.l D1, D3
        mulu #4, D3
        lea arrArr, A0
        move.l (A0, D3.l), D2
        move.l D2, var_max
        bra endif_13
else_12:
endif_13:
        move.l var_i, D1
        addq.l #1, D1
        move.l D1, var_i
        bra for_start_8
for_end_9:
        lea strAC, A1
        move.b #9, D0
        trap #14
        move.l var_max, D1
        move.l D1, D1
        move.b #1, D0
        trap #14
        move.l #0, D1
        move.l D1, var_i
for_start_16:
        move.l var_i, D2
        move.l var_len, D3
        cmp.l D3, D4
        blt Ltrue_18
        move.l #0, D4
        bra Lend_19
Ltrue_18:
        move.l #1, D4
Lend_19:
        move.l D4, D0
        cmp.l #0, D4
        beq for_end_17
        move.l var_i, D1
        move.l D1, D3
        mulu #4, D3
        lea arrArr, A0
        move.l (A0, D3.l), D2
        move.l #2, D4
        move.l D2, D5
        divs D4, D1
        muls D4, D1
        sub.l D1, D2
        move.l #0, D6
        cmp.l D6, D7
        beq Ltrue_22
        move.l #0, D7
        bra Lend_23
Ltrue_22:
        move.l #1, D7
Lend_23:
        move.l D7, D0
        cmpa.l D7, A1
        beq else_20
        move.l var_i, D1
        move.l D1, D3
        mulu #4, D3
        lea arrArr, A0
        move.l (A0, D3.l), D2
        bra endif_21
else_20:
endif_21:
        move.l var_i, D1
        addq.l #1, D1
        move.l D1, var_i
        bra for_start_16
for_end_17:
        lea strAD, A1
        move.b #9, D0
        trap #14
        move.l #0, D1
        move.l D1, var_i
for_start_24:
        move.l var_i, D2
        move.l var_len, D3
        cmp.l D3, D4
        blt Ltrue_26
        move.l #0, D4
        bra Lend_27
Ltrue_26:
        move.l #1, D4
Lend_27:
        move.l D4, D0
        cmp.l #0, D4
        beq for_end_25
        lea strAB, A1
        move.l A1, -(SP)
        move.l var_i, D1
        move.l D1, D3
        mulu #4, D3
        lea arrArr, A0
        move.l (A0, D3.l), D2
        move.l D2, D1
        move.l D1, -(SP)
        bsr write
        add.l #8, SP
        move.l D0, D4
        move.l var_i, D1
        addq.l #1, D1
        move.l D1, var_i
        bra for_start_24
for_end_25:
        move.l var_len, D1
        move.l D1, -(SP)
        move.l arrArr, D2
        move.l D2, -(SP)
        bsr sumArray
        add.l #8, SP
        move.l D0, D3
        move.l D3, var_total
        lea strAE, A1
        move.b #9, D0
        trap #14
        move.l var_total, D1
        move.l D1, D1
        move.b #1, D0
        trap #14
        ; Function epilogue
        move.l A6, SP
        move.l (SP)+, A6
        rts

        ; String literals
strAA:
        dc.b 'Original array:', 0
strAB:
        dc.b ' ', 0
strAD:
        dc.b 'Modified array:', 0
strAE:
        dc.b 'Sum of modified array: ', 0
strAC:
        dc.b 'Max value: ', 0
        ; Array storage
arrArr_0:    ds.l 1
arrArr_1:    ds.l 1
arrArr_2:    ds.l 1
arrArr_3:    ds.l 1
arrArr_4:    ds.l 1
arrArr_5:    ds.l 1
arrArr_6:    ds.l 1
arrArr_7:    ds.l 1
arrArr_8:    ds.l 1
arrArr_9:    ds.l 1
        ; Loop variables
        ; Scalar variables
var_max:    ds.l 1
var_total:    ds.l 1
var_i:    ds.l 1
var_len:    ds.l 1
var_sum:    ds.l 1
        ; Array labels
arr_0:    ds.l 1

write:
    rts
        END