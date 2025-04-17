module compiler.semantic;

import compiler.ast;

class SemanticAnalyzer {
    void analyze(ASTNode node) {
        if (auto fn = cast(FunctionDecl)node) {
            // Check main function exists
			foreach (stmt; fn.bodyStatements) {
				analyzeStatement(stmt);
			}
		}
    }
    
    private void analyzeStatement(ASTNode stmt) {
        if (auto ret = cast(ReturnStmt)stmt) {
            analyzeExpression(ret.expression);
        }
        // Add more checks
    }
    
    private void analyzeExpression(ASTNode expr) {
        if (auto lit = cast(Literal)expr) {
            // Check if it's a valid number
            import std.conv;
            try {
                lit.value.to!int;
            } catch (Exception e) {
                throw new Exception("Invalid number literal at line " ~ 
                                  lit.line.to!string);
            }
        }
    }
}
