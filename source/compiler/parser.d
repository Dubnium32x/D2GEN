module compiler.parser;

import compiler.lexer;
import compiler.ast;

import core.stdc.string;
import std.conv;

class Parser {
    private Token[] tokens;
    private size_t pos = 0;
    
    this(Token[] tokens) {
        this.tokens = tokens;
    }
    
    private Token peek(int lookahead = 0) {
        if (pos + lookahead < tokens.length) {
			return tokens[pos + lookahead];
		}
		return tokens[$-1];
    }
	
    FunctionDecl parseFunction() {

        if (peek().type != TokenType.Keyword || peek().lexeme != "int") {
            throw new Exception("Expected 'int' at line " ~ peek().line.to!string);
        }
        advance(); // Consume 'int'
        auto tok = consume(TokenType.Keyword, "Expected 'int'");
        auto nameTok = consume(TokenType.Identifier, "Expected function name");
        consume(TokenType.OpenParen, "Expected '('");
        consume(TokenType.CloseParen, "Expected ')'");
        consume(TokenType.OpenBrace, "Expected '{'");
        
        ASTNode[] bodyStatements;
        while (peek().type != TokenType.CloseBrace) {
            bodyStatements ~= parseStatement();
        }
        
        consume(TokenType.CloseBrace, "Expected '}'");
        return new FunctionDecl(nameTok.lexeme, bodyStatements, tok.line, tok.column);
    }
    
    private ASTNode parseStatement() {
        if (peek().type == TokenType.Return) {
            advance();
            auto expr = parseExpression();
            consume(TokenType.Semicolon, "Expected ';' after return");
            return new ReturnStmt(expr, peek(-2).line, peek(-2).column);
        }
        // Add more statement types here
        assert(0, "Unknown statement");
    }
    
    private ASTNode parseExpression() {
        if (peek().type == TokenType.Number) {
            auto tok = advance();
            return new Literal(tok.lexeme, tok.line, tok.column);
        }
        // Add more expression types here
        assert(0, "Unknown expression");
    }
    
    private Token advance() {
        if (pos < tokens.length) return tokens[pos++];
        return tokens[$-1]; // Return last token (EOF)
    }
    
    private Token consume(TokenType type, string message) {
        if (peek().type == type) return advance();
        throw new Exception(message);
    }
}
