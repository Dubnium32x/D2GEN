** GENERATED CODE USING DLANG AND D2GEN COMPILER **
        ORG $1000
        JMP main
printPoint:
        ; Function prologue
        move.l A6, -(SP)
        move.l SP, A6
        move.l 8(A6), D0
        lea strAA, A1
        move.b #9, D0
        trap #14
        move.l 8(A6), D1
        move.l D1, D1
        move.b #1, D0
        trap #14
        lea strAB, A1
        move.b #9, D0
        trap #14
        move.l 12(A6), D2
        move.l D2, D1
        move.b #1, D0
        trap #14
        lea strAC, A1
        move.b #9, D0
        trap #14
        ; Function epilogue
        move.l A6, SP
        move.l (SP)+, A6
        rts
describe:
        ; Function prologue
        move.l A6, -(SP)
        move.l SP, A6
        move.l 8(A6), D0
        cmp.l #1, D0
        beq case_0_1
        cmp.l #2, D0
        beq case_1_2
        bra case_2_3
case_0_1:
        lea strAD, A1
        move.b #9, D0
        trap #14
        bra end_loop
        bra switch_end_0
case_1_2:
        lea strAE, A1
        move.b #9, D0
        trap #14
        bra end_loop
        bra switch_end_0
case_2_3:
        lea strAF, A1
        move.b #9, D0
        trap #14
        bra end_loop
        bra switch_end_0
switch_end_0:
        ; Function epilogue
        move.l A6, SP
        move.l (SP)+, A6
        rts
main:
        ; Function prologue
        move.l A6, -(SP)
        move.l SP, A6
        ; variable of type Point (struct or unknown type, not implemented)
        move.l #7, D1
        move.l D1, var_pt+0
        move.l #8, D1
        move.l D1, var_pt+4
        ; variable of type void function(Point) (struct or unknown type, not implemented)
        lea var_printPoint, A1
        move.l A1, var_fp
        move.l var_pt, D1
        move.l D1, -(SP)
        add.l #4, SP
        move.l D0, D2
        move.l #2, D1
        move.l D1, var_val
        move.l var_val, D1
        move.l D1, -(SP)
        add.l #4, SP
        move.l D0, D2
        move.l #42, D1
        move.l D1, var_val
        move.l var_val, D1
        move.l D1, -(SP)
        add.l #4, SP
        move.l D0, D2
        ; Function epilogue
        move.l A6, SP
        move.l (SP)+, A6
        rts

        ; String literals
strAB:
        dc.b ', ', 0
strAC:
        dc.b ')', 0
strAE:
        dc.b 'Code is two', 0
strAA:
        dc.b 'Point: (', 0
strAD:
        dc.b 'Code is one', 0
strAF:
        dc.b 'Unknown code', 0
        ; Array storage
        ; Loop variables
        ; Scalar variables
var_pt:    ds.l 1
var_val:    ds.l 1
var_fp:    ds.l 1
var_printPoint:    ds.l 1
        ; Array labels

fp:
        move.l var_fp, A0
        jsr (A0)
        rts
case_0_1:
case_1_2:
switch_end_0:
case_2_3:
        END