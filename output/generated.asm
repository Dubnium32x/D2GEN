        ORG $1000
main:
        move.l #2, D1
        move.l D1, .var_x
        move.l .var_x, D1
        move.l #1, D2
        cmp.l D2, D1
        beq .case_0_1
        move.l #2, D3
        cmp.l D3, D1
        beq .case_1_2
        bra .case_2_3
.case_0_1:
        lea .str_0, A1
        move.b #9, D0
        trap #15
        bra .switch_end_0
.case_1_2:
        lea .str_1, A1
        move.b #9, D0
        trap #15
        bra .switch_end_0
.case_2_3:
        lea .str_2, A1
        move.b #9, D0
        trap #15
        bra .switch_end_0
.switch_end_0:
        move.l #0, D1
        move.l D1, D0 ; return
        rts

.var_x:    ds.l 1

.str_1:
        dc.b 'two'
        dc.b 0
.str_2:
        dc.b 'default'
        dc.b 0
.str_0:
        dc.b 'one'
        dc.b 0
        END