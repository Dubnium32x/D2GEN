module ast.nodes;

interface ASTNode {}

class ReturnStmt : ASTNode {
    ASTNode value;
    this(ASTNode v) {
        value = v;
    }
}


class VarDecl : ASTNode {
    string name;
    ASTNode value;
    this(string n, ASTNode v) {
        name = n;
        value = v;
    }
}

class BinaryExpr : ASTNode {
    string op;
    ASTNode left, right;
    this(string o, ASTNode l, ASTNode r) {
        op = o;
        left = l;
        right = r;
    }
}

class VarExpr : ASTNode {
    string name;
    this(string n) { name = n; }
}

class IntLiteral : ASTNode {
    int value;
    this(int v) { value = v; }
}
