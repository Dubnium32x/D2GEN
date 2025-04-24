** GENERATED CODE USING DLANG AND D2GEN COMPILER **
        ORG $1000
        JMP main
main:
        ; Function prologue
        move.l A6, -(SP)
        move.l SP, A6
        move.l #123, D1
        move.l D1, f+0
        move.l 8(A6), D1
        move.l D1, D1
        move.b #1, D0
        trap #14
        move.l s, D0
        cmp.l #0, D0
        seq D1
        move.l D1, D1
        move.b #1, D0
        trap #14
        ; Function epilogue
        move.l (SP)+, A6
        rts

        ; String literals
        ; Array storage
        ; Loop variables
        ; Scalar variables
f:    ds.l 4
s:    ds.l 1
        ; Array labels

        SIMHALT
        END