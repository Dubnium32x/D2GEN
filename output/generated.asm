        ORG $1000
        JMP main
isEven:
        ; Function prologue
        move.l A6, -(SP)
        move.l SP, A6
        move.l 8(A6), D1
        move.l D1, .var_x
        move.l .var_x, D1
        move.l #2, D2
        move.l D1, D3
        divu D2, D3
        move.l #0, D4
        cmp.l #0, D4
        seq D5
        move.l #0, D0 ; return
        move.l .var_x, D1
        move.l #2, D2
        move.l D1, D3
        divu D2, D3
        move.l #0, D4
        cmp.l #0, D4
        seq D5
        move.l #0, D0 ; return
        ; Function epilogue
        move.l A6, SP
        move.l (SP)+, A6
        rts
.var_x: ds.l 1
        ; String literals for isEven
main:
        ; Function prologue
        move.l A6, -(SP)
        move.l SP, A6
        move.l #4, D1
        move.l D1, .var_num
        move.l #4, D1
        move.l D1, .var_num
        move.l .var_num, D1
        move.l D1, -(SP)
        bsr isEven
        add.l #4, SP
        move.l D0, D2
        move.l D2, .var_result
        move.l .var_num, D1
        move.l D1, -(SP)
        bsr isEven
        add.l #4, SP
        move.l D0, D2
        move.l D2, .var_result
        move.l .var_result, D1
        cmpa.l D1, A1
        beq .else_0
        lea strAA, A1
        move.b #9, D0
        trap #14
        bra .endif_1
.else_0:
        lea strAB, A1
        move.b #9, D0
        trap #14
.endif_1:
        move.l .var_result, D1
        cmpa.l D1, A1
        beq .else_2
        lea strAA, A1
        move.b #9, D0
        trap #14
        bra .endif_3
.else_2:
        lea strAB, A1
        move.b #9, D0
        trap #14
.endif_3:
        move.l #0, D1
        move.l D1, D0 ; return
        move.l #0, D1
        move.l D1, D0 ; return
        ; Function epilogue
        move.l A6, SP
        move.l (SP)+, A6
        rts
.var_result: ds.l 1
.var_num: ds.l 1
        ; String literals for main

        ; String literals
strAA:
        dc.b 'Even', 0
strAB:
        dc.b 'Odd', 0
        END