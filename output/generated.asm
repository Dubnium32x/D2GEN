        ORG $1000
main:
        move.l #0, .arr_words_0
        move.l #0, .arr_words_1
        move.l #0, .arr_words_2
.arr_words_len:    dc.l 3
        ; Initialize foreach loop (w)
        move.l #1, D1          ; Start value
        move.l #5, D2          ; End value
        move.l D1, (.var_w_counter) ; Store initial value
.foreach_0:
        ; Check loop condition
        cmp.l D2, D1
        bge .end_foreach_1
        move.l D1, (.var_w) ; Update w
        ; === Loop body begin ===
        move.l .var_w, D1
        move.l D1, D1
        move.b #1, D0
        trap #15
        ; === Loop body end ===
        ; Update loop counter
        addq.l #1, D1          ; w++
        move.l D1, (.var_w_counter) ; Store updated value
        bra .foreach_0
.end_foreach_1:
        ; Foreach loop complete
        ; Clean up foreach loop variables
.var_w_counter:    ds.l 1 ; Clean up counter variable
.var_char_buffer:    ds.l 1 ; Clean up char buffer
        ; Reset register counter if needed
        move.l #0, D1
        move.l D1, D0 ; return
        rts

.arr_words:    ds.l 1
.var_w:    ds.l 1
.arr_words_0:    dc.l 0
.arr_words_1:    dc.l 0
.arr_words_2:    dc.l 0
.arr_words_3:    dc.l 0
.arr_words_4:    dc.l 0
.arr_words_5:    dc.l 0
.arr_words_6:    dc.l 0
.arr_words_7:    dc.l 0
.arr_words_8:    dc.l 0
.arr_words_9:    dc.l 0
        END