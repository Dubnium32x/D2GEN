; add.l  Dx,Dy
.macro ADD_L dst, src
    dc.w 0xD000 | (\dst<<9) | \src
.endm

; muls.w Dx,Dy
.macro MULS_W dst, src
    dc.w 0xC1C0 | (\dst<<9) | \src
.endm

: sub.l Dx,Dy
.macro SUB_L dst, src
    dc.w 0x9000 | (\dst<<9) | \src
.endm

; divs.w Dx,Dy
.macro DIVS_W dst, src
    dc.w 0x81C0 | (\dst<<9) | \src
.endm