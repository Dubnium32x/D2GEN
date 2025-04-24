** GENERATED CODE USING DLANG AND D2GEN COMPILER **
        ORG $1000
        JSR __global_init
        JMP main

__global_init:
score:    ds.l 1
debugFlag:    ds.l 1
        rts
resetSprites:
        ; Function prologue
        move.l A6, -(SP)
        move.l SP, A6
        move.l #0, D1
        move.l D1, i
for_start_0:
        move.l i, D2
        move.l #4, D3
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
        move.l i, D1
        move.l #1, D2
        move.l D1, D3
        add.l D2, D3
        move.l D3, i
        bra for_start_0
for_end_1:
        ; Function epilogue
        move.l (SP)+, A6
        rts
updateScore:
        ; Function prologue
        move.l A6, -(SP)
        move.l SP, A6
        move.l 8(A6), D0
        move.l score, D1
        move.l D1, D2
        add.l D0, D2
        move.l D2, score
        move.l score, D1
        move.l #2, D2
        move.l D1, D0
        muls D2, D0
        move.l D0, debugFlag
        ; Function epilogue
        move.l (SP)+, A6
        rts
main:
        ; Function prologue
        move.l A6, -(SP)
        move.l SP, A6
        add.l #0, SP
        move.l D0, D1
        move.l #10, D1
        move.l D1, -(SP)
        add.l #4, SP
        move.l D0, D2
        ; Function epilogue
        move.l (SP)+, A6
        rts

        ; String literals
        ; Scalar and struct variables
i:    ds.l 1
        ; Array labels
        ; Loop variables

        SIMHALT
        END