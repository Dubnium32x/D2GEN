module frontend.parser;

import frontend.lexer;
import ast.nodes;

private Token[] tokens;
private size_t index;

ASTNode[] parse(Token[] inputTokens) {
    return parseProgram(inputTokens);
}

// ---------------------------
// 🔧 XP-safe helper functions
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

Token expectAny(TokenType a, TokenType b, TokenType c = TokenType.Eof, TokenType d = TokenType.Eof) {
    Token t = current();
    if (!checkAny(a, b, c, d)) {
        throw new Exception("Expected one of [" ~ a.stringof ~ ", " ~ b.stringof ~ ", " ~ c.stringof ~ ", " ~ d.stringof ~ "], got " ~ t.type.stringof ~ " at '" ~ t.lexeme ~ "'");
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
    ASTNode left = parseUnary(); // ? use parseUnary instead!

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

ASTNode parseUnary() {
    if (check(TokenType.Bang)) {
        Token op = advance(); // consume '!'
        ASTNode right = parseUnary(); // support nested like !!x
        return new UnaryExpr(op.lexeme, right);
    }

    return parsePrimary(); // fallback
}


ASTNode parsePrimary() {
	if (check(TokenType.True)) {
		advance();
		return new IntLiteral(1); // Represent as literal for now
	}
	if (check(TokenType.False)) {
		advance();
		return new IntLiteral(0); // Represent as literal for now
	}

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
	
	if (check(TokenType.StringLiteral)) {
		return new StringLiteral(advance().lexeme);
	}

    throw new Exception("Unexpected token in expression: " ~ current().lexeme ~ " (" ~ current().type.stringof ~ ")");
}

ASTNode parseStatement() {
	if (checkAny(TokenType.Int, TokenType.Bool, TokenType.String)) {
		Token typeToken = expectAny(TokenType.Int, TokenType.Bool, TokenType.String);
		string name = expect(TokenType.Identifier).lexeme;
		expect(TokenType.Assign);
		ASTNode val = parseExpression();
		expect(TokenType.Semicolon);
		return new VarDecl(typeToken.lexeme, name, val); // Assuming you added `type` to VarDecl
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
		advance(); // skip 'if'
		expect(TokenType.LParen);
		ASTNode cond = parseExpression();
		expect(TokenType.RParen);
		ASTNode[] thenBody = parseBlock();

		ASTNode[] elseBody;
		if (check(TokenType.Else)) {
			advance(); // skip 'else'

			if (check(TokenType.If)) {
				elseBody ~= parseStatement(); // ? recursively chain
			} else {
				elseBody = parseBlock(); // regular else block
			}
		}
		
		return new IfStmt(cond, thenBody, elseBody);
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
	else if (check(TokenType.Identifier) && current().lexeme == "print") {
		advance(); // skip 'print'
		expect(TokenType.LParen);
		ASTNode val = parseExpression();
		expect(TokenType.RParen);
		expect(TokenType.Semicolon);
		return new PrintStmt(val);
	}
    else if (check(TokenType.For) && peek().type == TokenType.LParen) {
        advance(); // consume 'for'

        if (check(TokenType.LParen)) {
            // C-style for loop
            advance(); // consume '('

            ASTNode init = parseStatement(); // or parseExpression if you're just doing expressions
            expect(TokenType.Semicolon);

            ASTNode cond = parseExpression();
            expect(TokenType.Semicolon);

            ASTNode inc = parseExpression();
            expect(TokenType.RParen);

            ASTNode[] body = parseBlock();
            return new CStyleForStmt(init, cond, inc, body);
        }
        else if (check(TokenType.Identifier) && peek().type == TokenType.To) {
            // Range-style for loop
            string varName = expect(TokenType.Identifier).lexeme;
            expect(TokenType.Assign);
            ASTNode start = parseExpression();
            expect(TokenType.To);
            ASTNode end = parseExpression();

            ASTNode step = new IntLiteral(1); // default step
            if (check(TokenType.Step)) {
                advance(); // consume 'step'
                step = parseExpression();
            }

            ASTNode[] body = parseBlock();
            return new ForStmt(varName, start, end, step, body);
        }
        else {
            throw new Exception("Unexpected token after 'for': " ~ current().lexeme);
        }
    }

	
	if (check(TokenType.True)) {
		advance();
		return new BoolLiteral(true);
	}
	if (check(TokenType.False)) {
		advance();
		return new BoolLiteral(false);
	}
	
    throw new Exception("Unknown statement at token: " ~ tokens[index].lexeme);
}

ASTNode[] parseBlock() {
    ASTNode[] parseBody;

    expect(TokenType.LBrace);
    while (!check(TokenType.RBrace) && !check(TokenType.Eof)) {
        parseBody ~= parseStatement();
    }
    expect(TokenType.RBrace);

    return parseBody;
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
    if (check(TokenType.OrOr)) return 1;  // Lower precedence than &&
    if (check(TokenType.AndAnd)) return 2; // Higher precedence than ||
    if (check(TokenType.EqualEqual) || check(TokenType.NotEqual)) return 3; // Comparison operators
    if (check(TokenType.Less) || check(TokenType.LessEqual) || check(TokenType.Greater) || check(TokenType.GreaterEqual)) return 4;
    if (check(TokenType.Plus) || check(TokenType.Minus)) return 5;
    if (check(TokenType.Star) || check(TokenType.Slash)) return 6;
    if (check(TokenType.Assign)) return 0; // Lowest precedence
    return -1; // Default for unknown tokens
}

Token peek() {
    return (index + 1 < tokens.length) ? tokens[index + 1] : Token(TokenType.Eof, "");
}


