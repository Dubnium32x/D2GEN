module ast.nodes;

import std.string;
import std.array;
import std.algorithm : map;
import std.conv : to;

// Class declaration must come before import to break circular dependency
abstract class ASTNode {}

// Now we can import the ConditionalExpr class
public import ast.conditional_expr;

struct TemplateParam {
    string name;
    string defaultValue;  // Optional default value (empty if none)
}

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
    string visibility;
    bool isConst;  // New field to indicate if this is a constant

    this(string t, string n, ASTNode v, string vis = "public", bool isConst = false) {
        type = t;
        name = n;
        value = v;
        visibility = vis;
        this.isConst = isConst;
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
    string functionName;
    ASTNode[] values;

    this(string functionName, ASTNode[] values) {
        this.functionName = functionName;
        this.values = values;
    }
}
class AssignStmt : ASTNode {
    ASTNode lhs;
    ASTNode value;

    this(ASTNode lhs, ASTNode value) {
        this.lhs = lhs;
        this.value = value;
    }
}

class ArrayLiteralExpr : ASTNode {
    ASTNode[] elements;
    this(ASTNode[] elements) {
        this.elements = elements;
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

class BreakStmt : ASTNode {
    this() {} // Empty constructor
}

class ContinueStmt : ASTNode {
    this() {} // Empty constructor
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
    int value; // Can be null for `default`
    ASTNode condition; // Can be null for `default`
    ASTNode[] caseBody;

    this(int value, ASTNode cond, ASTNode[] caseBody) {
        this.value = value;
        this.condition = cond;
        this.caseBody = caseBody;
    }
}

class BlockStmt : ASTNode {
    ASTNode[] blockBody;

    this(ASTNode[] blockBody) {
        this.blockBody = blockBody;
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

class ByteLiteral : ASTNode {
    byte value;
    this(byte v) { value = v; }
}

class ArrayLiteral : ASTNode {
    ASTNode[] elements;
    this(ASTNode[] elems) {
        elements = elems;
    }
}

class ArrayDecl : ASTNode {
    string type;
    string name;
    ASTNode[] elements;

    this(string type, string name, ASTNode[] elements) {
        this.type = type;
        this.name = name;
        this.elements = elements;
    }
}

class ArrayAccessExpr : ASTNode {
    string arrayName;
    ASTNode index;
    ASTNode baseExpr; // For multi-dimensional array access
    
    this(string name, ASTNode idx) {
        arrayName = name;
        index = idx;
        baseExpr = null;
    }
    
    // Add a constructor that also sets baseExpr for multi-dimensional arrays
    this(string name, ASTNode idx, ASTNode base) {
        arrayName = name;
        index = idx;
        baseExpr = base;
    }
}


class FunctionDecl : ASTNode {
    string name;
    string returnType;
    ParamInfo[] params;
    ASTNode[] funcBody;
    VarParam[] varParams; // <-- Add this field

    this(string name, string returnType, ParamInfo[] params, ASTNode[] funcBody, VarParam[] varParams = []) {
        this.name = name;
        this.returnType = returnType;
        this.params = params;
        this.funcBody = funcBody;
        this.varParams = varParams;
    }
}

class CallExpr : ASTNode {
    string name;
    ASTNode[] args;

    this(string name, ASTNode[] args) {
        this.name = name;
        this.args = args;
    }
}

class CommentStmt : ASTNode {
    string text;
    this(string text) {
        this.text = text;
    }
}

class CommentBlockStmt : ASTNode {
    string comment;
    this (string comment) {
        this.comment = comment;
    }
}

class IndexExpr : ASTNode {
    string name;
    ASTNode index;

    this(string name, ASTNode index) {
        this.name = name;
        this.index = index;
    }
}

class StructDecl : ASTNode {
    string name;
    string[] fields;
    this(string name, string[] fields) {
        this.name = name;
        this.fields = fields;
    }
}
class StructFieldAccess : ASTNode {
    ASTNode baseExpr;
    string field;

    this(ASTNode baseExpr, string field) {
        this.baseExpr = baseExpr;
        this.field = field;
    }
}

struct ParamInfo {
    string type;
    string name;
}

class EnumDecl : ASTNode {
    string name;
    string[] values;

    this(string name, string[] values) {
        this.name = name;
        this.values = values;
    }
}

class VarParam : ASTNode {
    string name;
    this(string name) {
        this.name = name;
    }
}

class CastExpr : ASTNode {
    string typeName;
    ASTNode expr;
    this(string typeName, ASTNode expr) {
        this.typeName = typeName;
        this.expr = expr;
    }
}

class FloatLiteral : ASTNode {
    double value;
    this(double v) { value = v; }
}

// Template for mixin (defining a template that can be mixed in)
class MixinTemplate : ASTNode {
    string name;
    ASTNode[] body_;
    ASTNode[] templateBody;  // Add this for backward compatibility
    TemplateParam[] parameters;
    
    this(string name, ASTNode[] body_, TemplateParam[] parameters = []) {
        this.name = name;
        this.body_ = body_;
        this.templateBody = body_;  // Set both fields to the same value
        this.parameters = parameters;
    }
}

// String mixin (generates code from a string)
class StringMixin : ASTNode {
    ASTNode stringExpr;
    
    this(ASTNode stringExpr) {
        this.stringExpr = stringExpr;
    }
}

// Template mixin (uses a previously defined template)
class TemplateMixin : ASTNode {
    string templateName;
    ASTNode[] arguments;  // Added arguments
    
    this(string templateName, ASTNode[] arguments = []) {
        this.templateName = templateName;
        this.arguments = arguments;
    }
}

class MemberExpr : ASTNode {
    ASTNode object;
    string member;
    
    this(ASTNode object, string member) {
        this.object = object;
        this.member = member;
    }
    
    override string toString() {
        return object.toString() ~ "." ~ member;
    }
}

class MemberCallExpr : ASTNode {
    ASTNode object;
    string method;
    ASTNode[] arguments;
    
    this(ASTNode object, string method, ASTNode[] arguments) {
        this.object = object;
        this.method = method;
        this.arguments = arguments;
    }
}

// For ternary conditional expressions (condition ? trueExpr : falseExpr)
class ConditionalExpr : ASTNode {
    ASTNode condition;
    ASTNode trueExpr;
    ASTNode falseExpr;
    
    this(ASTNode cond, ASTNode tExpr, ASTNode fExpr) {
        condition = cond;
        trueExpr = tExpr;
        falseExpr = fExpr;
    }
}

class AssertStmt : ASTNode {
    ASTNode condition;
    
    this(ASTNode condition) {
        this.condition = condition;
    }
}