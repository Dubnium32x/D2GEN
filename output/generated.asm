        ORG $1000
        JMP main
main:
        ; Function prologue
        move.l A6, -(SP)
        move.l SP, A6
        move.l #1, D1
        move.l D1, arrNumbers_0
        move.l #2, D2
        move.l D2, arrNumbers_1
        move.l #3, D3
        move.l D3, arrNumbers_2
        move.l #4, D4
        move.l D4, arrNumbers_3
        move.l #5, D5
        move.l D5, arrNumbers_4
arrNumbers_len:    dc.l 5
        lea strAA, A1
        move.b #9, D0
        trap #14
        move.l arrNumbers, D1
        move.l D1, D1
        move.b #1, D0
        trap #14
        lea strAA, A1
        move.b #9, D0
        trap #14
        move.l arrNumbers, D1
        move.l D1, D1
        move.b #1, D0
        trap #14
        lea strAB, A1
        move.b #9, D0
        trap #14
        move.l #0, D1
        move.l numbers_0, D2
        move.l D2, D1
        move.b #1, D0
        trap #14
        lea strAB, A1
        move.b #9, D0
        trap #14
        move.l #0, D1
        move.l numbers_0, D2
        move.l D2, D1
        move.b #1, D0
        trap #14
        lea strAC, A1
        move.b #9, D0
        trap #14
        move.l var_$, D1
        move.l #1, D2
        move.l D1, D3
        sub.l D2, D3
        move.l #0, D5
        mulu #4, D5
        lea arrNumbers, A0
        move.l (A0, D5.l), D4
        move.l D4, D1
        move.b #1, D0
        trap #14
        lea strAC, A1
        move.b #9, D0
        trap #14
        move.l var_$, D1
        move.l #1, D2
        move.l D1, D3
        sub.l D2, D3
        move.l #0, D5
        mulu #4, D5
        lea arrNumbers, A0
        move.l (A0, D5.l), D4
        move.l D4, D1
        move.b #1, D0
        trap #14
        lea strAD, A1
        move.b #9, D0
        trap #14
        move.l arrNumbers, D1
        move.l D1, D1
        move.b #1, D0
        trap #14
        lea strAD, A1
        move.b #9, D0
        trap #14
        move.l arrNumbers, D1
        move.l D1, D1
        move.b #1, D0
        trap #14
        lea strAE, A1
        move.b #9, D0
        trap #14
        lea strAE, A1
        move.b #9, D0
        trap #14
        move.l #0, var_num
        move.l #0, var_num
        move.l #0, D1
        move.l D1, var_num
        move.l #0, D1
        move.l D1, var_num
        ; Initialize foreach loop (num)
        move.l #1, D1          ; Start value
        move.l #5, D2          ; End value
        move.l D1, (var_num_counter) ; Store initial value
foreach_0:
        ; Check loop condition
        cmp.l D2, D1
        bge end_foreach_1
        move.l D1, (var_num) ; Update num
        ; === Loop body begin ===
        move.l var_num, D1
        move.l D1, D1
        move.b #1, D0
        trap #14
        ; === Loop body end ===
        ; Update loop counter
        addq.l #1, D1          ; num++
        move.l D1, (var_num_counter) ; Store updated value
        bra foreach_0
end_foreach_1:
        ; Foreach loop complete
        ; Clean up foreach loop variables
var_num_counter:    ds.l 1 ; Clean up counter variable
var_char_buffer:    ds.l 1 ; Clean up char buffer
        ; Reset register counter if needed
        ; Initialize foreach loop (num)
        move.l #1, D1          ; Start value
        move.l #5, D2          ; End value
        move.l D1, (var_num_counter) ; Store initial value
foreach_2:
        ; Check loop condition
        cmp.l D2, D1
        bge end_foreach_3
        move.l D1, (var_num) ; Update num
        ; === Loop body begin ===
        move.l var_num, D1
        move.l D1, D1
        move.b #1, D0
        trap #14
        ; === Loop body end ===
        ; Update loop counter
        addq.l #1, D1          ; num++
        move.l D1, (var_num_counter) ; Store updated value
        bra foreach_2
end_foreach_3:
        ; Foreach loop complete
        ; Clean up foreach loop variables
        ; Reset register counter if needed
        ; Function epilogue
        move.l A6, SP
        move.l (SP)+, A6
        rts
var_$: ds.l 1
arrNumbers: ds.l 1
var_num: ds.l 1
        ; String literals for main

        ; String literals
strAC:
        dc.b 'Last element: ', 0
strAD:
        dc.b 'Modified Array: ', 0
strAE:
        dc.b 'Array elements:', 0
strAB:
        dc.b 'First element: ', 0
strAA:
        dc.b 'Array: ', 0
        ; Array storage
arrNumbers_0:    ds.l 1
arrNumbers_1:    ds.l 1
arrNumbers_2:    ds.l 1
arrNumbers_3:    ds.l 1
arrNumbers_4:    ds.l 1
arrNumbers_5:    ds.l 1
arrNumbers_6:    ds.l 1
arrNumbers_7:    ds.l 1
arrNumbers_8:    ds.l 1
arrNumbers_9:    ds.l 1
        ; Array labels
numbers_0:    ds.l 1
        END