        ORG $1000
main:
        move.l #0, D1
        move.l D1, .var_i
        move.l #0, D1
        move.l D1, .var_i
.for_start_0:
        move.l .var_i, D2
        move.l #3, D3
        cmp.l D3, D2
        slt D4
        cmp.l #0, D4
        beq .for_end_1
        move.l .var_i, D1
        move.l #1, D2
        move.l D1, D3
        add.l D2, D3
        move.l D3, .var_i
        bra .for_start_0
.for_end_1:
        rts

.var_i:    ds.l 1
        END