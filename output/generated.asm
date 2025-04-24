** GENERATED CODE USING DLANG AND D2GEN COMPILER **
        ORG $1000
        JMP main
printPixel:
        ; Function prologue
        move.l A6, -(SP)
        move.l SP, A6
        move.l 8(A6), D0
        move.l p_pos_x, D1
        move.l D1, -(SP)
        add.l #4, SP
        move.l D0, D2
        move.l p_pos_y, D1
        move.l D1, -(SP)
        add.l #4, SP
        move.l D0, D2
        move.l p_color, D1
        move.l D1, -(SP)
        add.l #4, SP
        move.l D0, D2
        ; Function epilogue
        move.l (SP)+, A6
        rts
sumColors:
        ; Function prologue
        move.l A6, -(SP)
        move.l SP, A6
        move.l 8(A6), D0
        move.l 12(A6), D3
        move.l #0, D1
        move.l D1, sum
        move.l #0, D1
        move.l D1, i
for_start_0:
        move.l i, D2
        cmp.l D3, D3
        blt Ltrue_2
        move.l #0, D3
        bra Lend_3
Ltrue_2:
        move.l #1, D3
Lend_3:
        move.l D3, D0
        cmp.l #0, D3
        beq for_end_1
        move.l sum, D1
; ERROR: Only constant indices supported for struct array field access
        move.l #0, D2
        move.l D1, D3
        add.l D2, D3
        move.l D3, sum
        move.l i, D1
        move.l #1, D2
        move.l D1, D3
        add.l D2, D3
        move.l D3, i
        bra for_start_0
for_end_1:
        move.l sum, D1
        move.l D1, D0 ; return
        ; Function epilogue
        move.l (SP)+, A6
        rts
main:
        ; Function prologue
        move.l A6, -(SP)
        move.l SP, A6
        move.l #0, D1
        move.l pixels_0, D2
        move.l D2, D1
        move.l D1, -(SP)
        add.l #4, SP
        move.l D0, D3
        move.l #2, D1
        move.l pixels_2, D2
        move.l D2, D1
        move.l D1, -(SP)
        add.l #4, SP
        move.l D0, D3
        move.l #0, D1
        move.l D1, total
        move.l #0, D1
        move.l D1, i
for_start_4:
        move.l i, D2
        move.l #3, D3
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
        cmp.l #1, D0
        beq case_0_11
        cmp.l #2, D0
        beq case_1_12
        cmp.l #3, D0
        beq case_2_13
        bra case_3_14
case_0_11:
        move.l total, D1
        move.l #10, D2
        move.l D1, D3
        add.l D2, D3
        move.l D3, total
        bra switch_end_8
case_1_12:
        move.l total, D1
        move.l #20, D2
        move.l D1, D3
        add.l D2, D3
        move.l D3, total
        bra switch_end_8
case_2_13:
        move.l total, D1
        move.l #30, D2
        move.l D1, D3
        add.l D2, D3
        move.l D3, total
        bra switch_end_8
case_3_14:
        move.l total, D1
        move.l #1, D2
        move.l D1, D3
        add.l D2, D3
        move.l D3, total
        bra switch_end_8
switch_end_8:
        move.l i, D1
        move.l #1, D2
        move.l D1, D3
        add.l D2, D3
        move.l D3, i
        bra for_start_4
for_end_5:
        move.l total, D1
        move.l D1, -(SP)
        add.l #4, SP
        move.l D0, D2
        move.l #3, D1
        move.l D1, -(SP)
        move.l arrPixels, D2
        move.l D2, -(SP)
        add.l #8, SP
        move.l D0, D3
        move.l D3, colorSum
        move.l colorSum, D1
        move.l D1, -(SP)
        add.l #4, SP
        move.l D0, D2
        add.l #0, SP
        move.l D0, D1
        move.l D1, D0
        cmpa.l D1, A1
        beq else_15
        move.l #123, D1
        move.l D1, -(SP)
        add.l #4, SP
        move.l D0, D2
        bra endif_16
else_15:
        move.l #456, D1
        move.l D1, -(SP)
        add.l #4, SP
        move.l D0, D2
endif_16:
        ; Function epilogue
        move.l (SP)+, A6
        rts

        ; String literals
        ; Scalar and struct variables
p_color:    ds.l 1
arrFparr_len:    ds.l 2
fpArr_0:    ds.l 1
pixels_2:    ds.l 1
total:    ds.l 1
colorSum:    ds.l 1
i:    ds.l 1
fpArr_1:    ds.l 1
p_pos_x:    ds.l 1
pixels_0:    ds.l 1
arrPixels:    ds.l 1
p_pos_y:    ds.l 1
sum:    ds.l 1
s:    ds.l 1
        ; Array labels
arrFparr:    ds.l 1
        ; Loop variables

writeln:
    rts

        SIMHALT
        END