module ast.conditional_expr;

// Import ASTNode as a forward declaration to avoid circular dependencies
// The ASTNode class should be defined in nodes.d before this file is imported
import ast.nodes : ASTNode;

// Define a new AST node type for ternary conditional expressions
class ConditionalExpr : ASTNode {
    ASTNode condition;
    ASTNode trueExpr;
    ASTNode falseExpr;
    
    this(ASTNode cond, ASTNode tExpr, ASTNode fExpr) {
        condition = cond;
        trueExpr = tExpr;
        falseExpr = fExpr;
    }
    
    override string toString() const {
        import std.format : format;
        // Cast to remove const for toString calls
        return format("ConditionalExpr(%s ? %s : %s)", 
                     (cast()condition).toString(), 
                     (cast()trueExpr).toString(), 
                     (cast()falseExpr).toString());
    }
}
