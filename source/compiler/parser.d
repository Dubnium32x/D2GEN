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
// ðŸ”§ XP-safe helper functions
// ---------------------------

// Consume and return if matches
Token expect(TokenType kind) {
    Token t = current();
    if (t.type != kind) {
        throw new Exception("Expected " ~ kind.stringof ~ ", got " ~ t.type.stringof ~ " at token '" ~ t.lexeme ~ "'");
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

    // Parse: int main() { ... }
    expect(TokenType.Int);               // return type
    expect(TokenType.Identifier);       // function name
    expect(TokenType.LParen);           // (
    expect(TokenType.RParen);           // )
    expect(TokenType.LBrace);           // {

    // Parse all statements in the function body
    while (!check(TokenType.RBrace)) {
        stmts ~= parseStatement();
    }

    expect(TokenType.RBrace);           // }
    expect(TokenType.Eof);              // end of file

    return stmts;
}


ASTNode parseExpression(int prec = 0) {
    ASTNode left = parsePrimary();

    while (true) {
        int nextPrec = getPrecedence();
        if (nextPrec <= prec)
            break;

        Token op = advance();
        ASTNode right = parseExpression(nextPrec);
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

    if (check(TokenType.LParen)) {
        advance(); // skip '('
        ASTNode expr = parseExpression();
        expect(TokenType.RParen);
        return expr;
    }

    throw new Exception("Unexpected token in expression");
}

ASTNode parseStatement() {
    if (check(TokenType.Int)) {
        advance(); // skip 'int'
        string name = expect(TokenType.Identifier).lexeme;
        expect(TokenType.Assign);
        ASTNode val = parseExpression();
        expect(TokenType.Semicolon);
        return new VarDecl(name, val);
    }
	else if (check(TokenType.Identifier) && peek().type == TokenType.Assign) {
		string name = expect(TokenType.Identifier).lexeme;
		expect(TokenType.Assign);
		ASTNode value = parseExpression();
		expect(TokenType.Semicolon);
		return new AssignStmt(name, value);
	}
    else if (check(TokenType.Return)) {
        advance();
        ASTNode val = parseExpression();
        expect(TokenType.Semicolon);
        return new ReturnStmt(val);
    }
    else if (check(TokenType.If)) {
        advance();
        expect(TokenType.LParen);
        ASTNode cond = parseExpression();
        expect(TokenType.RParen);
        expect(TokenType.LBrace);
        ASTNode[] typeBody;
        while (!check(TokenType.RBrace)) {
            typeBody ~= parseStatement();
        }
        expect(TokenType.RBrace);
        return new IfStmt(cond, typeBody);
    }
    else if (check(TokenType.While)) {
        advance();
        expect(TokenType.LParen);
        ASTNode cond = parseExpression();
        expect(TokenType.RParen);
        expect(TokenType.LBrace);
        ASTNode[] typeBody;
        while (!check(TokenType.RBrace)) {
            typeBody ~= parseStatement();
        }
        expect(TokenType.RBrace);
        return new WhileStmt(cond, typeBody);
    }

    throw new Exception("Unknown statement at token: " ~ tokens[index].lexeme);
}

Token advance() {
    return tokens[index++];
}

// Current token
Token current() {
    return tokens[index];
}

bool check(TokenType kind) {
    return tokens[index].type == kind;
}

bool checkAny(TokenType a, TokenType b, TokenType c = TokenType.Eof, TokenType d = TokenType.Eof) {
    auto t = tokens[index].type;
    return t == a || t == b || t == c || t == d;
}

int getPrecedence() {
    if (check(TokenType.Plus) || check(TokenType.Minus)) return 1;
    if (check(TokenType.Star) || check(TokenType.Slash)) return 2;
    if (check(TokenType.Less)) return 3; // Add precedence for '<'
    if (check(TokenType.Greater)) return 3; // Add precedence for '>'
    if (check(TokenType.EqualEqual)) return 4; // Add precedence for '=='
    return 0;
}

Token peek() {
    return (index + 1 < tokens.length) ? tokens[index + 1] : Token(TokenType.Eof, "");
}


