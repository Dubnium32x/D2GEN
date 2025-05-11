module frontend.lexer;

import std.string;

enum TokenType {
    Import,
	Int,
    Identifier,
    Return,
    Number,

    Equal,
	PlusPlus, MinusMinus,
	// For the sake of simplicity, we can use the same token for both
	// `+` and `+=`, `-` and `-=`, etc.
    Plus, Minus, Star, Slash,
    
    Const, // For const keyword
    Mixin, // For mixin keyword
    Template, // For template keyword

	Dot,
	DotDot,

	If, Else, While,
	Greater, Less, EqualEqual, // for `==`
	Assign,
	Ampersand,
	TildeEqual, // for `~=` (not equal)
	Bool,
	String,
	NotEqual,
	LessEqual,
	GreaterEqual,
	PlusEqual,
	MinusEqual,
	StarEqual,
	SlashEqual,
	Bang, // for !
	Mod,
	ModEqual,
	Dollar,
	
	For, Foreach,
	Break, Continue, Default,

	Switch, Case,
	To, Step,

	Enum,

	Var,
	Struct,
	Function,
	Void,

	Auto,
	Cast,
	Null,
	Assert,

	Public,
	Private,
	Protected,
	Static,

	StringLiteral,
	
	True,
	False,
	AndAnd,
	OrOr,

	Byte,
	Short,

	Comment,
	CommentBlockStart,
	CommentBlockEnd,

	LBracket, RBracket,
    LBrace, RBrace,
    LParen, RParen,
    Semicolon,
	Colon,
	Comma,
	Question,
    Eof
}


struct Token {
    TokenType type;
    string lexeme;
}

Token[] tokenize(string input) {
	Token[] tokens;
	size_t pos = 0;
	int line = 1;

	while (pos < input.length) {
		char c = input[pos];

        // Skip whitespace
        if (c == ' ' || c == '\n' || c == '\r' || c == '\t') {
            pos++;
            continue;
        }
		if (c == '\n') {
			tokens ~= Token(TokenType.Comment, "");
			line++;
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
		if (c == '~' && peekNext(input, pos) == '=') {
			tokens ~= Token(TokenType.TildeEqual, "~=");
			pos += 2;
			continue;
		}
		else if (c == '+') {
			if (peekNext(input, pos) == '=') {
				tokens ~= Token(TokenType.PlusEqual, "+=");
				pos += 2;
				continue;
			}
		}
		else if (c == '-') {
			if (peekNext(input, pos) == '=') {
				tokens ~= Token(TokenType.MinusEqual, "-=");
				pos += 2;
				continue;
			}
		}
		else if (c == '*') {
			if (peekNext(input, pos) == '=') {
				tokens ~= Token(TokenType.StarEqual, "*=");
				pos += 2;
				continue;
			}
		}
		else if (c == '/') {
			if (peekNext(input, pos) == '=') {
				tokens ~= Token(TokenType.SlashEqual, "/=");
				pos += 2;
				continue;
			}
		}
		// Comments
		if (c == '/') {
			if (peekNext(input, pos) == '/') {
				while (pos < input.length && input[pos] != '\n')
					pos++;
				continue;
			}
			else if (peekNext(input, pos) == '*') {
				tokens ~= Token(TokenType.CommentBlockStart, "/*");
				pos += 2;
				continue;
			}
		}
		else if (c == '*') {
			if (peekNext(input, pos) == '/') {
				tokens ~= Token(TokenType.CommentBlockEnd, "*/");
				pos += 2;
				continue;
			}
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
		if (c == '?') { tokens ~= Token(TokenType.Question, "?"); pos++; continue; }
		if (c == ':') { tokens ~= Token(TokenType.Colon, ":"); pos++; continue; }
		if (c == '-') { tokens ~= Token(TokenType.Minus, "-"); pos++; continue; }
		if (c == '<') { tokens ~= Token(TokenType.Less, "<"); pos++; continue; }
		if (c == '>') { tokens ~= Token(TokenType.Greater, ">"); pos++; continue; }
		if (c == '.') { tokens ~= Token(TokenType.Dot, "."); pos++; continue; }
		if (c == '%') { tokens ~= Token(TokenType.Mod, "%"); pos++; continue; }
		if (c == '$') { tokens ~= Token(TokenType.Dollar, "$"); pos++; continue; }
		if (c == '&') { tokens ~= Token(TokenType.Ampersand, "&"); pos++; continue; }

        // Numbers
        if (isDigit(c)) {
            size_t start = pos;
            while (pos < input.length && isDigit(input[pos]))
                pos++;
            // Check for float (dot followed by digit)
            if (pos < input.length && input[pos] == '.' && pos + 1 < input.length && isDigit(input[pos + 1])) {
                // Skip the float and print an error
                size_t floatStart = start;
                pos++; // skip dot
                while (pos < input.length && isDigit(input[pos]))
                    pos++;
                string lexeme = input[floatStart .. pos];
                import std.stdio : writeln;
                writeln("ERROR: Float literal '", lexeme, "' not supported on this platform.");
                continue;
            }
            string lexeme = input[start .. pos];
            tokens ~= Token(TokenType.Number, lexeme);
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
            else if (lexeme == "enum")
                tokens ~= Token(TokenType.Enum, lexeme);
            else if (lexeme == "auto")
                tokens ~= Token(TokenType.Auto, lexeme);
            else if (lexeme == "cast")
                tokens ~= Token(TokenType.Cast, lexeme);
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
            else if (lexeme == "null")
                tokens ~= Token(TokenType.Null, lexeme);
            else if (lexeme == "assert")
                tokens ~= Token(TokenType.Assert, lexeme);
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
            else if (lexeme == "struct")
                tokens ~= Token(TokenType.Struct, lexeme);
            else if (lexeme == "void")
                tokens ~= Token(TokenType.Void, lexeme);
            else if (lexeme == "function")
                tokens ~= Token(TokenType.Function, lexeme);
            else if (lexeme == "import")
                tokens ~= Token(TokenType.Import, lexeme);
            else if (lexeme == "public")
                tokens ~= Token(TokenType.Public, lexeme);
            else if (lexeme == "private")
                tokens ~= Token(TokenType.Private, lexeme);
            else if (lexeme == "protected")
                tokens ~= Token(TokenType.Protected, lexeme);
            else if (lexeme == "static")
                tokens ~= Token(TokenType.Static, lexeme);
            else if (lexeme == "const")
                tokens ~= Token(TokenType.Const, lexeme);
            else if (lexeme == "mixin")
                tokens ~= Token(TokenType.Mixin, lexeme);
            else if (lexeme == "template")
                tokens ~= Token(TokenType.Template, lexeme);
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

