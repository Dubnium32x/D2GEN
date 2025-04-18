module frontend.lexer;

import std.string;

enum TokenType {
    Int,
    Identifier,
    Return,
    Number,

    Equal,
    Plus, Minus, Star, Slash,

	If, Else, While,
	Greater, Less, EqualEqual, // for `==`
	Assign,                    // single =

    LBrace, RBrace,
    LParen, RParen,
    Semicolon,
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

        // Single-character tokens
        if (c == '(') { tokens ~= Token(TokenType.LParen, "("); pos++; continue; }
        if (c == ')') { tokens ~= Token(TokenType.RParen, ")"); pos++; continue; }
        if (c == '{') { tokens ~= Token(TokenType.LBrace, "{"); pos++; continue; }
        if (c == '}') { tokens ~= Token(TokenType.RBrace, "}"); pos++; continue; }
        if (c == ';') { tokens ~= Token(TokenType.Semicolon, ";"); pos++; continue; }
        if (c == '=') { tokens ~= Token(TokenType.Assign, "="); pos++; continue; }
        if (c == '+') { tokens ~= Token(TokenType.Plus, "+"); pos++; continue; }
        if (c == '-') { tokens ~= Token(TokenType.Minus, "-"); pos++; continue; }
        if (c == '*') { tokens ~= Token(TokenType.Star, "*"); pos++; continue; }
        if (c == '/') { tokens ~= Token(TokenType.Slash, "/"); pos++; continue; }
        if (c == '>') { tokens ~= Token(frontend.lexer.TokenType.Greater, ">"); pos++; continue; }
        if (c == '<') { tokens ~= Token(frontend.lexer.TokenType.Less, "<"); pos++; continue; }

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
            else if (lexeme == "if")
                tokens ~= Token(TokenType.If, lexeme);
            else if (lexeme == "else")
                tokens ~= Token(TokenType.Else, lexeme);
            else if (lexeme == "while")
                tokens ~= Token(TokenType.While, lexeme);
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

