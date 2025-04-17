module compiler.ast;

import compiler.lexer;

abstract class ASTNode {
    size_t line;
    size_t column;
    this(size_t line, size_t column) {
        this.line = line;
        this.column = column;
    }
	
	// pure virtual function for node type identification
	abstract string nodeType() const;
}

class FunctionDecl : ASTNode {
    string name;
    ASTNode[] bodyStatements;
    this(string name, ASTNode[] stmts, size_t line, size_t column) {
        super(line, column);
        this.name = name;
        this.bodyStatements = stmts;
    }
	
	override string nodeType() const {
		return "FunctionDecl";
	}
}

class ReturnStmt : ASTNode {
    ASTNode expression;
    this(ASTNode expr, size_t line, size_t column) {
        super(line, column);
        this.expression = expr;
    }
	
	override string nodeType() const {
		return "ReturnStmt";
	}
}

class VarDecl : ASTNode {
	string name;
	string type;
	ASTNode initialValue;
	
	this(string name, string type, ASTNode initVal,  size_t line, size_t column) {
		super(line, column);
		this.name = name;
		this.type = type;
		this.initialValue = initVal;
	}
	
	override string nodeType() const { return "VarDecl"; }
}

class VarBlock : ASTNode {
	VarDecl[] declarations;
	
	this(VarDecl[] decls, size_t line, size_t column) {
		super(line, column);
		this.declarations = decls;
	}
	
	override string nodeType() const { return "VarBlock"; }
}

abstract class Expression : ASTNode {
	// base class for all expressions
	this(size_t line, size_t column) {
		super(line, column);
	}
	override string nodeType() const { return "Expression"; }
}

class ExpressionStmt : ASTNode {
	Expression expr;
	this(Expression e, size_t line, size_t column) {
		super(line, column);
		this.expr = e;
	}
	
	override string nodeType() const { return "ExpressionStmt"; }
}

class IfStmt : ASTNode {
	Expression condition;
	ASTNode thenBranch;
	ASTNode elseBranch;
	
	this(Expression cond, ASTNode thenBr, ASTNode elseBr, size_t line, size_t column) {
		super(line, column);
		this.condition = cond;
		this.thenBranch = thenBr;
		this.elseBranch = elseBr;
	}
	
	override string nodeType() const { return "IfStmt"; }
}

class WhileStmt : ASTNode {
	Expression condition;
	ASTNode whileBody;
	
	this(Expression cond, ASTNode whileBody, size_t line, size_t column) {
		super(line, column);
		this.condition = cond;
		this.whileBody = whileBody;
	}
	
	override string nodeType() const { return "WhileStmt"; }
}

class Instruction : ASTNode {
	string type;
	bool isSigned;
	int size;
	string src;
	string dest;
	
	this(string type, bool isSigned, int size, string src, string dest, size_t line, size_t column) {
		super(line, column);
		this.type = type;
		this.isSigned = isSigned;
		this.size = size;
		this.src = src;
		this.dest = dest;
	}
	
	override string nodeType() const { return "Instruction"; }
}


class BinaryOp : Expression {
	string op;
	Expression left;
	Expression right;
	
	this(string op, Expression l, Expression r, size_t line, size_t column) {
		super(line, column);
		this.op = op;
		this.left = l;
		this.right = r;
	}
}

class Literal : Expression {
	string value;
	
	this(string val, size_t line, size_t column) {
		super(line, column);
		this.value = val;
	}
	
	override string nodeType() const { return "Literal"; }
}

// Add more AST nodes as needed (variables, expressions, etc.)
