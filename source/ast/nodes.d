module ast.nodes;

abstract class ASTNode {}

class ReturnStmt : ASTNode {
    ASTNode value;
    this(ASTNode v) {
        value = v;
    }
}


class VarDecl : ASTNode {
    string name;
    string type;
    ASTNode value;

    this(string t, string n, ASTNode v) {
        type = t;
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

class IfStmt : ASTNode {
    ASTNode condition;
    ASTNode[] thenBody;
    ASTNode[] elseBody; // Added elseBody for else branch

    this(ASTNode cond, ASTNode[] thenBody, ASTNode[] elseBody = []) {
        this.condition = cond;
        this.thenBody = thenBody;
        this.elseBody = elseBody;
    }
}

class WhileStmt : ASTNode {
    ASTNode condition;
    ASTNode[] loopBody;

    this(ASTNode cond, ASTNode[] loopBody) {
        this.condition = cond;
        this.loopBody = loopBody;
    }
}

class AssignStmt : ASTNode {
    string name;
    ASTNode value;

    this(string n, ASTNode v) {
        name = n;
        value = v;
    }
}

class UnaryExpr : ASTNode {
    string op;
    ASTNode expr;

    this(string op, ASTNode expr) {
        this.op = op;
        this.expr = expr;
    }
}

class BoolLiteral : ASTNode {
    bool value;
    this(bool v) {
        value = v;
    }
}


