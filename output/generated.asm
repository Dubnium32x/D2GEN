        ORG $1000
main:
        move.l #6, D1
        move.b D1, .var_i
        move.l .var_i, D1
        move.l #6, D2
        cmp.l D2, D1
        seq D3
        cmp.l #0, D3
        beq .else_0
        lea .str_0, A1
        move.b #9, D0
        trap #15
        bra .endif_1
.else_0:
.endif_1:
        move.l #0, D1
        move.l D1, D0 ; return
        rts

.var_i:    ds.l 1

.str_0:
        dc.b 'Yippee!'
        dc.b 0
        END