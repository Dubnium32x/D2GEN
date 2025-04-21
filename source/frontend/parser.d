module frontend.parser;

import frontend.lexer;
import ast.nodes;

import std.stdio;

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
    ASTNode left = parseUnary();

    // Handle assignment if applicable
    if (check(TokenType.Assign)) {
        advance(); // consume '='
        ASTNode right = parseExpression();
        if (auto var = cast(VarExpr) left) {
            return new AssignStmt(var.name, right);
        } else {
            throw new Exception("Left-hand side of assignment must be a variable");
        }
    }
    if (check(TokenType.Number) && peek().type == TokenType.DotDot) {
        int start = toInt(advance().lexeme);
        expect(TokenType.DotDot);
        int end = toInt(expect(TokenType.Number).lexeme);
        return new RangeLiteral(start, end);
    }
    if (check(TokenType.DotDot)) {
        Token op = advance(); // consume '..'
        ASTNode right = parseExpression();
        return new RangeExpr(left, right);
    }
    

    while (true) {
        int nextPrec = getPrecedence();
        if (nextPrec <= prec)
            break;

        Token op = advance();
        ASTNode right = parseExpression(nextPrec);
        left = new BinaryExpr(op.lexeme, left, right);
    }

    if (check(TokenType.PlusPlus) || check(TokenType.MinusMinus)) {
        Token op = advance();
        return new PostfixExpr(op.lexeme, left);
    }

    return left;
}

ASTNode parseUnary() {
    if (check(TokenType.Bang)) {
        Token op = advance(); // consume '!'
        ASTNode right = parseUnary(); // support nested like !!x
        return new UnaryExpr(op.lexeme, right);
    }

    if (check(TokenType.PlusPlus) || check(TokenType.MinusMinus)) {
        Token op = advance();
        ASTNode expr = parseUnary(); // e.g., ++i -> UnaryExpr("++", i)
        return new UnaryExpr(op.lexeme, expr);
    }

    return parsePrimary(); // fallback
}


ASTNode parsePrimary() {
    if (check(TokenType.True)) {
        advance();
        return new BoolLiteral(true);
    }
    if (check(TokenType.False)) {
        advance();
        return new BoolLiteral(false);
    }

    if (check(TokenType.Number)) {
        return new IntLiteral(toInt(advance().lexeme));
    }

    if (check(TokenType.StringLiteral)) {
        return new StringLiteral(advance().lexeme);
    }

    if (check(TokenType.Identifier)) {
        string name = advance().lexeme;

        if (check(TokenType.LBracket)) {
            advance(); // consume '['
            ASTNode indexExpr = parseExpression(); // Parse the index expression
            expect(TokenType.RBracket); // Ensure the closing bracket is present
            return new ArrayAccessExpr(name, indexExpr);
        }

        return new VarExpr(name);
    }

    if (check(TokenType.LParen)) {
        advance(); // skip '('
        ASTNode expr = parseExpression();
        expect(TokenType.RParen);
        return expr;
    }

    throw new Exception("Unexpected token in expression: " ~ current().lexeme ~ " (" ~ current().type.stringof ~ ")");
}


byte parseByteValue(string lexeme) {
    // Handle 0xAB, 'A', or decimal formats
    import std.algorithm.searching : startsWith;

    if (lexeme.startsWith("0x")) 
        return to!byte(lexeme[2..$], 16);
    if (lexeme.startsWith("'") && lexeme.length == 3) 
        return lexeme[1].to!byte;
    return to!byte(lexeme);
}

ASTNode parseStatement() {
    if (check(TokenType.PlusPlus)) {
        advance(); // consume '++'
        string var = expect(TokenType.Identifier).lexeme;
        auto increment = new UnaryExpr("++", new VarExpr(var));
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
    else if (check(TokenType.Identifier) && peek().type == TokenType.PlusPlus) {
        string name = expect(TokenType.Identifier).lexeme;
        expect(TokenType.PlusPlus); // This must match your token type
        expect(TokenType.Semicolon);
        return new PostfixUnaryStmt(name, "++");
    }
    else if (check(TokenType.Switch)) {
        advance(); // consume 'switch'
        expect(TokenType.LParen);
        auto condition = parseExpression();
        expect(TokenType.RParen);
        expect(TokenType.LBrace);

        ASTNode[] allCases;

        while (!check(TokenType.RBrace) && !check(TokenType.Eof)) {
            if (check(TokenType.Case)) {
                advance();
                auto caseExpr = parseExpression(); // this could be IntLiteral, etc.
                expect(TokenType.Colon);

                ASTNode[] caseBody;
                while (!checkAny(TokenType.Case, TokenType.Default, TokenType.RBrace, TokenType.Eof)) {
                    caseBody ~= parseStatement();
                }

                allCases ~= new CaseStmt(0, caseExpr, caseBody);
            }
            else if (check(TokenType.Default)) {
                advance();
                expect(TokenType.Colon);

                ASTNode[] defaultBody;
                while (!checkAny(TokenType.RBrace, TokenType.Eof)) {
                    defaultBody ~= parseStatement();
                }

                allCases ~= new CaseStmt(0, null, defaultBody); // "default" as value
            }
            else {
                throw new Exception("Unexpected token in switch: " ~ current().lexeme);
            }
        }

        expect(TokenType.RBrace);
        return new SwitchStmt(condition, allCases);
    }
    else if (check(TokenType.Default)) {
        advance();
        expect(TokenType.Colon);
        ASTNode[] defaultBody;

        while (!check(TokenType.RBrace)) {
            defaultBody ~= parseStatement();
        }

        return new CaseStmt(0, null, defaultBody); // "default" as value
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
    else if ((check(TokenType.Int) || check(TokenType.Byte)) && peek().type == TokenType.LBracket) {
        advance(); // 'int' or 'byte'
        expect(TokenType.LBracket);
        expect(TokenType.RBracket);
        string name = expect(TokenType.Identifier).lexeme;
        expect(TokenType.Assign);
        expect(TokenType.LBrace);

        ASTNode[] elements;
        while (!check(TokenType.RBrace)) {
            elements ~= parseExpression();
            if (check(TokenType.Comma)) {
                advance();
            } else {
                break;
            }
        }

        expect(TokenType.RBrace);
        expect(TokenType.Semicolon);

        return new ArrayDecl("int", name, elements);
    }
	else if (check(TokenType.Identifier) && (current().lexeme == "print"
    || current().lexeme == "println" || current().lexeme == "printf" || current().lexeme == "writeln")) {
		advance(); // skip 'print', 'println', 'printf', or 'writeln'
		expect(TokenType.LParen);
		ASTNode val = parseExpression();
		expect(TokenType.RParen);
		expect(TokenType.Semicolon);
		return new PrintStmt(val);
	}
    else if (checkAny(TokenType.Int, TokenType.Bool, TokenType.String)) {
		Token typeToken = expectAny(TokenType.Int, TokenType.Bool, TokenType.String);
		string name = expect(TokenType.Identifier).lexeme;
		expect(TokenType.Assign);
		ASTNode val = parseExpression();
		expect(TokenType.Semicolon);
		return new VarDecl(typeToken.lexeme, name, val); // Assuming you added `type` to VarDecl
	}
    else if (check(TokenType.Byte)) {
        advance();
        string name = expect(TokenType.Identifier).lexeme;
        expect(TokenType.Assign);
        ASTNode val = parseExpression();
        expect(TokenType.Semicolon);
        return new VarDecl("byte", name, val); // Assuming you added `type` to VarDecl
    }
    else if (check(TokenType.For)) {
        advance(); // consume 'for'
        expect(TokenType.LParen);

        ASTNode init;
        if (checkAny(TokenType.Int, TokenType.Bool, TokenType.String)) {
            init = parseStatement(); // handles int i = 0;
        } else {
            init = parseExpression();
            expect(TokenType.Semicolon);
        }

        ASTNode condition = parseExpression();
        expect(TokenType.Semicolon);

        ASTNode increment = parseExpression();
        expect(TokenType.RParen);

        ASTNode[] forBody = parseBlock();

        return new CStyleForStmt(init, condition, increment, forBody);
    }
    else if (check(TokenType.Foreach)) {
        advance(); // consume 'foreach'
        expect(TokenType.LParen);
        
        string varName = expect(TokenType.Identifier).lexeme;
        expect(TokenType.Semicolon);
        
        ASTNode iterable = parseExpression();
        expect(TokenType.RParen);
        
        ASTNode[] forEachBody = parseBlock();
        
        return new ForeachStmt(varName, iterable, forEachBody);
    }



    // Fallback for expression statements like 'i++' or any valid expression
    if (check(TokenType.Identifier) || check(TokenType.Number) || check(TokenType.LParen) || check(TokenType.Comma)) {
        ASTNode expr = parseExpression();
        expect(TokenType.Semicolon);
        return new ExprStmt(expr);
    }
	
	if (check(TokenType.True)) {
		advance();
		return new BoolLiteral(true);
	}
	if (check(TokenType.False)) {
		advance();
		return new BoolLiteral(false);
	}
	writeln("Current token at statement level: ", current().type);

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

bool match(TokenType kind) {
    if (check(kind)) {
        advance();
        return true;
    }
    return false;
}