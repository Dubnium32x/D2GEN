        ORG $1000
main:
        move.l #0, D1
        move.l D1, .var_sumTrue
        move.l #3, D1
        move.l D1, .var_x
        move.l #4, D1
        move.l D1, .var_y
        move.l .var_x, D1
        move.l .var_y, D2
        move.l D1, D3
        add.l D2, D3
        move.l D3, .var_z
        move.l .var_z, D1
        move.l #6, D2
        cmp.l D2, D1
        seq D3
        cmp.l #0, D3
        beq .else_0
        move.l #1, D1
        move.l D1, .var_sumTrue
        bra .endif_1
.else_0:
        move.l #0, D1
        move.l D1, .var_sumTrue
.endif_1:
        move.l .var_z, D1
        move.l D1, D0 ; return
        rts

.var_x:    ds.l 1
.var_sumTrue:    ds.l 1
.var_y:    ds.l 1
.var_z:    ds.l 1
        END