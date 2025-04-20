        ORG $1000
main:
        move.l #0, D1
        move.l D1, .var_i
        ; Initialize foreach loop (i)
        move.l #1, D1          ; Start value
        move.l #5, D2          ; End value
        move.l D1, (.var_i_counter) ; Store initial value
.foreach_0:
        ; Check loop condition
        cmp.l D2, D1
        bge .end_foreach_1
        move.l D1, (.var_i) ; Update i
        ; === Loop body begin ===
        move.l .var_i, D1
        move.l D1, D1
        move.b #1, D0
        trap #15
        ; === Loop body end ===
        ; Update loop counter
        addq.l #1, D1          ; i++
        move.l D1, (.var_i_counter) ; Store updated value
        bra .foreach_0
.end_foreach_1:
        ; Foreach loop complete
        ; Clean up foreach loop variables
.var_i_counter:    ds.l 1 ; Clean up counter variable
.var_char_buffer:    ds.l 1 ; Clean up char buffer
        ; Reset register counter if needed
        move.l #0, D1
        move.l D1, D0 ; return
        rts

.var_i:    ds.l 1
        END