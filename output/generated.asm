** GENERATED CODE USING DLANG AND D2GEN COMPILER **
        ORG $1000
        JSR __global_init
        JMP main

__global_init:
        rts
initBoxes:
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
        move.l #3, D3
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
        ; DEBUG: Entered handleAssignStmt. LHS type: ast.nodes.StructFieldAccess
        ; DEBUG: Field path: x.min, Base type: ArrayAccessExpr
        ; DEBUG: generateExpr called with type: ast.nodes.VarExpr
        move.l i, D1
        ; DEBUG: generateExpr called with type: ast.nodes.BinaryExpr
        ; DEBUG: generateExpr called with type: ast.nodes.VarExpr
        move.l i, D2
        ; DEBUG: generateExpr called with type: ast.nodes.IntLiteral
        move.l #10, D3
        move.l D2, D0
        muls D3, D0
        ; DEBUG: Field: x, ElementSize: 20, Offset: 0
        move.l D1, D5
        mulu #20, D5
        lea boxes, A0
        add.l D5, A0
        move.l D0, 0(A0)
        ; DEBUG: Entered handleAssignStmt. LHS type: ast.nodes.StructFieldAccess
        ; DEBUG: Field path: y.min, Base type: ArrayAccessExpr
        ; DEBUG: generateExpr called with type: ast.nodes.VarExpr
        move.l i, D1
        ; DEBUG: generateExpr called with type: ast.nodes.BinaryExpr
        ; DEBUG: generateExpr called with type: ast.nodes.VarExpr
        move.l i, D2
        ; DEBUG: generateExpr called with type: ast.nodes.IntLiteral
        move.l #20, D3
        move.l D2, D0
        muls D3, D0
        ; DEBUG: Field: y, ElementSize: 20, Offset: 4
        move.l D1, D5
        mulu #20, D5
        lea boxes, A0
        add.l D5, A0
        move.l D0, 4(A0)
        ; DEBUG: Entered handleAssignStmt. LHS type: ast.nodes.StructFieldAccess
        ; DEBUG: Field path: x.max, Base type: ArrayAccessExpr
        ; DEBUG: generateExpr called with type: ast.nodes.VarExpr
        move.l i, D1
        ; DEBUG: generateExpr called with type: ast.nodes.BinaryExpr
        ; DEBUG: generateExpr called with type: ast.nodes.BinaryExpr
        ; DEBUG: generateExpr called with type: ast.nodes.VarExpr
        move.l i, D2
        ; DEBUG: generateExpr called with type: ast.nodes.IntLiteral
        move.l #10, D3
        move.l D2, D0
        muls D3, D0
        ; DEBUG: generateExpr called with type: ast.nodes.IntLiteral
        move.l #5, D5
        move.l D0, D6
        add.l D5, D6
        ; DEBUG: Field: x, ElementSize: 20, Offset: 8
        move.l D1, D7
        mulu #20, D7
        lea boxes, A0
        add.l D7, A0
        move.l D6, 8(A0)
        ; DEBUG: Entered handleAssignStmt. LHS type: ast.nodes.StructFieldAccess
        ; DEBUG: Field path: y.max, Base type: ArrayAccessExpr
        ; DEBUG: generateExpr called with type: ast.nodes.VarExpr
        move.l i, D1
        ; DEBUG: generateExpr called with type: ast.nodes.BinaryExpr
        ; DEBUG: generateExpr called with type: ast.nodes.BinaryExpr
        ; DEBUG: generateExpr called with type: ast.nodes.VarExpr
        move.l i, D2
        ; DEBUG: generateExpr called with type: ast.nodes.IntLiteral
        move.l #20, D3
        move.l D2, D0
        muls D3, D0
        ; DEBUG: generateExpr called with type: ast.nodes.IntLiteral
        move.l #5, D5
        move.l D0, D6
        add.l D5, D6
        ; DEBUG: Field: y, ElementSize: 20, Offset: 12
        move.l D1, D7
        mulu #20, D7
        lea boxes, A0
        add.l D7, A0
        move.l D6, 12(A0)
        ; DEBUG: Entered handleAssignStmt. LHS type: ast.nodes.StructFieldAccess
        ; DEBUG: Field path: colorIndex, Base type: ArrayAccessExpr
        ; DEBUG: generateExpr called with type: ast.nodes.VarExpr
        move.l i, D1
        ; DEBUG: generateExpr called with type: ast.nodes.BinaryExpr
        ; DEBUG: generateExpr called with type: ast.nodes.VarExpr
        move.l i, D2
        ; DEBUG: generateExpr called with type: ast.nodes.IntLiteral
        move.l #16, D3
        move.l D2, D4
        divs D3, D1
        muls D3, D1
        sub.l D1, D2
        ; DEBUG: Field: colorIndex, ElementSize: 20, Offset: 16
        move.l D1, D5
        mulu #20, D5
        lea boxes, A0
        add.l D5, A0
        move.l D4, 16(A0)
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
        ; DEBUG: Entered handleAssignStmt. LHS type: ast.nodes.ArrayAccessExpr
        ; DEBUG: generateExpr called with type: ast.nodes.IntLiteral
        move.l #42, D1
        lea colorTable, A0
        move.l D1, 0(A0)
        ; DEBUG: Entered handleAssignStmt. LHS type: ast.nodes.ArrayAccessExpr
        ; DEBUG: generateExpr called with type: ast.nodes.IntLiteral
        move.l #99, D1
        lea colorTable, A0
        move.l D1, 4(A0)
        ; Function epilogue
        move.l (SP)+, A6
        rts
main:
        ; Function prologue
        move.l A6, -(SP)
        move.l SP, A6
        bsr initBoxes
        ; DEBUG: Entered handleAssignStmt. LHS type: ast.nodes.StructFieldAccess
        ; DEBUG: Field path: x.min, Base type: ArrayAccessExpr
        ; DEBUG: generateExpr called with type: ast.nodes.IntLiteral
        move.l #1, D1
        ; DEBUG: generateExpr called with type: ast.nodes.IntLiteral
        move.l #123, D2
        ; DEBUG: Field: x, ElementSize: 20, Offset: 0
        move.l D1, D3
        mulu #20, D3
        lea boxes, A0
        add.l D3, A0
        move.l D2, 0(A0)
        ; DEBUG: Entered handleAssignStmt. LHS type: ast.nodes.StructFieldAccess
        ; DEBUG: Field path: colorIndex, Base type: ArrayAccessExpr
        ; DEBUG: generateExpr called with type: ast.nodes.IntLiteral
        move.l #2, D1
        ; DEBUG: generateExpr called with type: ast.nodes.ArrayAccessExpr
        ; DEBUG: generateExpr called with type: ast.nodes.IntLiteral
        move.l #1, D2
        lea colorTable, A0
        move.l D2, D3
        mulu #4, D3
        add.l D3, A0
        move.l (A0), D3
        ; DEBUG: Field: colorIndex, ElementSize: 20, Offset: 16
        move.l D1, D5
        mulu #20, D5
        lea boxes, A0
        add.l D5, A0
        move.l D3, 16(A0)
        ; Function epilogue
        move.l (SP)+, A6
        rts

        ; String literals
        ; Scalar and struct variables
i:    ds.l 1
boxes:    ds.l 1
colorTable:    ds.l 1
        ; Array labels
        ; Loop variables

        SIMHALT
        END