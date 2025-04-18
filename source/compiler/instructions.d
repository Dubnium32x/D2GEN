module compiler.instructions;

import std.string;

// =============================================
// 68K Instruction Templates (Auto-generated)
// =============================================


/// Arithmetic Operations
enum arithmetic = `
    ; add.l  Dx,Dy
    .macro ADD_L dst, src
        dc.w 0xD000 | (\dst<<9) | \src
    .endm

    ; muls.w Dx,Dy
    .macro MULS_W dst, src
        dc.w 0xC1C0 | (\dst<<9) | \src
    .endm
`;

/// Memory Operations
enum memory = `
    ; move.l #imm,Dn
    .macro MOVE_L_IMM_DN val, reg
        dc.w 0x203C | (\reg<<9)
        dc.l \val
    .endm
`;

/// Control Flow
enum control = `
    ; jsr (A0)
    .macro JSR_A0
        dc.w 0x4E90
    .endm
`;

// =============================================
// D Code Generation Helpers
// =============================================

string genAdd(string dst, string src, bool isLong = true) {
    return isLong ? 
        format("    ADD_L  %s,%s\n", dst, src) :
        format("    ADD.W  %s,%s\n", dst, src);
}

string genMoveImm(string reg, int value, int size = 32) {
    return size == 32 ?
        format("    MOVE_L_IMM_DN  #%s,%s\n", value, reg) :
        format("    MOVE_W_IMM_DN  #%s,%s\n", value, reg);
}
