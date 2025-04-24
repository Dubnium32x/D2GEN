** GENERATED CODE USING DLANG AND D2GEN COMPILER **
        ORG $1000
        JMP main
main:
        ; Function prologue
        move.l A6, -(SP)
        move.l SP, A6
        ; variable of type Vec2 (struct or unknown type, not implemented)
        move.l #12, D1
        move.l D1, var_pos+0
        move.l #34, D1
        move.l D1, var_pos+4
        lea strAA, A1
        move.b #9, D0
        trap #14
        move.l var_pos+0, D1
        move.l D1, D1
        move.b #1, D0
        trap #14
        lea strAB, A1
        move.b #9, D0
        trap #14
        move.l var_pos+4, D2
        move.l D2, D1
        move.b #1, D0
        trap #14
        lea strAC, A1
        move.b #9, D0
        trap #14
        ; variable of type Vec2 (struct or unknown type, not implemented)
        move.l var_pos, D1
        move.l D1, var_other
        lea strAD, A1
        move.b #9, D0
        trap #14
        move.l var_other+0, D1
        move.l D1, D1
        move.b #1, D0
        trap #14
        lea strAB, A1
        move.b #9, D0
        trap #14
        move.l var_other+4, D2
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

        ; String literals
strAB:
        dc.b ', ', 0
strAA:
        dc.b 'Position: (', 0
strAC:
        dc.b ')', 0
strAD:
        dc.b 'Other: (', 0
        ; Array storage
        ; Loop variables
        ; Scalar variables
var_pos:    ds.l 1
var_other:    ds.l 1
        ; Array labels
        END