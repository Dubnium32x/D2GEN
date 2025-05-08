** GENERATED CODE USING DLANG AND D2GEN COMPILER **
        ORG $1000
        JSR __global_init
        JMP main

__global_init:
        rts
initMatrix:
        ; Function prologue
        move.l A6, -(SP)
        move.l SP, A6
        ; DEBUG: generateExpr called with type: ast.nodes.IntLiteral
        move.l #0, D1
        move.l D1, i
for_start_0:
        ; DEBUG: generateExpr called with type: ast.nodes.BinaryExpr
        ; DEBUG: generateExpr called with type: ast.nodes.VarExpr
        move.l i, D2
        ; DEBUG: generateExpr called with type: ast.nodes.IntLiteral
        move.l #4, D3
        cmp.l D3, D4
        blt Ltrue_2
        move.l #0, D4
        bra Lend_3
Ltrue_2:
        move.l #1, D4
Lend_3:
        move.l D4, D0
        cmp.l #0, D4
        beq for_end_1
        ; DEBUG: generateExpr called with type: ast.nodes.IntLiteral
        move.l #0, D1
        move.l D1, j
for_start_4:
        ; DEBUG: generateExpr called with type: ast.nodes.BinaryExpr
        ; DEBUG: generateExpr called with type: ast.nodes.VarExpr
        move.l j, D2
        ; DEBUG: generateExpr called with type: ast.nodes.IntLiteral
        move.l #4, D3
        cmp.l D3, D4
        blt Ltrue_6
        move.l #0, D4
        bra Lend_7
Ltrue_6:
        move.l #1, D4
Lend_7:
        move.l D4, D0
        cmp.l #0, D4
        beq for_end_5
        ; DEBUG: generateExpr called with type: ast.nodes.BinaryExpr
        ; DEBUG: generateExpr called with type: ast.nodes.VarExpr
        move.l i, D1
        ; DEBUG: generateExpr called with type: ast.nodes.VarExpr
        move.l j, D2
        cmp.l D2, D3
        beq Ltrue_10
        move.l #0, D3
        bra Lend_11
Ltrue_10:
        move.l #1, D3
Lend_11:
        move.l D3, D0
        cmpa.l D3, A1
        beq else_8
        ; DEBUG: Entered handleAssignStmt. LHS type: ast.nodes.ArrayAccessExpr
        ; DEBUG: Array access with arrayName = complex_expr
        ; WARNING: Complex array expression detected. Using dynamic array approach.
        ; DEBUG: generateExpr called with type: ast.nodes.IntLiteral
        move.l #1, D1
        ; DEBUG: generateExpr called with type: ast.nodes.VarExpr
        move.l j, D2
        move.l D2, D3
        mulu #4, D3
        lea complex_array, A0
        move.l D1, (A0,D3.l)
        bra endif_9
else_8:
        ; DEBUG: Entered handleAssignStmt. LHS type: ast.nodes.ArrayAccessExpr
        ; DEBUG: Array access with arrayName = complex_expr
        ; WARNING: Complex array expression detected. Using dynamic array approach.
        ; DEBUG: generateExpr called with type: ast.nodes.IntLiteral
        move.l #0, D1
        ; DEBUG: generateExpr called with type: ast.nodes.VarExpr
        move.l j, D2
        move.l D2, D3
        mulu #4, D3
        lea complex_array, A0
        move.l D1, (A0,D3.l)
endif_9:
        ; DEBUG: Entered handleAssignStmt. LHS type: ast.nodes.VarExpr
        ; DEBUG: generateExpr called with type: ast.nodes.BinaryExpr
        ; DEBUG: generateExpr called with type: ast.nodes.VarExpr
        move.l j, D1
        ; DEBUG: generateExpr called with type: ast.nodes.IntLiteral
        move.l #1, D2
        move.l D1, D3
        add.l D2, D3
        move.l D3, j
        bra for_start_4
for_end_5:
        ; DEBUG: Entered handleAssignStmt. LHS type: ast.nodes.VarExpr
        ; DEBUG: generateExpr called with type: ast.nodes.BinaryExpr
        ; DEBUG: generateExpr called with type: ast.nodes.VarExpr
        move.l i, D1
        ; DEBUG: generateExpr called with type: ast.nodes.IntLiteral
        move.l #1, D2
        move.l D1, D3
        add.l D2, D3
        move.l D3, i
        bra for_start_0
for_end_1:
        ; Function epilogue
        move.l (SP)+, A6
        rts
setupModel:
        ; Function prologue
        move.l A6, -(SP)
        move.l SP, A6
        move.l 8(A6), D0
        move.l 12(A6), D1
        move.l 16(A6), D2
        move.l 20(A6), D3
        ; DEBUG: Entered handleAssignStmt. LHS type: ast.nodes.StructFieldAccess
        ; DEBUG: Field path: x.position, Base type: ArrayAccessExpr
        ; DEBUG: generateExpr called with type: ast.nodes.VarExpr
        ; DEBUG: generateExpr called with type: ast.nodes.VarExpr
        ; DEBUG: Entered handleAssignStmt. LHS type: ast.nodes.StructFieldAccess
        ; DEBUG: Field path: y.position, Base type: ArrayAccessExpr
        ; DEBUG: generateExpr called with type: ast.nodes.VarExpr
        ; DEBUG: generateExpr called with type: ast.nodes.VarExpr
        ; DEBUG: Entered handleAssignStmt. LHS type: ast.nodes.StructFieldAccess
        ; DEBUG: Field path: z.position, Base type: ArrayAccessExpr
        ; DEBUG: generateExpr called with type: ast.nodes.VarExpr
        ; DEBUG: generateExpr called with type: ast.nodes.VarExpr
        ; DEBUG: Entered handleAssignStmt. LHS type: ast.nodes.StructFieldAccess
        ; DEBUG: Field path: type.material, Base type: ArrayAccessExpr
        ; DEBUG: generateExpr called with type: ast.nodes.VarExpr
        ; DEBUG: generateExpr called with type: ast.nodes.IntLiteral
        move.l #2, D1
        ; DEBUG: Entered handleAssignStmt. LHS type: ast.nodes.StructFieldAccess
        ; DEBUG: Field path: shininess.material, Base type: ArrayAccessExpr
        ; DEBUG: generateExpr called with type: ast.nodes.VarExpr
        ; DEBUG: generateExpr called with type: ast.nodes.BinaryExpr
        ; DEBUG: generateExpr called with type: ast.nodes.VarExpr
        ; DEBUG: generateExpr called with type: ast.nodes.IntLiteral
        move.l #10, D1
        muls D1, D0
        ; DEBUG: Entered handleAssignStmt. LHS type: ast.nodes.ArrayAccessExpr
        ; DEBUG: Array access with arrayName = complex_expr
        ; WARNING: Complex array expression detected. Using dynamic array approach.
        ; DEBUG: generateExpr called with type: ast.nodes.IntLiteral
        move.l #255, D1
        ; DEBUG: generateExpr called with type: ast.nodes.IntLiteral
        move.l #0, D2
        move.l D2, D3
        mulu #4, D3
        lea complex_array, A0
        move.l D1, (A0,D3.l)
        ; DEBUG: Entered handleAssignStmt. LHS type: ast.nodes.ArrayAccessExpr
        ; DEBUG: Array access with arrayName = complex_expr
        ; WARNING: Complex array expression detected. Using dynamic array approach.
        ; DEBUG: generateExpr called with type: ast.nodes.IntLiteral
        move.l #128, D1
        ; DEBUG: generateExpr called with type: ast.nodes.IntLiteral
        move.l #1, D2
        move.l D2, D3
        mulu #4, D3
        lea complex_array, A0
        move.l D1, (A0,D3.l)
        ; DEBUG: Entered handleAssignStmt. LHS type: ast.nodes.ArrayAccessExpr
        ; DEBUG: Array access with arrayName = complex_expr
        ; WARNING: Complex array expression detected. Using dynamic array approach.
        ; DEBUG: generateExpr called with type: ast.nodes.IntLiteral
        move.l #0, D1
        ; DEBUG: generateExpr called with type: ast.nodes.IntLiteral
        move.l #2, D2
        move.l D2, D3
        mulu #4, D3
        lea complex_array, A0
        move.l D1, (A0,D3.l)
        ; DEBUG: generateExpr called with type: ast.nodes.BinaryExpr
        ; DEBUG: generateExpr called with type: ast.nodes.VarExpr
        ; DEBUG: generateExpr called with type: ast.nodes.IntLiteral
        move.l #0, D1
        cmp.l D1, D2
        bgt Ltrue_14
        move.l #0, D2
        bra Lend_15
Ltrue_14:
        move.l #1, D2
Lend_15:
        move.l D2, D0
        cmpa.l D2, A1
        beq else_12
        ; DEBUG: Entered handleAssignStmt. LHS type: ast.nodes.StructFieldAccess
        ; DEBUG: Field path: scale, Base type: ArrayAccessExpr
        ; DEBUG: generateExpr called with type: ast.nodes.VarExpr
        ; DEBUG: generateExpr called with type: ast.nodes.StructFieldAccess
        lea models, A1
        ; DEBUG: generateExpr called with type: ast.nodes.IntLiteral
        move.l #0, D2
        move.l D2, D3
        mulu #4, D3
        add.l D3, A1
        move.l 0(A1), D1
        bra endif_13
else_12:
        ; DEBUG: Entered handleAssignStmt. LHS type: ast.nodes.StructFieldAccess
        ; DEBUG: Field path: x.scale, Base type: ArrayAccessExpr
        ; DEBUG: generateExpr called with type: ast.nodes.VarExpr
        ; DEBUG: generateExpr called with type: ast.nodes.IntLiteral
        move.l #1, D1
        ; DEBUG: Entered handleAssignStmt. LHS type: ast.nodes.StructFieldAccess
        ; DEBUG: Field path: y.scale, Base type: ArrayAccessExpr
        ; DEBUG: generateExpr called with type: ast.nodes.VarExpr
        ; DEBUG: generateExpr called with type: ast.nodes.IntLiteral
        move.l #1, D1
        ; DEBUG: Entered handleAssignStmt. LHS type: ast.nodes.StructFieldAccess
        ; DEBUG: Field path: z.scale, Base type: ArrayAccessExpr
        ; DEBUG: generateExpr called with type: ast.nodes.VarExpr
        ; DEBUG: generateExpr called with type: ast.nodes.IntLiteral
        move.l #1, D1
endif_13:
        ; DEBUG: Entered handleAssignStmt. LHS type: ast.nodes.StructFieldAccess
        ; DEBUG: Field path: id, Base type: ArrayAccessExpr
        ; DEBUG: generateExpr called with type: ast.nodes.VarExpr
        ; DEBUG: generateExpr called with type: ast.nodes.BinaryExpr
        ; DEBUG: generateExpr called with type: ast.nodes.ArrayAccessExpr
        ; Handling complex array expression
        ; DEBUG: generateExpr called with type: ast.nodes.BinaryExpr
        ; DEBUG: generateExpr called with type: ast.nodes.VarExpr
        ; DEBUG: generateExpr called with type: ast.nodes.IntLiteral
        move.l #4, D1
        move.l D0, D2
        divs D1, D1
        muls D1, D1
        sub.l D1, D0
        move.l D2, D1
        mulu #4, D1
        lea complex_array, A0
        move.l (A0,D1.l), D2
        ; DEBUG: generateExpr called with type: ast.nodes.IntLiteral
        move.l #100, D3
        move.l D2, D4
        add.l D3, D4
        ; Function epilogue
        move.l (SP)+, A6
        rts
main:
        ; Function prologue
        move.l A6, -(SP)
        move.l SP, A6
        bsr initMatrix
        ; DEBUG: generateExpr called with type: ast.nodes.IntLiteral
        move.l #0, D1
        move.l D1, i
for_start_16:
        ; DEBUG: generateExpr called with type: ast.nodes.BinaryExpr
        ; DEBUG: generateExpr called with type: ast.nodes.VarExpr
        move.l i, D2
        ; DEBUG: generateExpr called with type: ast.nodes.IntLiteral
        move.l #3, D3
        cmp.l D3, D4
        blt Ltrue_18
        move.l #0, D4
        bra Lend_19
Ltrue_18:
        move.l #1, D4
Lend_19:
        move.l D4, D0
        cmp.l #0, D4
        beq for_end_17
        ; DEBUG: generateExpr called with type: ast.nodes.BinaryExpr
        ; DEBUG: generateExpr called with type: ast.nodes.VarExpr
        move.l i, D1
        ; DEBUG: generateExpr called with type: ast.nodes.IntLiteral
        move.l #30, D2
        move.l D1, D0
        muls D2, D0
        move.l D0, -(SP)
        ; DEBUG: generateExpr called with type: ast.nodes.BinaryExpr
        ; DEBUG: generateExpr called with type: ast.nodes.VarExpr
        move.l i, D1
        ; DEBUG: generateExpr called with type: ast.nodes.IntLiteral
        move.l #20, D2
        move.l D1, D0
        muls D2, D0
        move.l D0, -(SP)
        ; DEBUG: generateExpr called with type: ast.nodes.BinaryExpr
        ; DEBUG: generateExpr called with type: ast.nodes.VarExpr
        move.l i, D1
        ; DEBUG: generateExpr called with type: ast.nodes.IntLiteral
        move.l #10, D2
        move.l D1, D0
        muls D2, D0
        move.l D0, -(SP)
        ; DEBUG: generateExpr called with type: ast.nodes.VarExpr
        move.l i, D1
        move.l D1, -(SP)
        bsr setupModel
        add.l #16, SP
        ; DEBUG: Entered handleAssignStmt. LHS type: ast.nodes.VarExpr
        ; DEBUG: generateExpr called with type: ast.nodes.BinaryExpr
        ; DEBUG: generateExpr called with type: ast.nodes.VarExpr
        move.l i, D1
        ; DEBUG: generateExpr called with type: ast.nodes.IntLiteral
        move.l #1, D2
        move.l D1, D3
        add.l D2, D3
        move.l D3, i
        bra for_start_16
for_end_17:
        ; DEBUG: generateExpr called with type: ast.nodes.BinaryExpr
        ; DEBUG: generateExpr called with type: ast.nodes.IntLiteral
        move.l #1, D1
        ; DEBUG: generateExpr called with type: ast.nodes.IntLiteral
        move.l #1, D2
        move.l D1, D3
        add.l D2, D3
        move.l D3, idx
        ; DEBUG: Entered handleAssignStmt. LHS type: ast.nodes.StructFieldAccess
        ; DEBUG: Field path: x.position, Base type: ArrayAccessExpr
        ; DEBUG: generateExpr called with type: ast.nodes.VarExpr
        move.l idx, D1
        ; DEBUG: generateExpr called with type: ast.nodes.BinaryExpr
        ; DEBUG: generateExpr called with type: ast.nodes.StructFieldAccess
        lea models, A2
        ; DEBUG: generateExpr called with type: ast.nodes.BinaryExpr
        ; DEBUG: generateExpr called with type: ast.nodes.VarExpr
        move.l idx, D3
        ; DEBUG: generateExpr called with type: ast.nodes.IntLiteral
        move.l #1, D4
        move.l D3, D5
        sub.l D4, D5
        move.l D5, D3
        mulu #4, D3
        add.l D3, A2
        move.l 0(A2), D2
        ; DEBUG: generateExpr called with type: ast.nodes.StructFieldAccess
        lea models, A3
        ; DEBUG: generateExpr called with type: ast.nodes.IntLiteral
        move.l #0, D4
        move.l D4, D5
        mulu #4, D5
        add.l D5, A3
        move.l 0(A3), D3
        move.l D2, D4
        add.l D3, D4
        ; Function epilogue
        move.l (SP)+, A6
        rts

        ; String literals
        ; Scalar and struct variables
models:    ds.l 1
complex_array:    ds.l 100
i:    ds.l 1
idx:    ds.l 1
j:    ds.l 1
        ; Array labels
        ; Loop variables

        SIMHALT
        END