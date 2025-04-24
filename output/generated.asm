** GENERATED CODE USING DLANG AND D2GEN COMPILER **
        ORG $1000
        JSR __global_init
        JMP main

__global_init:
        rts
main:
        ; Function prologue
        move.l A6, -(SP)
        move.l SP, A6
        move.l pixels_0_x, D1
        move.l pixels_1_y, D2
        move.l D1, D3
        add.l D2, D3
        move.l D3, sum
        ; Function epilogue
        move.l (SP)+, A6
        rts

        ; String literals
        ; Scalar and struct variables
pixels_1_y:    ds.l 1
sum:    ds.l 1
pixels_0_x:    ds.l 1
        ; Array labels
        ; Loop variables

        SIMHALT
        END