        ORG $1000
        JMP main
sayHello:
        ; Function prologue
        move.l A6, -(SP)
        move.l SP, A6
        lea strAA, A1
        move.b #9, D0
        trap #14
        lea strAA, A1
        move.b #9, D0
        trap #14
        ; Function epilogue
        move.l A6, SP
        move.l (SP)+, A6
        rts
        ; String literals for sayHello
add:
        ; Function prologue
        move.l A6, -(SP)
        move.l SP, A6
        move.l (SP)+, D1
        move.l D1, .var_b
        move.l (SP)+, D2
        move.l D2, .var_a
        move.l .var_a, D1
        move.l .var_b, D2
        move.l D1, D3
        add.l D2, D3
        move.l #0, D0 ; return
        move.l .var_a, D1
        move.l .var_b, D2
        move.l D1, D3
        add.l D2, D3
        move.l #0, D0 ; return
        ; Function epilogue
        move.l A6, SP
        move.l (SP)+, A6
        rts
.var_a: ds.l 1
.var_b: ds.l 1
        ; String literals for add
checkEven:
        ; Function prologue
        move.l A6, -(SP)
        move.l SP, A6
        move.l (SP)+, D4
        move.l D4, .var_num
        move.l .var_num, D1
        move.l #2, D2
        move.l D1, D3
        divu D2, D3
        move.l #0, D4
        cmp.l #0, D4
        seq D5
        cmpa.l #0, A1
        beq .else_0
        lea strAB, A1
        move.b #9, D0
        trap #14
        bra .endif_1
.else_0:
        lea strAC, A1
        move.b #9, D0
        trap #14
.endif_1:
        move.l .var_num, D1
        move.l #2, D2
        move.l D1, D3
        divu D2, D3
        move.l #0, D4
        cmp.l #0, D4
        seq D5
        cmpa.l #0, A1
        beq .else_2
        lea strAB, A1
        move.b #9, D0
        trap #14
        bra .endif_3
.else_2:
        lea strAC, A1
        move.b #9, D0
        trap #14
.endif_3:
        ; Function epilogue
        move.l A6, SP
        move.l (SP)+, A6
        rts
.var_num: ds.l 1
        ; String literals for checkEven
main:
        ; Function prologue
        move.l A6, -(SP)
        move.l SP, A6
        bsr sayHello
        add.l #0, SP
        move.l D0, D1
        bsr sayHello
        add.l #0, SP
        move.l D0, D1
        move.l #3, D1
        move.l D1, -(SP)
        move.l #5, D2
        move.l D2, -(SP)
        bsr add
        add.l #8, SP
        move.l D0, D3
        move.l D3, .var_result
        move.l #3, D1
        move.l D1, -(SP)
        move.l #5, D2
        move.l D2, -(SP)
        bsr add
        add.l #8, SP
        move.l D0, D3
        move.l D3, .var_result
        move.l .var_result, D1
        move.l D1, D1
        move.b #1, D0
        trap #14
        move.l .var_result, D1
        move.l D1, D1
        move.b #1, D0
        trap #14
        move.l .var_result, D1
        move.l D1, -(SP)
        bsr checkEven
        add.l #4, SP
        move.l D0, D2
        move.l .var_result, D1
        move.l D1, -(SP)
        bsr checkEven
        add.l #4, SP
        move.l D0, D2
        move.l #0, D1
        move.l D1, D0 ; return
        move.l #0, D1
        move.l D1, D0 ; return
        ; Function epilogue
        move.l A6, SP
        move.l (SP)+, A6
        rts
.var_result: ds.l 1
        ; String literals for main

        ; String literals
strAB:
        dc.b 'Even', 0
strAA:
        dc.b 'Hello!', 0
strAC:
        dc.b 'Odd', 0
        END