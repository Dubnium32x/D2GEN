module ast.nodes;

import std.string;

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

class PrintStmt : ASTNode {
    ASTNode value;
    this(ASTNode v) {
        value = v;
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

class StringLiteral : ASTNode {
    string value;
    this(string v) { value = v; }
}

class ForStmt : ASTNode {
    string name;
    ASTNode start, end, step;
    ASTNode[] forBody;

    this(string n, ASTNode s, ASTNode e, ASTNode st, ASTNode[] b) {
        name = n;
        start = s;
        end = e;
        step = st;
        forBody = b;
    }
}

class CStyleForStmt : ASTNode {
    ASTNode init;
    ASTNode condition;
    ASTNode increment;
    ASTNode[] forBody;

    this(ASTNode init, ASTNode condition, ASTNode increment, ASTNode[] body) {
        this.init = init;
        this.condition = condition;
        this.increment = increment;
        this.forBody = body;
    }
}

class ExprStmt : ASTNode {
    ASTNode expr;

    this(ASTNode expr) {
        this.expr = expr;
    }
}

class FunctionDecl : ASTNode {
    string name;
    string returnType;
    string[] params;
    ASTNode[] body;

    this(string n, string rt, string[] p, ASTNode[] b) {
        name = n;
        returnType = rt;
        params = p;
        body = b;
    }
}

class BreakStmt : ASTNode {
    this() {} // Empty constructor
}

class ContinueStmt : ASTNode {
    this() {} // Empty constructor
}

class ArrayDecl : ASTNode {
    string name;
    int size;

    this(string n, int s) {
        name = n;
        size = s;
    }
}

class SwitchStmt : ASTNode {
    ASTNode condition;
    ASTNode[] cases;

    this(ASTNode cond, ASTNode[] cs) {
        condition = cond;
        cases = cs;
    }
}

class CaseStmt : ASTNode {
    ASTNode condition;
    ASTNode[] caseBody;

    this(ASTNode cond, ASTNode[] b) {
        condition = cond;
        caseBody = b;
    }
}

class BlockStmt : ASTNode {
    ASTNode[] blockBody;

    this(ASTNode[] b) {
        blockBody = b;
    }
}

class PostfixUnaryStmt : ASTNode {
    string name;
    string op; // "++" or "--"

    this(string name, string op) {
        this.name = name;
        this.op = op;
    }
}

class PostfixExpr : ASTNode {
    string op;
    ASTNode target;

    this(string op, ASTNode target) {
        this.op = op;
        this.target = target;
    }
}
