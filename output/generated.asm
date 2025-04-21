        ORG $1000
main:
        move.l #100, D1
        move.l D1, .arr_nums_0
        move.l #200, D2
        move.l D2, .arr_nums_1
        move.l #300, D3
        move.l D3, .arr_nums_2
.arr_nums_len:    dc.l 3
        move.l #0, D1
        move.b #1, D0
        trap #15
        move.l #0, D1
        move.l D1, D0 ; return
        rts

.arr_nums:    ds.l 1
.arr_nums_0:    dc.l 0
.arr_nums_1:    dc.l 0
.arr_nums_2:    dc.l 0
.arr_nums_3:    dc.l 0
.arr_nums_4:    dc.l 0
.arr_nums_5:    dc.l 0
.arr_nums_6:    dc.l 0
.arr_nums_7:    dc.l 0
.arr_nums_8:    dc.l 0
.arr_nums_9:    dc.l 0
        END