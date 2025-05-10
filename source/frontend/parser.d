module frontend.parser;

import frontend.lexer;
import ast.nodes;
import globals : enumTable, structFieldOffsets;
import main;

import std.stdio;
import std.algorithm.iteration; // Required for filter

private Token[] tokens;
private size_t index;
string[] structTypes;

// ---------------------------
// 🔧 Helper functions
// ---------------------------

string errorWithLine(string msg, int line = __LINE__)
{
    import std.format : format;
    return format("[parser.d:%s] %s", line, msg);
}

Token expect(TokenType kind) {
    Token t = current();
    if (t.type != kind) {
        hasErrors = true;
        throw new Exception(errorWithLine("Expected " ~ kind.stringof ~ ", got " ~ t.type.stringof ~ " at token '" ~ current().lexeme ~ "'"));
    }
    index++;
    return t;
}

bool isTypeToken(TokenType t) {
    return t == TokenType.Int ||
        t == TokenType.Bool ||
        t == TokenType.String ||
        t == TokenType.Void ||
        t == TokenType.Byte ||
        t == TokenType.Short;
}

ASTNode parseExpression(int prec = 0) {
    ASTNode left = parseUnary();

    // Handle assignment if applicable
    if (check(TokenType.Assign)) {
        advance(); // consume '='
        ASTNode right = parseExpression();
        if (cast(VarExpr) left || cast(ArrayAccessExpr) left || cast(StructFieldAccess) left) {
            return new AssignStmt(left, right);
        } else {
            throw new Exception(errorWithLine("Left-hand side of assignment must be a variable, array element, or struct field"));
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

    if (check(TokenType.LParen)) {
        advance();
        ASTNode[] args;
        if (!check(TokenType.RParen)) {
            do {
                args ~= parseExpression();
            } while (match(TokenType.Comma));
        }
        expect(TokenType.RParen);
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
    // --- CAST SUPPORT ---
    if (check(TokenType.Cast)) {
        advance(); // consume 'cast'
        expect(TokenType.LParen);
        string typeName;
        if (checkAny(TokenType.Identifier, TokenType.Int, TokenType.String, TokenType.Bool, TokenType.Byte, TokenType.Short)) {
            typeName = advance().lexeme;
        } else {
            throw new Exception(errorWithLine("Expected type name in cast, got " ~ current().lexeme));
        }
        expect(TokenType.RParen);
        ASTNode expr = parseUnary();
        return new CastExpr(typeName, expr); // Use CastExpr node
    }
    return parsePrimary();
}

ASTNode parsePrimary() {
    ASTNode expr;

    if (check(TokenType.True)) {
        advance();
        expr = new BoolLiteral(true);
    }
    else if (check(TokenType.False)) {
        advance();
        expr = new BoolLiteral(false);
    }
    else if (check(TokenType.Number)) {
        expr = new IntLiteral(toInt(advance().lexeme));
    }
    else if (check(TokenType.StringLiteral)) {
        expr = new StringLiteral(advance().lexeme);
    }
    else if (check(TokenType.Identifier)) {
        string ident = advance().lexeme;
        // Check for EnumName.Member
        if (check(TokenType.Dot)) {
            advance();
            string member = expect(TokenType.Identifier).lexeme;
            if (enumTable !is null && ident in enumTable && member in enumTable[ident]) {
                expr = new IntLiteral(enumTable[ident][member]);
            } else {
                expr = new StructFieldAccess(new VarExpr(ident), member);
            }
        } else if (enumTable !is null) {
            // Optionally support bare enum member names
            foreach (ename, members; enumTable) {
                if (ident in members) {
                    expr = new IntLiteral(members[ident]);
                    break;
                }
            }
            if (expr is null)
                expr = new VarExpr(ident);
        } else {
            expr = new VarExpr(ident);
        }
    }
    else if (check(TokenType.Dollar)) {
        advance();
        expr = new VarExpr("$");
    }
    else if (check(TokenType.LParen)) {
        advance();
        expr = parseExpression();
        expect(TokenType.RParen);
    }
    else if (check(TokenType.LBracket)) {
        advance();
        ASTNode[] elements;
        if (!check(TokenType.RBracket)) {
            do {
                elements ~= parseExpression();
            } while (match(TokenType.Comma));
        }
        expect(TokenType.RBracket);
        expr = new ArrayLiteralExpr(elements);
    }
    else {
        // If we get here, it's an error
        hasErrors = true;
        throw new Exception(errorWithLine("Unexpected token in expression: " ~ current().lexeme ~ " (" ~ current().type.stringof ~ ")"));
    }

    // Handle chained field accesses, array accesses, and calls
    while (true) {
        if (check(TokenType.LBracket)) {
            advance();
            ASTNode indexExpr = parseExpression();
            expect(TokenType.RBracket);
            // For array access, if the base is a VarExpr, use its name
            if (auto var = cast(VarExpr)expr) {
                expr = new ArrayAccessExpr(var.name, indexExpr);
            } else if (auto prevAccess = cast(ArrayAccessExpr)expr) {
                // Handle multi-dimensional arrays more effectively
                // Store the full array name and the current dimension access
                string arrayBaseName = prevAccess.arrayName;
                if (arrayBaseName != "complex_expr") {
                    // Create a new accessor for the next dimension
                    ArrayAccessExpr newAccess = new ArrayAccessExpr(arrayBaseName, indexExpr);
                    // Mark this as a multi-dim access by saving the previous dimension index
                    newAccess.baseExpr = prevAccess;
                    expr = newAccess;
                } else {
                    // We're already using complex_expr for a nested access
                    ArrayAccessExpr newAccess = new ArrayAccessExpr("complex_expr", indexExpr);
                    newAccess.baseExpr = prevAccess;
                    expr = newAccess;
                }
            } else {
                // For other complex bases, use the fallback
                expr = new ArrayAccessExpr("complex_expr", indexExpr);
            }
        } else if (check(TokenType.LParen)) {
            advance();
            ASTNode[] args;
            if (!check(TokenType.RParen)) {
                do {
                    args ~= parseExpression();
                } while (match(TokenType.Comma));
            }
            expect(TokenType.RParen);
            // For calls, if the base is a VarExpr, use its name
            if (auto var = cast(VarExpr)expr) {
                expr = new CallExpr(var.name, args);
            } else {
                // For more complex bases, you may want to extend CallExpr
                expr = new CallExpr("complex_expr", args); // fallback
            }
        } else if (check(TokenType.Dot)) {
            advance();
            string field = expect(TokenType.Identifier).lexeme;
            expr = new StructFieldAccess(expr, field);
        } else {
            break;
        }
    }
    return expr;
}

byte parseByteValue(string lexeme) {
    import std.algorithm.searching : startsWith;
    if (lexeme.startsWith("0x")) 
        return to!byte(lexeme[2..$], 16);
    if (lexeme.startsWith("'") && lexeme.length == 3) 
        return lexeme[1].to!byte;
    return to!byte(lexeme);
}

ASTNode parseStatement() {
    // Handle public/private/const variable declarations at top level and in blocks
    // --- PATCH: allow struct types and arrays after public/private/const ---
    if ((check(TokenType.Public) || check(TokenType.Private) || check(TokenType.Const)) &&
        (isTypeToken(peek().type) || peek().type == TokenType.Auto ||
         (peek().type == TokenType.Identifier && structTypes.canFind(peek().lexeme)))) {
        bool isConst = false;
        string visibility = "public"; // Default visibility
        
        if (check(TokenType.Const)) {
            isConst = true;
            advance();
        } else {
            visibility = advance().type == TokenType.Public ? "public" : "private";
        }
        
        Token typeToken = advance();
        ASTNode[] decls;
        do {
            if (!check(TokenType.Identifier)) {
                writeln("ERROR: Expected variable name, but got ", current().lexeme, " (", current().type, ")");
                throw new Exception(errorWithLine("Expected variable name, got " ~ current().lexeme));
            }
            string varName = expect(TokenType.Identifier).lexeme;
            // --- PATCH: Support multi-dimensional array declaration after public/private ---
            if (check(TokenType.LBracket)) {
                ASTNode[] dimensions;
                while (check(TokenType.LBracket)) {
                    advance();
                    ASTNode sizeExpr = null;
                    if (!check(TokenType.RBracket)) {
                        sizeExpr = parseExpression();
                    }
                    expect(TokenType.RBracket);
                    dimensions ~= sizeExpr;
                }
                // Defensive: Only allow semicolon or comma after array declaration
                if (check(TokenType.Comma)) {
                    writeln("ERROR: Comma after array declaration is not supported. Only one array variable per statement.");
                    throw new Exception(errorWithLine("Comma after array declaration is not supported. Only one array variable per statement."));
                }
                decls ~= new ArrayDecl(typeToken.lexeme, varName, dimensions);
                break; // Only one array decl per statement
            } else {
                ASTNode val;
                if (match(TokenType.Assign)) {
                    val = parseExpression();
                } else {
                    if (isConst) {
                        throw new Exception(errorWithLine("Const variables must be initialized"));
                    }
                    val = null;
                }
                decls ~= new VarDecl(typeToken.lexeme, varName, val, visibility, isConst);
            }
            // Defensive: If next token is not comma or semicolon, error
            if (!(check(TokenType.Comma) || check(TokenType.Semicolon))) {
                writeln("ERROR: Expected ',' or ';' after variable declaration, but got '", current().lexeme, "' (", current().type, ")");
                throw new Exception(errorWithLine("Expected ',' or ';' after variable declaration, but got '" ~ current().lexeme ~ "' (" ~ current().type.stringof ~ ")"));
            }
        } while (match(TokenType.Comma));
        expect(TokenType.Semicolon);
        return decls.length == 1 ? decls[0] : new BlockStmt(decls);
    }
    // --- PATCH: Error if public/private/const is not followed by a valid declaration ---
    if (check(TokenType.Public) || check(TokenType.Private) || check(TokenType.Const)) {
        string modifier = "";
        if (check(TokenType.Public)) modifier = "public";
        else if (check(TokenType.Private)) modifier = "private";
        else if (check(TokenType.Const)) modifier = "const";
        
        advance();
        writeln("ERROR: '" ~ modifier ~ "' must be followed by a type, struct, or 'auto', but got '", current().lexeme, "' (", current().type, ")");
        throw new Exception(errorWithLine("'" ~ modifier ~ "' must be followed by a type, struct, or 'auto', but got '" ~ current().lexeme ~ "' (" ~ current().type.stringof ~ ")"));
    }
    // Prefix increment/decrement (e.g., ++x;)
    if (check(TokenType.PlusPlus) || check(TokenType.MinusMinus)) {
        Token op = advance();
        string var = expect(TokenType.Identifier).lexeme;
        expect(TokenType.Semicolon);
        return new ExprStmt(new UnaryExpr(op.lexeme, new VarExpr(var)));
    }
    // Assignment (e.g., x = 5;)
    else if (check(TokenType.Identifier) && peek().type == TokenType.Assign) {
        string name = expect(TokenType.Identifier).lexeme;
        expect(TokenType.Assign);
        ASTNode value = parseExpression();
        expect(TokenType.Semicolon);
        return new AssignStmt(new VarExpr(name), value);
    }
    // Postfix increment/decrement (e.g., x++;)
    else if (check(TokenType.Identifier) && (peek().type == TokenType.PlusPlus || peek().type == TokenType.MinusMinus)) {
        string name = expect(TokenType.Identifier).lexeme;
        Token op = advance();
        expect(TokenType.Semicolon);
        return new PostfixUnaryStmt(name, op.lexeme);
    }
    // Return statement
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
                elseBody ~= parseStatement();
            } else {
                elseBody = parseBlock();
            }
        }
        return new IfStmt(cond, thenBody, elseBody);
    }
    else if (check(TokenType.Void) && peek().type == TokenType.Function) {
        string type = expect(TokenType.Void).lexeme ~ " " ~ expect(TokenType.Function).lexeme;
        expect(TokenType.LParen);
        string innerType;
        // Accept built-in types or struct types as function pointer parameter types
        if (checkAny(TokenType.Int, TokenType.String, TokenType.Bool, TokenType.Void, TokenType.Byte, TokenType.Short)) {
            innerType = advance().lexeme;
        } else if (isStructType()) {
            innerType = advance().lexeme;
        } else {
            hasErrors = true;
            throw new Exception(errorWithLine("Expected type in function pointer declaration, got " ~ current().lexeme));
        }
        expect(TokenType.RParen);
        type ~= "(" ~ innerType ~ ")";
        string name = expect(TokenType.Identifier).lexeme;
        // Support array of function pointers: void function(Pixel) fpArr[2];
        if (check(TokenType.LBracket)) {
            advance();
            ASTNode sizeExpr = null;
            if (!check(TokenType.RBracket)) {
                sizeExpr = parseExpression();
            }
            expect(TokenType.RBracket);
            expect(TokenType.Semicolon);
            ASTNode[] elements = sizeExpr is null ? [] : [sizeExpr];
            return new ArrayDecl(type, name, elements);
        } else {
            expect(TokenType.Semicolon);
            return new VarDecl(type, name, null);
        }
    }
    else if (check(TokenType.Identifier) && peek().type == TokenType.PlusPlus) {
        string name = expect(TokenType.Identifier).lexeme;
        expect(TokenType.PlusPlus);
        expect(TokenType.Semicolon);
        return new PostfixUnaryStmt(name, "++");
    }
    else if (check(TokenType.Switch)) {
        advance();
        expect(TokenType.LParen);
        auto condition = parseExpression();
        expect(TokenType.RParen);
        expect(TokenType.LBrace);

        ASTNode[] allCases;
        while (!check(TokenType.RBrace) && !check(TokenType.Eof)) {
            if (check(TokenType.Case)) {
                advance();
                auto caseExpr = parseExpression();
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
                allCases ~= new CaseStmt(0, null, defaultBody);
            }
            else {
                hasErrors = true;
                throw new Exception(errorWithLine("Unexpected token in switch: " ~ current().lexeme));
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
        return new CaseStmt(0, null, defaultBody);
    }
    else if (check(TokenType.LBrace)) {
        ASTNode[] blockBody = parseBlock();
        return new BlockStmt(blockBody);
    }
    else if (check(TokenType.While)) {
        advance();
        expect(TokenType.LParen);
        ASTNode cond = parseExpression();
        expect(TokenType.RParen);
        ASTNode[] whileBody = parseBlock();
        return new WhileStmt(cond, whileBody);
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
        return new CommentBlockStmt(comment);
    }
    // Array declaration: type identifier [ size ] [ size ] ... ;
    if ((isTypeToken(current().type) || isStructType() || current().type == TokenType.Auto)
        && peek().type == TokenType.Identifier && tokens.length > index+2 && tokens[index+2].type == TokenType.LBracket) {
        string type = advance().lexeme;
        string name = expect(TokenType.Identifier).lexeme;
        ASTNode[] dimensions;
        while (check(TokenType.LBracket)) {
            advance();
            ASTNode sizeExpr = null;
            if (!check(TokenType.RBracket)) {
                sizeExpr = parseExpression();
            }
            expect(TokenType.RBracket);
            dimensions ~= sizeExpr;
        }
        expect(TokenType.Semicolon);
        return new ArrayDecl(type, name, dimensions);
    }
    // Handle variable declarations starting with const
    else if (check(TokenType.Const) && 
             (isTypeToken(peek().type) || peek().type == TokenType.Auto ||
              (peek().type == TokenType.Identifier && structTypes.canFind(peek().lexeme)))) {
        advance(); // Consume 'const'
        Token typeToken = advance();
        ASTNode[] decls;
        do {
            if (!check(TokenType.Identifier)) {
                writeln("ERROR: Expected variable name after const " ~ typeToken.lexeme ~ ", but got ", current().lexeme, " (", current().type, ")");
                throw new Exception(errorWithLine("Expected variable name, got " ~ current().lexeme));
            }
            string varName = expect(TokenType.Identifier).lexeme;
            ASTNode val;
            if (match(TokenType.Assign)) {
                val = parseExpression();
            } else {
                throw new Exception(errorWithLine("Const variables must be initialized"));
            }
            decls ~= new VarDecl(typeToken.lexeme, varName, val, "public", true); // Constants are public by default
        } while (match(TokenType.Comma));
        expect(TokenType.Semicolon);
        return decls.length == 1 ? decls[0] : new BlockStmt(decls);
    }
    // General variable declaration
    else if (isTypeToken(current().type) || isStructType() || current().type == TokenType.Auto) {
        Token typeToken = advance();
        ASTNode[] decls;
        do {
            if (!check(TokenType.Identifier)) {
                writeln("ERROR: Expected variable name, but got ", current().lexeme, " (", current().type, ")");
                writeln("Did you forget a semicolon after a previous declaration?");
                throw new Exception(errorWithLine("Expected variable name, got " ~ current().lexeme));
            }
            string varName = expect(TokenType.Identifier).lexeme;
            ASTNode val;
            if (match(TokenType.Assign)) {
                val = parseExpression();
            } else {
                val = null;
            }
            decls ~= new VarDecl(typeToken.lexeme, varName, val);
        } while (match(TokenType.Comma));
        expect(TokenType.Semicolon);
        return decls.length == 1 ? decls[0] : new BlockStmt(decls);
    }
    else if (check(TokenType.Byte)) {
        advance();
        string name = expect(TokenType.Identifier).lexeme;
        expect(TokenType.Assign);
        ASTNode val = parseExpression();
        expect(TokenType.Semicolon);
        return new VarDecl("byte", name, val);
    }
    else if (check(TokenType.Break)) {
        advance();
        expect(TokenType.Semicolon);
        return new BreakStmt();
    }
    else if (check(TokenType.Continue)) {
        advance();
        expect(TokenType.Semicolon);
        return new ContinueStmt();
    }
    else if (check(TokenType.For)) {
        advance();
        expect(TokenType.LParen);

        ASTNode init;
        if (checkAny(TokenType.Int, TokenType.Bool, TokenType.String)) {
            init = parseStatement();
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
        advance();
        expect(TokenType.LParen);
        string varName = expect(TokenType.Identifier).lexeme;
        expect(TokenType.Semicolon);
        ASTNode iterable = parseExpression();
        expect(TokenType.RParen);
        ASTNode[] forEachBody = parseBlock();
        return new ForeachStmt(varName, iterable, forEachBody);
    }
    else if (check(TokenType.Function)) {
        advance();
        string returnType = expectAny(TokenType.Int, TokenType.String, TokenType.Bool).lexeme;
        string name = expect(TokenType.Identifier).lexeme;
        expect(TokenType.LParen);
        ParamInfo[] params;
        VarParam[] varParams; // <-- Use VarParam[]
        if (!check(TokenType.RParen)) {
            do {
                string paramType;
                if (check(TokenType.Void) && peek().type == TokenType.Function) {
                    paramType = expect(TokenType.Void).lexeme ~ " " ~ expect(TokenType.Function).lexeme;
                    expect(TokenType.LParen);
                    string innerType;
                    if (checkAny(TokenType.Int, TokenType.String, TokenType.Bool)) {
                        innerType = advance().lexeme;
                    } else if ((check(TokenType.Identifier) && (isStructType() || isEnumType()))) {
                        innerType = advance().lexeme;
                    } else {
                        throw new Exception(errorWithLine("Expected type in parameter list, got " ~ current().lexeme));
                    }
                    // Support array type for function pointer parameter (Pixel[])
                    if (check(TokenType.LBracket)) {
                        advance();
                        expect(TokenType.RBracket);
                        innerType ~= "[]";
                    }
                    expect(TokenType.RParen);
                    paramType ~= "(" ~ innerType ~ ")";
                } else if (checkAny(TokenType.Int, TokenType.String, TokenType.Bool) || isStructType() || isEnumType()) {
                    paramType = advance().lexeme;
                    // Support array type for parameter (Pixel[] pixels or Pixel pixels[])
                    bool arrayType = false;
                    if (check(TokenType.LBracket)) {
                        advance();
                        expect(TokenType.RBracket);
                        paramType ~= "[]";
                        arrayType = true;
                    }
                    string paramName = expect(TokenType.Identifier).lexeme;
                    // Support Pixel pixels[]
                    if (!arrayType && check(TokenType.LBracket)) {
                        advance();
                        expect(TokenType.RBracket);
                        paramType ~= "[]";
                    }
                    params ~= ParamInfo(paramType, paramName);
                    continue;
                } else if (check(TokenType.Identifier)) {
                    string varName = advance().lexeme;
                    varParams ~= new VarParam(varName);
                    continue;
                } else {
                    throw new Exception(errorWithLine("Expected type in parameter list, got " ~ current().lexeme));
                }
                string paramName = expect(TokenType.Identifier).lexeme;
                params ~= ParamInfo(paramType, paramName);
            } while (match(TokenType.Comma));
        }
        expect(TokenType.RParen);
        ASTNode[] funcBody = parseBlock();
        return new FunctionDecl(name, returnType, params, funcBody, varParams);
    }
    // Fallback for expression statements
    // Handles assignments to fields, arrays, and any complex lvalue
    if (check(TokenType.Identifier) || check(TokenType.Number) || check(TokenType.LParen) || check(TokenType.Comma) || check(TokenType.LBracket)) {
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
    throw new Exception(errorWithLine("Unknown statement at token: " ~ tokens[index].lexeme));
}

ASTNode[] parseBlock() {
    ASTNode[] parseBody;
    expect(TokenType.LBrace);
    while (!check(TokenType.RBrace) && !check(TokenType.Eof)) {
        // Allow public/private at block scope (for top-level and struct blocks)
        if (check(TokenType.Public) || check(TokenType.Private)) {
            parseBody ~= parseStatement();
        } else {
            parseBody ~= parseStatement();
        }
    }
    expect(TokenType.RBrace);
    return parseBody;
}

Token advance() {
    return tokens[index++];
}

Token current() {
    return tokens[index];
}

bool check(TokenType kind) {
    return tokens[index].type == kind;
}

bool checkAny(TokenType[] types...) {
    auto t = tokens[index].type;
    foreach (tt; types) {
        if (t == tt) return true;
    }
    return false;
}

int getPrecedence() {
    if (check(TokenType.OrOr)) return 1;
    if (check(TokenType.AndAnd)) return 2;
    if (check(TokenType.EqualEqual) || check(TokenType.NotEqual)) return 3;
    if (check(TokenType.Less) || check(TokenType.LessEqual) || check(TokenType.Greater) || check(TokenType.GreaterEqual)) return 4;
    if (check(TokenType.Plus) || check(TokenType.Minus)) return 5;
    if (check(TokenType.Star) || check(TokenType.Slash)) return 6;
    if (check(TokenType.Mod)) return 7;
    if (check(TokenType.TildeEqual)) return 8;
    if (check(TokenType.Assign)) return 0;
    return -1;
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

    // --- PATCH: Parse all struct/enum declarations first so structTypes is filled, skipping comments ---
    while (!isAtEnd()) {
        // Skip comments and blank lines
        if (check(TokenType.Comment) || check(TokenType.CommentBlockStart)) {
            advance();
            continue;
        }
        if (check(TokenType.Struct)) {
            nodes ~= parseStructDecl();
            continue;
        }
        if (check(TokenType.Enum)) {
            nodes ~= parseEnumDecl();
            continue;
        }
        // Only break if it's not a struct/enum/comment
        break;
    }

    // Now parse the rest of the file
    while (!isAtEnd()) {
        if (check(TokenType.Import)) {
            advance();
            while (!check(TokenType.Semicolon) && !isAtEnd()) {
                advance();
            }
            expect(TokenType.Semicolon);
            continue;
        }
        // Structs and enums already handled above
        if (check(TokenType.Struct)) {
            nodes ~= parseStructDecl();
            continue;
        }
        if (check(TokenType.Enum)) {
            nodes ~= parseEnumDecl();
            continue;
        }
        // Function declaration: type identifier '(' or structType identifier '(' or public/private
        if ((checkAny(TokenType.Int, TokenType.String, TokenType.Bool, TokenType.Void, TokenType.Byte, TokenType.Short) || isStructType() || check(TokenType.Public) || check(TokenType.Private))
            && peek().type == TokenType.Identifier && tokens.length > index+2 && tokens[index+2].type == TokenType.LParen) {
            nodes ~= parseFunctionDecl();
            continue;
        }
        // Top-level variable declaration: allow public/private
        if (checkAny(TokenType.Int, TokenType.String, TokenType.Bool, TokenType.Void, TokenType.Byte, TokenType.Short) || isStructType() || check(TokenType.Public) || check(TokenType.Private) || check(TokenType.Auto)) {
            nodes ~= parseStatement();
            continue;
        }
        // --- PATCH: Accept top-level assignments and field/array assignments ---
        if (check(TokenType.Identifier) || check(TokenType.LParen) || check(TokenType.LBracket) || check(TokenType.Number) || check(TokenType.Dollar)) {
            // Accept assignment, field assignment, array assignment, or expression statement at top level
            auto stmt = parseStatement();
            // Only add if it's an assignment or ExprStmt (for field/array assignment)
            import ast.nodes : AssignStmt, ExprStmt;
            if (cast(AssignStmt)stmt !is null || cast(ExprStmt)stmt !is null) {
                nodes ~= stmt;
            } else {
                // Ignore other expression statements at top level
            }
            continue;
        }
        writeln("Unknown top-level token: ", current().lexeme, " (", current().type, ")");
        advance();
    }
    return nodes;
}

ASTNode parseStructDecl() {
    if (check(TokenType.Struct)) {
        advance();
        string name = expect(TokenType.Identifier).lexeme;
        expect(TokenType.LBrace);
        ASTNode[] members;
        while (!check(TokenType.RBrace) && !isAtEnd()) {
            if (checkAny(TokenType.Int, TokenType.Bool, TokenType.String) || isStructType() || isEnumType()) {
                members ~= parseStatement();
            } else {
                throw new Exception(errorWithLine("Only variable declarations are allowed in structs. Got: " ~ current().lexeme));
            }
        }
        expect(TokenType.RBrace);
        expect(TokenType.Semicolon);
        import std.array : array;
        import std.stdio : writeln;
        
        // Only include VarDecls to avoid null dereference, and flatten BlockStmt
        string[] fieldNames = members
            .map!(m => cast(BlockStmt) m ? (cast(BlockStmt) m).blockBody : [m])
            .joiner
            .filter!(m => cast(VarDecl) m !is null)
            .map!(m => (cast(VarDecl) m).name)
            .array;
        // If any member is not VarDecl or BlockStmt, print a warning
        foreach (m; members) {
            if (cast(VarDecl) m is null && cast(BlockStmt) m is null) {
                // Ignore unexpected struct members
            }
        }

        int offset = 0;
        int[string] fieldOffsets;
        foreach (fname; fieldNames) {
            fieldOffsets[fname] = offset;
            offset += 4;
        }
        structFieldOffsets[name] = fieldOffsets;
        structTypes ~= name;

        return new StructDecl(name, fieldNames);
    }
    assert(0, "parseStructDecl called when current token is not a struct declaration");
    return null;
}

ASTNode parseEnumDecl() {
    expect(TokenType.Enum);
    string enumName = expect(TokenType.Identifier).lexeme;
    expect(TokenType.LBrace);
    string[] members;
    int[] values;
    int currentValue = 0;
    while (!check(TokenType.RBrace) && !isAtEnd()) {
        string member = expect(TokenType.Identifier).lexeme;
        int value = currentValue;
        if (match(TokenType.Assign)) {
            if (check(TokenType.Number)) {
                value = toInt(expect(TokenType.Number).lexeme);
                currentValue = value;
            } else {
                throw new Exception(errorWithLine("Expected number after '=' in enum member"));
            }
        }
        members ~= member;
        values ~= value;
        currentValue = value + 1;
        if (!check(TokenType.RBrace)) expect(TokenType.Comma);
    }
    expect(TokenType.RBrace);
    expect(TokenType.Semicolon);

    foreach (i, m; members) {
        enumTable[enumName][m] = values[i];
    }
    return new EnumDecl(enumName, members); // Only pass name and members
}

bool isAtEnd() {
    return index >= tokens.length || tokens[index].type == TokenType.Eof;
}

ASTNode parseFunctionDecl() {
    // --- PATCH: Support optional public/private before return type ---
    string visibility = "";
    if (check(TokenType.Public) || check(TokenType.Private)) {
        visibility = advance().type == TokenType.Public ? "public" : "private";
    }
    if (checkAny(TokenType.Int, TokenType.String, TokenType.Bool, TokenType.Void)) {
        string returnType = advance().lexeme;
        string name = expect(TokenType.Identifier).lexeme;
        expect(TokenType.LParen);
        ParamInfo[] params = [];
        VarParam[] varParams; // <-- Use VarParam[]
        if (!check(TokenType.RParen)) {
            do {
                string paramType;
                if (check(TokenType.Void) && peek().type == TokenType.Function) {
                    paramType = expect(TokenType.Void).lexeme ~ " " ~ expect(TokenType.Function).lexeme;
                    expect(TokenType.LParen);
                    string innerType;
                    if (checkAny(TokenType.Int, TokenType.String, TokenType.Bool)) {
                        innerType = advance().lexeme;
                    } else if ((check(TokenType.Identifier) && (isStructType() || isEnumType()))) {
                        innerType = advance().lexeme;
                    } else {
                        throw new Exception(errorWithLine("Expected type in parameter list, got " ~ current().lexeme));
                    }
                    // Support array type for function pointer parameter (Pixel[])
                    if (check(TokenType.LBracket)) {
                        advance();
                        expect(TokenType.RBracket);
                        innerType ~= "[]";
                    }
                    expect(TokenType.RParen);
                    paramType ~= "(" ~ innerType ~ ")";
                } else if (checkAny(TokenType.Int, TokenType.String, TokenType.Bool) || isStructType() || isEnumType()) {
                    paramType = advance().lexeme;
                    // Support array type for parameter (Pixel[] pixels or Pixel pixels[])
                    bool arrayType = false;
                    if (check(TokenType.LBracket)) {
                        advance();
                        expect(TokenType.RBracket);
                        paramType ~= "[]";
                        arrayType = true;
                    }
                    string paramName = expect(TokenType.Identifier).lexeme;
                    // Support Pixel pixels[]
                    if (!arrayType && check(TokenType.LBracket)) {
                        advance();
                        expect(TokenType.RBracket);
                        paramType ~= "[]";
                    }
                    params ~= ParamInfo(paramType, paramName);
                    continue;
                } else if (check(TokenType.Identifier)) {
                    string varName = advance().lexeme;
                    varParams ~= new VarParam(varName);
                    continue;
                } else {
                    throw new Exception(errorWithLine("Expected type in parameter list, got " ~ current().lexeme));
                }
                string paramName = expect(TokenType.Identifier).lexeme;
                params ~= ParamInfo(paramType, paramName);
            } while (match(TokenType.Comma));
        }
        expect(TokenType.RParen);
        ASTNode[] funcBody = parseBlock();
        return new FunctionDecl(name, returnType, params, funcBody);
    }
    assert(0, "parseFunctionDecl called when current token is not a function declaration");
    return null;
}

import std.algorithm.searching : canFind;
bool isStructType() {
    static string[] builtinTypes = ["int", "string", "bool", "void", "byte", "short"];
    return check(TokenType.Identifier)
        && !builtinTypes.canFind(current().lexeme)
        && structTypes.canFind(current().lexeme);
}

bool isEnumType() {
    return check(TokenType.Identifier) && (current().lexeme in enumTable);
}

void parseArguments() {
    expect(TokenType.LParen);
    while (!check(TokenType.RParen)) {
        parseExpression();
        if (check(TokenType.Comma)) advance();
    }
    expect(TokenType.RParen);
}

int toInt(string s) {
    import std.conv : to;
    return to!int(s);
}

Token expectAny(TokenType[] types...) {
    Token t = current();
    if (!checkAny(types)) {
        hasErrors = true;
        throw new Exception(errorWithLine("Expected one of " ~ types.stringof ~ ", got " ~ t.type.stringof ~ " at '" ~ current().lexeme ~ "'"));
    }
    index++;
    return t;
}