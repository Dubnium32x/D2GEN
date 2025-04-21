        ORG $1000
main:
        move.l #0, D1
        move.l D1, .var_i
.for_start_0:
        move.l .var_i, D2
        move.l #5, D3
        cmp.l D3, D2
        slt D4
        cmp.l #0, D4
        beq .for_end_1
        move.l .var_i, D1
        move.l D1, D1
        move.b #1, D0
        trap #15
        move.l .var_i, D1
        addq.l #1, D1
        move.l D1, .var_i
        bra .for_start_0
.for_end_1:
        move.l #0, D1
        move.l D1, D0 ; return
        rts

.var_i:    ds.l 1
        END