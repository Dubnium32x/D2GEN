module frontend.parser;

import frontend.lexer;
import ast.nodes;
import main;

import std.stdio;
import std.algorithm.iteration; // Required for filter

private Token[] tokens;
private size_t index;

// ---------------------------
// 🔧 XP-safe helper functions
// ---------------------------

// Consume and return if matches
Token expect(TokenType kind) {
    Token t = current();
    if (t.type != kind) {
        hasErrors = true;
        writeln("DEBUG: At token ", current().lexeme, " (", current().type, ")");

        throw new Exception("Expected " ~ kind.stringof ~ ", got " ~ t.type.stringof ~ " at token '" ~ current().lexeme ~ "'");
    }
    index++;
    return t;
}

Token expectAny(TokenType a, TokenType b, TokenType c = TokenType.Eof, TokenType d = TokenType.Eof) {
    Token t = current();
    if (!checkAny(a, b, c, d)) {
        hasErrors = true;
        writeln("DEBUG: At token ", current().lexeme, " (", current().type, ")");

        throw new Exception("Expected one of [" ~ a.stringof ~ ", " ~ b.stringof ~ ", " ~ c.stringof ~ ", " ~ d.stringof ~ "], got " ~ t.type.stringof ~ " at '" ~ current().lexeme ~ "'");
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

bool isTypeToken(TokenType t) {
    return t == TokenType.Int ||
        t == TokenType.Bool ||
        t == TokenType.String ||
        t == TokenType.Void ||
        t == TokenType.Byte;
}

ASTNode parseExpression(int prec = 0) {
    ASTNode left = parseUnary();

    // Handle assignment if applicable
    if (check(TokenType.Assign)) {
        advance(); // consume '='
        ASTNode right = parseExpression();
        if (cast(VarExpr) left || cast(ArrayAccessExpr) left) {
            // ok
        } else {
            writeln("DEBUG: At token ", current().lexeme, " (", current().type, ")");

            throw new Exception("Left-hand side of assignment must be a variable or array element");
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
    if (check(TokenType.TildeEqual) && peek().type == TokenType.Assign) {
        Token op = advance();
        ASTNode right = parseExpression();
        left = new BinaryExpr(op.lexeme, left, right);
    }

    return left;
}

ASTNode parseUnary() {
    if (check(TokenType.Bang)) {
        Token op = advance(); // consume '!'
        ASTNode right = parseUnary();
        return new UnaryExpr(op.lexeme, right);
    }
    if (check(TokenType.Ampersand)) {
        Token op = advance(); // consume '&'
        ASTNode right = parseUnary();
        return new UnaryExpr("&", right);
    }
    if (check(TokenType.PlusPlus) || check(TokenType.MinusMinus)) {
        Token op = advance();
        ASTNode expr = parseUnary();
        return new UnaryExpr(op.lexeme, expr);
    }
    return parsePrimary();
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
        if (check(TokenType.LParen)) {
            advance(); // consume '('
            ASTNode[] args;

            if (!check(TokenType.RParen)) {
                do {
                    args ~= parseExpression();  // 👈 this handles each arg
                } while (match(TokenType.Comma));
            }

            expect(TokenType.RParen);
            return new CallExpr(name, args);
        }

        return new VarExpr(name);
    }

    if (check(TokenType.Dollar)) {
        advance();
        return new VarExpr("$"); // treat `$` as a special variable
    }


    if (check(TokenType.LParen)) {
        advance(); // consume '('
        ASTNode expr = parseExpression();
        expect(TokenType.RParen);
        return expr;
    }

    if (check(TokenType.LBracket)) {
        advance(); // consume '['
        ASTNode[] elements;
        if (!check(TokenType.RBracket)) {
            do {
                elements ~= parseExpression();
            } while (match(TokenType.Comma));
        }
        expect(TokenType.RBracket);
        return new ArrayLiteralExpr(elements);
    }

    if (check(TokenType.TildeEqual)) {
        Token op = advance(); // consume '~='
        ASTNode right = parseExpression();
        ASTNode left = parsePrimary();
        return new BinaryExpr(op.lexeme, left, right);
    }

    hasErrors = true;
    writeln("DEBUG: At token ", current().lexeme, " (", current().type, ")");

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
        return new AssignStmt(new VarExpr(name), value);
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
                hasErrors = true;
                writeln("DEBUG: At token ", current().lexeme, " (", current().type, ")");

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
    else if (check(TokenType.Comment)) {
        string text  = advance().lexeme;
        return new CommentStmt(text);
    }
    else if (check(TokenType.CommentBlockStart)) {
        string comment = advance().lexeme;
        expect(TokenType.CommentBlockEnd);
        // Handle the content between /* and */
        return new CommentBlockStmt(comment);
    }
    else if (check(TokenType.Struct)) {
        advance(); // consume 'struct'
        string name = expect(TokenType.Identifier).lexeme;
        expect(TokenType.LBrace);

        ASTNode[] members;
        while (!check(TokenType.RBrace)) {
            members ~= parseStatement();
            if (check(TokenType.Comma)) {
                advance();
            } else {
                break;
            }
        }

        expect(TokenType.RBrace);
        expect(TokenType.Semicolon);

    
        import std.array : array; // Ensure std.array is imported
        string[] fieldNames = members.map!(m => cast(VarDecl) m).filter!(v => v !is null).map!(v => v.name).array;
        return new StructDecl(name, fieldNames);
    }
    else if ((check(TokenType.Int) || check(TokenType.Byte) || check(TokenType.String)) && peek().type == TokenType.LBracket) {
        string type = advance().lexeme; // 'int', 'byte', or 'string'
        expect(TokenType.LBracket);
        expect(TokenType.RBracket);
        string name = expect(TokenType.Identifier).lexeme;

        ASTNode[] elements;

        // Optional initializer
        if (match(TokenType.Assign)) {
            // Accept either [ or { for array literal
            TokenType opening = current().type;
            if (opening != TokenType.LBracket && opening != TokenType.LBrace) {
                writeln("DEBUG: At token ", current().lexeme, " (", current().type, ")");

                throw new Exception("Expected '[' or '{' for array elements, got: " ~ current().lexeme);
            }

            advance(); // consume the opening token

            // Only parse elements if not closing immediately
            if (!check(TokenType.RBracket) && !check(TokenType.RBrace)) {
                while (true) {
                    elements ~= parseExpression();

                    if (check(TokenType.Comma)) {
                        advance(); // consume ','
                    } else {
                        break;
                    }
                }
            }

            // Match the correct closing token
            if (opening == TokenType.LBracket)
                expect(TokenType.RBracket);
            else
                expect(TokenType.RBrace);
        }

        expect(TokenType.Semicolon);

        return new ArrayDecl(type, name, elements); // elements may be null
    }
    else if (check(TokenType.Identifier) &&
            (peek().type == TokenType.Assign ||
            peek().type == TokenType.PlusEqual ||
            peek().type == TokenType.MinusEqual ||
            peek().type == TokenType.StarEqual ||
            peek().type == TokenType.SlashEqual ||
            peek().type == TokenType.ModEqual ||
            peek().type == TokenType.TildeEqual)) {

        string name = expect(TokenType.Identifier).lexeme;
        TokenType opType = advance().type; // consume the operator

        ASTNode value = parseExpression();
        expect(TokenType.Semicolon);

        string op;
        switch (opType) {
            case TokenType.Assign:     op = "="; break;
            case TokenType.PlusEqual:  op = "+="; break;
            case TokenType.MinusEqual: op = "-="; break;
            case TokenType.StarEqual:  op = "*="; break;
            case TokenType.SlashEqual: op = "/="; break;
            case TokenType.TildeEqual: op = "~="; break;
            case TokenType.ModEqual:   op = "%="; break;
            default: writeln("DEBUG: At token ", current().lexeme, " (", current().type, ")");
            throw new Exception("Unknown operator: " ~ opType.stringof);
        }   
        return new BinaryExpr(op, new VarExpr(name), value);
    }
    else if (check(TokenType.Identifier) && 
        (current().lexeme == "print" ||
        current().lexeme == "println" ||
        current().lexeme == "printf" ||
        current().lexeme == "writeln")) {

        string printType = advance().lexeme;
        expect(TokenType.LParen);

        ASTNode[] args;
        if (!check(TokenType.RParen)) {
            do {
                args ~= parseExpression();
            } while (match(TokenType.Comma)); // ✅ Allow multiple expressions
        }

        expect(TokenType.RParen);
        expect(TokenType.Semicolon);
        return new PrintStmt(printType, args); // ✅ List of args, not a single node
    }
    else if (checkAny(TokenType.Int, TokenType.Bool, TokenType.String)) {
        Token typeToken = expectAny(TokenType.Int, TokenType.Bool, TokenType.String);
        ASTNode[] decls;
        do {
            string name = expect(TokenType.Identifier).lexeme;
            ASTNode val;
            if (match(TokenType.Assign)) {
                val = parseExpression();
            }else {
                val = null;
            }
            decls ~= new VarDecl(typeToken.lexeme, name, val);
        } while (match(TokenType.Comma));
        expect(TokenType.Semicolon);
        // If only one, return it directly, else return a block of declarations
        return decls.length == 1 ? decls[0] : new BlockStmt(decls);
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
    else if (check(TokenType.Function)) {
        advance(); // consume 'function'
        string returnType = expectAny(TokenType.Int, TokenType.String, TokenType.Bool).lexeme;
        string name = expect(TokenType.Identifier).lexeme;

        expect(TokenType.LParen);
        string[] params;
        if (!check(TokenType.RParen)) {
            do {
                string paramType = expectAny(TokenType.Int, TokenType.String, TokenType.Bool).lexeme;
                string paramName = expect(TokenType.Identifier).lexeme;
                params ~= paramName;
            } while (match(TokenType.Comma));
        }
        expect(TokenType.RParen);

        ASTNode[] funcBody = parseBlock();
        return new FunctionDecl(name, returnType, params, funcBody);
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
	writeln("DEBUG: At token ", current().lexeme, " (", current().type, ")");
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
    if (check(TokenType.Mod)) return 7;
    if (check(TokenType.TildeEqual)) return 8; // Bitwise operators
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

ASTNode[] parse(Token[] inputTokens) {
    ASTNode[] nodes;
    index = 0;
    tokens = inputTokens;
    while (!isAtEnd()) {
        if (check(TokenType.Import)) {
            // Skip import statements
            advance(); // consume 'import'
            while (!check(TokenType.Semicolon) && !isAtEnd()) advance();
            if (check(TokenType.Semicolon)) advance();
            continue;
        }
        nodes ~= parseFunctionDecl();
    }
    return nodes;
}

bool isAtEnd() {
    return index >= tokens.length || tokens[index].type == TokenType.Eof;
}

ASTNode parseFunctionDecl() {
    // Accept: int add(int a, int b) { ... }
    if (checkAny(TokenType.Int, TokenType.String, TokenType.Bool, TokenType.Void)) {
        string returnType = advance().lexeme;
        string name = expect(TokenType.Identifier).lexeme;

        expect(TokenType.LParen);
        string[] params;
        if (!check(TokenType.RParen)) {
            do {
                string paramType = expectAny(TokenType.Int, TokenType.String, TokenType.Bool).lexeme;
                bool isArray = false;
                if (match(TokenType.LBracket)) {
                    expect(TokenType.RBracket);
                    paramType ~= "[]";
                }
                string paramName = expect(TokenType.Identifier).lexeme;
                params ~= paramName; // (or store type/name pair if you track types)
            } while (match(TokenType.Comma));
        }
        expect(TokenType.RParen);

        ASTNode[] funcBody = parseBlock();
        return new FunctionDecl(name, returnType, params, funcBody);
    }
    assert(0, "parseFunctionDecl called when current token is not a function declaration");
    return null;
}