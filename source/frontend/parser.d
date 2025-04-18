module frontend.parser;

import frontend.lexer;
import ast.nodes;

private Token[] tokens;
private size_t index;

ASTNode parse(Token[] inputTokens) {
    tokens = inputTokens;
    index = 0;

    // Parse: int main() { return 42; }
    expect(TokenType.Int);
    string name = expect(TokenType.Identifier).lexeme;
    expect(TokenType.LParen);
    expect(TokenType.RParen);
    expect(TokenType.LBrace);
    expect(TokenType.Return);
    int value = toInt(expect(TokenType.Number).lexeme);
    expect(TokenType.Semicolon);
    expect(TokenType.RBrace);
    expect(TokenType.Eof);

    return new ReturnStmt(new IntLiteral(value));
}

// ---------------------------
// 🔧 XP-safe helper functions
// ---------------------------

Token expect(TokenType kind) {
    Token t = tokens[index];
    if (t.type != kind) {
        throw new Exception("Expected " ~ kind.stringof ~ ", got " ~ t.type.stringof);
    }
    index++;
    return t;
}

int toInt(string s) {
    int val = 0;
    foreach (c; s) {
        if (c >= '0' && c <= '9') {
            val = val * 10 + (c - '0');
        }
    }
    return val;
}

ASTNode[] parseProgram(Token[] inputTokens) {
    tokens = inputTokens;
    index = 0;
    ASTNode[] stmts;

    expect(TokenType.Int); // skip return type
    expect(TokenType.Identifier); // skip 'main'
    expect(TokenType.LParen);
    expect(TokenType.RParen);
    expect(TokenType.LBrace);

    while (!check(TokenType.RBrace)) {
        if (check(TokenType.Return)) {
            advance();
            ASTNode expr = parseExpression();
            expect(TokenType.Semicolon);
            stmts ~= new ReturnStmt(expr);
        } else if (check(TokenType.Int)) {
            advance(); // skip 'int'
            string name = expect(TokenType.Identifier).lexeme;
            expect(TokenType.Equal);
            ASTNode val = parseExpression();
            expect(TokenType.Semicolon);
            stmts ~= new VarDecl(name, val);
        } else {
            throw new Exception("Unknown statement");
        }
    }

    expect(TokenType.RBrace);
    expect(TokenType.Eof);
    return stmts;
}

ASTNode parseExpression() {
    ASTNode left = parsePrimary();

    while (checkAny(TokenType.Plus, TokenType.Minus, TokenType.Star, TokenType.Slash)) {
        Token op = advance();
        ASTNode right = parsePrimary();
        left = new BinaryExpr(op.lexeme, left, right);
    }

    return left;
}

ASTNode parsePrimary() {
    if (check(TokenType.Number)) {
        return new IntLiteral(toInt(advance().lexeme));
    }
    if (check(TokenType.Identifier)) {
        return new VarExpr(advance().lexeme);
    }

    throw new Exception("Unexpected token in expression");
}

Token advance() {
    return tokens[index++];
}

bool check(TokenType kind) {
    return tokens[index].type == kind;
}

bool checkAny(TokenType a, TokenType b, TokenType c = TokenType.Eof, TokenType d = TokenType.Eof) {
    auto t = tokens[index].type;
    return t == a || t == b || t == c || t == d;
}

