** GENERATED CODE USING DLANG AND D2GEN COMPILER **
        ORG $1000
        JMP main
printPoint:
        ; Function prologue
        move.l A6, -(SP)
        move.l SP, A6
        move.l 8(A6), D0
        move.l 8(A6), D1
        move.l D1, -(SP)
        add.l #4, SP
        move.l D0, D2
        move.l 12(A6), D1
        move.l D1, -(SP)
        add.l #4, SP
        move.l D0, D2
        ; Function epilogue
        move.l (SP)+, A6
        rts
main:
        ; Function prologue
        move.l A6, -(SP)
        move.l SP, A6
        move.l #2, D1
        move.l D1, arrArr_0
arrArr_len:    dc.l 1
        ; variable of type void function(Point) (unknown type, not implemented)
        lea printPoint, A1
        move.l A1, fp
        move.l p, D1
        move.l D1, -(SP)
        add.l #4, SP
        move.l D0, D2
        move.l #1, D1
        move.l arr_1, D2
        move.l D2, D1
        move.l D1, -(SP)
        add.l #4, SP
        move.l D0, D3
        add.l #0, SP
        move.l D0, D1
        move.l D1, -(SP)
        add.l #4, SP
        move.l D0, D2
        move.l #0, D1
        move.l D1, sum
        move.l #0, D1
        move.l D1, i
for_start_0:
        move.l i, D2
        move.l #2, D3
        cmp.l D3, D4
        blt Ltrue_2
        move.l #0, D4
        bra Lend_3
Ltrue_2:
        move.l #1, D4
Lend_3:
        move.l D4, D0
        cmp.l #0, D4
        beq for_end_1
        move.l sum, D1
; ERROR: Only constant indices supported for struct array field access
        move.l D1, D2
        add.l #0, D2
        move.l D2, sum
        move.l i, D1
        move.l #1, D2
        move.l D1, D3
        add.l D2, D3
        move.l D3, i
        bra for_start_0
for_end_1:
        move.l sum, D1
        move.l D1, -(SP)
        add.l #4, SP
        move.l D0, D2
        move.l sum, D1
        move.l #3, D2
        cmp.l D2, D3
        bgt Ltrue_6
        move.l #0, D3
        bra Lend_7
Ltrue_6:
        move.l #1, D3
Lend_7:
        move.l D3, D0
        cmpa.l D3, A1
        beq else_4
        move.l #42, D1
        move.l D1, -(SP)
        add.l #4, SP
        move.l D0, D2
        bra endif_5
else_4:
        move.l #0, D1
        move.l D1, -(SP)
        add.l #4, SP
        move.l D0, D2
endif_5:
        ; Function epilogue
        move.l (SP)+, A6
        rts

        ; String literals
        ; Scalar variables
p:    ds.l 2
i:    ds.l 1
var_fp:    ds.l 1
s:    ds.l 1
sum:    ds.l 1
        ; Array storage
arrArr:
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
        ; Array labels
arr_1:    ds.l 1

fp:
        move.l var_fp, A0
        jsr (A0)
        rts
        ; Loop variables

writeln:
    rts

        SIMHALT
        END