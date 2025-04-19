        ORG $1000
main:
        move.l #90, D1
        move.l D1, .var_score
        move.l #0, .var_messageGood
        move.l #0, .var_messageOK
        move.l .var_score, D1
        move.l #100, D2
        cmp.l D2, D1
        seq D3
        cmp.l #0, D3
        beq .else_0
        move.l .var_messageGood, D1
        move.l D1, D1
        move.b #1, D0
        trap #15
        bra .endif_1
.else_0:
        move.l .var_score, D1
        move.l #90, D2
        cmp.l D2, D1
        sge D3
        cmp.l #0, D3
        beq .else_2
        move.l .var_messageOK, D1
        move.l D1, D1
        move.b #1, D0
        trap #15
        bra .endif_3
.else_2:
        lea .str_0, A1
        move.b #9, D0
        trap #15
.endif_3:
.endif_1:
        move.l #0, D1
        move.l D1, D0 ; return
        rts

.var_messageGood:    ds.l 1
.var_score:    ds.l 1
.var_messageOK:    ds.l 1

.str_0:
        dc.b 'Keep trying.'
        dc.b 0
        END