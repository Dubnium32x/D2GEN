module ast.nodes;

import std.string;
import std.array;
import std.algorithm : map;
import std.conv : to;

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
    ASTNode init;
    ASTNode condition;
    ASTNode increment;
    ASTNode[] forBody;

    this(ASTNode init, ASTNode cond, ASTNode inc, ASTNode[] forBody) {
        this.init = init;
        this.condition = cond;
        this.increment = inc;
        this.forBody = forBody;
    }
}

class RangeForStmt : ASTNode {
    string varName;
    ASTNode start;
    ASTNode end;
    ASTNode step;
    ASTNode[] forBody;

    this(string varName, ASTNode start, ASTNode end, ASTNode step, ASTNode[] forBody) {
        this.varName = varName;
        this.start = start;
        this.end = end;
        this.step = step;
        this.forBody = forBody;
    }
}

class RangeLiteral : ASTNode {
    int start, end;
    this(int s, int e) { start = s; end = e; }
}

class RangeExpr : ASTNode {
    ASTNode start;
    ASTNode end;
    this(ASTNode s, ASTNode e) {
        start = s;
        end = e;
    }
}

class CStyleForStmt : ASTNode {
    ASTNode init;
    ASTNode condition;
    ASTNode increment;
    ASTNode[] forBody;

    this(ASTNode init, ASTNode condition, ASTNode increment, ASTNode[] forBody) {
        this.init = init;
        this.condition = condition;
        this.increment = increment;
        this.forBody = forBody;
    }
}

class ExprStmt : ASTNode {
    ASTNode expr;

    this(ASTNode expr) {
        this.expr = expr;
    }
}

class ForeachStmt : ASTNode {
    string varName;
    ASTNode iterable;
    ASTNode[] forEachBody;

    this(string name, ASTNode iterable, ASTNode[] forEachBody) {
        this.varName = name;
        this.iterable = iterable;
        this.forEachBody = forEachBody;
    }
}

class FunctionDecl : ASTNode {
    string name;
    string returnType;
    string[] params;
    ASTNode[] funcBody;

    this(string n, string rt, string[] p, ASTNode[] b) {
        name = n;
        returnType = rt;
        params = p;
        funcBody = b;
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

class IdentifierExpr : ASTNode {
    string name;
    this(string n) { name = n; }
}