        ORG $1000
main:
        move.l #2, D1 ; int x
        move.l D2, D0 ; return
        rts
        END
