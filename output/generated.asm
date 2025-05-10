** GENERATED CODE USING DLANG AND D2GEN COMPILER **
        ORG $1000
        JSR __global_init
        JMP main

; ===== FUNCTION DEFINITIONS =====
__global_init:
        rts
main:
        ; Function prologue
        link A6, #0  ; Setup stack frame (saves A6 and sets up new frame in one instruction)
        moveq #5, D1  ; Optimized small constant
        move.l D1, a
        moveq #10, D1  ; Optimized small constant
        move.l D1, b
        move.l a, D1
        move.l b, D2
        moveq #0, D3  ; Clear result register
        cmp.l D2, D1  ; Compare values
        seq.b D3      ; Set dest to FF if equal, 00 if not equal
        and.l #1, D3  ; Mask to boolean value (1 if equal)
        move.l D3, eq
        move.l a, D1
        move.l b, D2
        moveq #0, D3  ; Clear result register
        cmp.l D2, D1  ; Compare values
        sne.b D3      ; Set dest to FF if not equal, 00 if equal
        and.l #1, D3  ; Mask to boolean value (1 if not equal)
        move.l D3, neq
        move.l a, D1
        move.l b, D2
        moveq #0, D3  ; Clear result register
        cmp.l D2, D1  ; Compare values
        slt.b D3      ; Set dest to FF if less than, 00 otherwise
        and.l #1, D3  ; Mask to boolean value (1 if less than)
        move.l D3, lt
        move.l a, D1
        move.l b, D2
        moveq #0, D3  ; Clear result register
        cmp.l D2, D1  ; Compare values
        sle.b D3      ; Set dest to FF if less or equal, 00 otherwise
        and.l #1, D3  ; Mask to boolean value (1 if less or equal)
        move.l D3, lte
        move.l a, D1
        move.l b, D2
        moveq #0, D3  ; Clear result register
        cmp.l D2, D1  ; Compare values
        sgt.b D3      ; Set dest to FF if greater than, 00 otherwise
        and.l #1, D3  ; Mask to boolean value (1 if greater than)
        move.l D3, gt
        move.l a, D1
        move.l b, D2
        moveq #0, D3  ; Clear result register
        cmp.l D2, D1  ; Compare values
        sge.b D3      ; Set dest to FF if greater or equal, 00 otherwise
        and.l #1, D3  ; Mask to boolean value (1 if greater or equal)
        move.l D3, gte
        moveq #42, D1  ; Optimized small constant
        moveq #3, D2  ; Optimized small constant
        moveq #2, D3  ; Optimized small constant
        moveq #1, D4  ; Optimized small constant
        ; Computing multi-dimensional array offset for assignment to arr
        move.l D4, D5
        move.l #12, D6  ; Size of dimension 1  ; Initialize constant
        muls D6, D5  ; Multiply previous index by dimension
        add.l D3, D5  ; Add current dimension index
        move.l #4, D6  ; Size of dimension 2
        muls D6, D5  ; Multiply previous index by dimension
        add.l D2, D5  ; Add current dimension index
        mulu #4, D5  ; Multiply by element size (4 bytes)
        lea arr, A0  ; Load array base address
        move.l D1, (A0,D5.l)  ; Store value to array element
        moveq #3, D1  ; Optimized small constant
        moveq #2, D2  ; Optimized small constant
        moveq #1, D3  ; Optimized small constant
        ; Computing multi-dimensional array offset for arr
        move.l D3, D4
        move.l #12, D5  ; Size of dimension 1  ; Initialize constant
        muls D5, D4  ; Multiply previous index by dimension
        add.l D2, D4  ; Add current dimension index
        move.l #4, D5  ; Size of dimension 2
        muls D5, D4  ; Multiply previous index by dimension
        add.l D1, D4  ; Add current dimension index
        mulu #4, D4  ; Multiply by element size (4 bytes)
        lea arr, A0  ; Load array base address
        move.l (A0,D4.l), D6  ; Load element value
        move.l D6, x
        moveq #0, D1  ; Optimized small constant
        move.l D1, i
.for_start_0:             ; Start of for loop
        move.l i, D2
        moveq #2, D3  ; Optimized small constant
        moveq #0, D4  ; Clear result register
        cmp.l D3, D2  ; Compare values
        slt.b D4      ; Set dest to FF if less than, 00 otherwise
        and.l #1, D4  ; Mask to boolean value (1 if less than)
        move.l D4, D0  ; Move condition result to D0
        tst.l D4   ; Check if condition is false/zero
        beq .for_end_1        ; Exit loop if condition is false
        moveq #0, D1  ; Optimized small constant
        move.l D1, j
.for_start_2:             ; Start of for loop
        move.l j, D2
        moveq #3, D3  ; Optimized small constant
        moveq #0, D4  ; Clear result register
        cmp.l D3, D2  ; Compare values
        slt.b D4      ; Set dest to FF if less than, 00 otherwise
        and.l #1, D4  ; Mask to boolean value (1 if less than)
        move.l D4, D0  ; Move condition result to D0
        tst.l D4   ; Check if condition is false/zero
        beq .for_end_3        ; Exit loop if condition is false
        moveq #0, D1  ; Optimized small constant
        move.l D1, k
.for_start_4:             ; Start of for loop
        move.l k, D2
        moveq #4, D3  ; Optimized small constant
        moveq #0, D4  ; Clear result register
        cmp.l D3, D2  ; Compare values
        slt.b D4      ; Set dest to FF if less than, 00 otherwise
        and.l #1, D4  ; Mask to boolean value (1 if less than)
        move.l D4, D0  ; Move condition result to D0
        tst.l D4   ; Check if condition is false/zero
        beq .for_end_5        ; Exit loop if condition is false
        move.l j, D1
        move.l k, D2
        move.l j, D3
        move.l i, D4
        ; Computing multi-dimensional array offset for assignment to arr
        move.l D4, D5
        move.l #12, D6  ; Size of dimension 1  ; Initialize constant
        muls D6, D5  ; Multiply previous index by dimension
        add.l D3, D5  ; Add current dimension index
        move.l #4, D6  ; Size of dimension 2
        muls D6, D5  ; Multiply previous index by dimension
        add.l D2, D5  ; Add current dimension index
        mulu #4, D5  ; Multiply by element size (4 bytes)
        lea arr, A0  ; Load array base address
        move.l D1, (A0,D5.l)  ; Store value to array element
        move.l k, D1
        addq.l #1, D1  ; Increment loop counter
        move.l D1, k
        bra .for_start_4      ; Jump back to start of loop
.for_end_5:             ; End of for loop
        move.l j, D1
        addq.l #1, D1  ; Increment loop counter
        move.l D1, j
        bra .for_start_2      ; Jump back to start of loop
.for_end_3:             ; End of for loop
        move.l i, D1
        addq.l #1, D1  ; Increment loop counter
        move.l D1, i
        bra .for_start_0      ; Jump back to start of loop
.for_end_1:             ; End of for loop
        ; Function epilogue
        unlk A6       ; Restore stack frame (restores A6 and SP in one instruction)
        rts           ; Return from subroutine

; ===== DATA SECTION =====
; String literals
; Scalar and struct variables
eq:    ds.l 1
lt:    ds.l 1
arr_0:    ds.l 1
a:    ds.l 1
x:    ds.l 1
j:    ds.l 1
i:    ds.l 1
gte:    ds.l 1
lte:    ds.l 1
arrArr_len:    ds.l 3
arr_1:    ds.l 1
arr:    ds.l 24
neq:    ds.l 1
arr_2:    ds.l 1
b:    ds.l 1
gt:    ds.l 1
k:    ds.l 1
; Array labels
arrArr:    ds.l 1
; Loop variables

        SIMHALT
        END