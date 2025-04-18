        ORG $1000
main:
        move.l #0, D1
.while_0:
        move.l #3, D2
        move.l D1, D3
        add.l D2, D3
        cmp.l #0, D3
        beq .endwhile_1
        move.l #1, D4
        move.l D1, D5
        add.l D4, D5
        bra .while_0
.endwhile_1:
        move.l D5, D0 ; return
        rts
        END