module frontend.lexer;

import std.string;

enum TokenType {
    Int,
    Identifier,
    Return,
    Number,

    Equal,
	PlusPlus, MinusMinus,
	// For the sake of simplicity, we can use the same token for both
	// `+` and `+=`, `-` and `-=`, etc.
    Plus, Minus, Star, Slash,

	Dot,
	DotDot,

	If, Else, While,
	Greater, Less, EqualEqual, // for `==`
	Assign,   
	Bool,
	String,
	NotEqual,
	LessEqual,
	GreaterEqual,
	Bang, // for !
	
	For, Foreach,
	Break, Continue, Default,

	Switch, Case,
	To, Step,

	Var,
	Struct,
	Function,

	StringLiteral,
	
	True,
	False,
	AndAnd,
	OrOr,

	Byte,

	LBracket, RBracket,
    LBrace, RBrace,
    LParen, RParen,
    Semicolon,
	Colon,
	Comma,
    Eof
}


struct Token {
    TokenType type;
    string lexeme;
}

Token[] tokenize(string input) {
    Token[] tokens;
    size_t pos = 0;

    while (pos < input.length) {
        char c = input[pos];

        // Skip whitespace
        if (c == ' ' || c == '\n' || c == '\r' || c == '\t') {
            pos++;
            continue;
        }

        // Double-character operators (check before single '=')
        if (c == '=' && peekNext(input, pos) == '=') {
            tokens ~= Token(TokenType.EqualEqual, "==");
            pos += 2;
            continue;
        }
		else if (c == '=') {
			tokens ~= Token(TokenType.Assign, "=");
			pos++;
			continue;
		}

		if (c == '+' && peekNext(input, pos) == '+') {
			tokens ~= Token(TokenType.PlusPlus, "++");
			pos += 2;
			continue;
		}
		else if (c == '+') {
			tokens ~= Token(TokenType.Plus, "+");
			pos++;
			continue;
		}

		if (c == '-' && peekNext(input, pos) == '-') {
			tokens ~= Token(TokenType.MinusMinus, "--");
			pos += 2;
			continue;
		}
		else if (c == '-') {
			tokens ~= Token(TokenType.Minus, "-");
			pos++;
			continue;
		}

		// !=
		else if  (c == '!' && peekNext(input, pos) == '=') {
			tokens ~= Token(TokenType.NotEqual, "!=");
			pos += 2;
			continue;
		}
		else if (c == '!') {
			tokens ~= Token(TokenType.Bang, "!");
			pos++;
			continue;
		}
		
		if (c == '<' && peekNext(input, pos) == '=') {
			tokens ~= Token(TokenType.LessEqual, "<=");
			pos += 2;
			continue;
		}
		else if (c == '<') {
			tokens ~= Token(TokenType.Less, "<");
			pos++;
			continue;
		}

		if (c == '>' && peekNext(input, pos) == '=') {
			tokens ~= Token(TokenType.GreaterEqual, ">=");
			pos += 2;
			continue;
		}
		else if (c == '>') {
			tokens ~= Token(TokenType.Greater, ">");
			pos++;
			continue;
		}

		// and/or
		if (c == '&' && peekNext(input, pos) == '&') {
			tokens ~= Token(TokenType.AndAnd, "&&");
			pos += 2;
			continue;
		}

		else if (c == '|' && peekNext(input, pos) == '|') {
			tokens ~= Token(TokenType.OrOr, "||");
			pos += 2;
			continue;
		}
		
		// strings
		if (c == '"') {
			size_t start = ++pos; // skip the opening quote
			while (pos < input.length && input[pos] != '"')
				pos++;
			string lexeme = input[start .. pos];
			pos++; // skip closing quote
			tokens ~= Token(TokenType.StringLiteral, lexeme);
			continue;
		}
		
		// dots
		if (c == '.' && peekNext(input, pos) == '.') {
			tokens ~= Token(TokenType.DotDot, "..");
			pos += 2;
			continue;
		}


        // Single-character tokens
		if (c == '[') { tokens ~= Token(TokenType.LBracket, "["); pos++; continue; }
		if (c == ']') { tokens ~= Token(TokenType.RBracket, "]"); pos++; continue; }
        if (c == '(') { tokens ~= Token(TokenType.LParen, "("); pos++; continue; }
        if (c == ')') { tokens ~= Token(TokenType.RParen, ")"); pos++; continue; }
        if (c == '{') { tokens ~= Token(TokenType.LBrace, "{"); pos++; continue; }
        if (c == '}') { tokens ~= Token(TokenType.RBrace, "}"); pos++; continue; }
        if (c == ';') { tokens ~= Token(TokenType.Semicolon, ";"); pos++; continue; }
        if (c == '=') { tokens ~= Token(TokenType.Assign, "="); pos++; continue; }
        if (c == '*') { tokens ~= Token(TokenType.Star, "*"); pos++; continue; }
        if (c == '/') { tokens ~= Token(TokenType.Slash, "/"); pos++; continue; }
		if (c == ',') { tokens ~= Token(TokenType.Comma, ","); pos++; continue; }
		if (c == ':') { tokens ~= Token(TokenType.Colon, ":"); pos++; continue; }
		if (c == '-') { tokens ~= Token(TokenType.Minus, "-"); pos++; continue; }
		if (c == '<') { tokens ~= Token(TokenType.Less, "<"); pos++; continue; }
		if (c == '>') { tokens ~= Token(TokenType.Greater, ">"); pos++; continue; }
		if (c == '.') { tokens ~= Token(TokenType.Dot, "."); pos++; continue; }

        // Numbers
        if (isDigit(c)) {
            size_t start = pos;
            while (pos < input.length && isDigit(input[pos]))
                pos++;
            tokens ~= Token(TokenType.Number, input[start .. pos]);
            continue;
        }

        // Identifiers and keywords
        if (isAlpha(c)) {
            size_t start = pos;
            while (pos < input.length && (isAlpha(input[pos]) || isDigit(input[pos])))
                pos++;
            string lexeme = input[start .. pos];

            // Check if lexeme is a keyword
			if (lexeme == "int")
				tokens ~= Token(TokenType.Int, lexeme);
			else if (lexeme == "return")
				tokens ~= Token(TokenType.Return, lexeme);
			else if (lexeme == "byte")
				tokens ~= Token(TokenType.Byte, lexeme);
			else if (lexeme == "if")
				tokens ~= Token(TokenType.If, lexeme);
			else if (lexeme == "else")
				tokens ~= Token(TokenType.Else, lexeme);
			else if (lexeme == "while")
				tokens ~= Token(TokenType.While, lexeme);
			else if (lexeme == "true")
				tokens ~= Token(TokenType.True, lexeme);
			else if (lexeme == "false")
				tokens ~= Token(TokenType.False, lexeme);
			else if (lexeme == "bool")
				tokens ~= Token(TokenType.Bool, lexeme);
			else if (lexeme == "string")
				tokens ~= Token(TokenType.String, lexeme);
			else if (lexeme == "for")
				tokens ~= Token(TokenType.For, lexeme);
			else if (lexeme == "foreach")
				tokens ~= Token(TokenType.Foreach, lexeme);
			else if (lexeme == "break")
				tokens ~= Token(TokenType.Break, lexeme);
			else if (lexeme == "case")
				tokens ~= Token(TokenType.Case, lexeme);
			else if (lexeme == "continue")
				tokens ~= Token(TokenType.Continue, lexeme);
			else if (lexeme == "default")
				tokens ~= Token(TokenType.Default, lexeme);
			else if (lexeme == "var")
				tokens ~= Token(TokenType.Var, lexeme);
			else if (lexeme == "struct")
				tokens ~= Token(TokenType.Struct, lexeme);
			else if (lexeme == "function")
				tokens ~= Token(TokenType.Function, lexeme);
			else if (lexeme == "switch")
				tokens ~= Token(TokenType.Switch, lexeme);
			else if (lexeme == "case")
				tokens ~= Token(TokenType.Identifier, lexeme);
			else if (lexeme == "to")
				tokens ~= Token(TokenType.To, lexeme);
			else if (lexeme == "step")
				tokens ~= Token(TokenType.Step, lexeme);
			else 
				tokens ~= Token(TokenType.Identifier, lexeme);
            continue;
        }

        // Unknown character (skip or error)
        pos++; // Could also log an error here
    }

    tokens ~= Token(TokenType.Eof, "");
    return tokens;
}

bool isAlpha(char c) {
    return (c >= 'a' && c <= 'z') || (c >= 'A' && c <= 'Z') || c == '_';
}

bool isDigit(char c) {
    return c >= '0' && c <= '9';
}

char peekNext(string input, size_t pos) {
    return (pos + 1 < input.length) ? input[pos + 1] : '\0';
}

