module frontend.lexer;

import std.string;
import std.ascii;

enum TokenType {
    Int,
    Identifier,
    Return,
    Number,

    Equal,
    Plus, Minus, Star, Slash,

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

        // Single character symbols
        if (c == '(') { tokens ~= Token(TokenType.LParen, "("); pos++; continue; }
        if (c == ')') { tokens ~= Token(TokenType.RParen, ")"); pos++; continue; }
        if (c == '{') { tokens ~= Token(TokenType.LBrace, "{"); pos++; continue; }
        if (c == '}') { tokens ~= Token(TokenType.RBrace, "}"); pos++; continue; }
        if (c == ';') { tokens ~= Token(TokenType.Semicolon, ";"); pos++; continue; }
		if (c == '=') { tokens ~= Token(TokenType.Equal, "="); pos++; continue; }
		if (c == '+') { tokens ~= Token(TokenType.Plus, "+"); pos++; continue; }
		if (c == '-') { tokens ~= Token(TokenType.Minus, "-"); pos++; continue; }
		if (c == '*') { tokens ~= Token(TokenType.Star, "*"); pos++; continue; }
		if (c == '/') { tokens ~= Token(TokenType.Slash, "/"); pos++; continue; }

		
		
        // Numbers
        if (c >= '0' && c <= '9') {
            size_t start = pos;
            while (pos < input.length && input[pos] >= '0' && input[pos] <= '9')
                pos++;
            tokens ~= Token(TokenType.Number, input[start .. pos]);
            continue;
        }

        // Identifiers or keywords
        if (isAlpha(c)) {
            size_t start = pos;
            while (pos < input.length && (isAlpha(input[pos]) || isDigit(input[pos])))
                pos++;
            string lexeme = input[start .. pos];

            if (lexeme == "int") {
                tokens ~= Token(TokenType.Int, lexeme);
            } else if (lexeme == "return") {
                tokens ~= Token(TokenType.Return, lexeme);
            } else {
                tokens ~= Token(TokenType.Identifier, lexeme);
            }

            continue;
        }

        // Unknown char
        pos++; // Skip unknowns (future: error)
    }

    tokens ~= Token(TokenType.Eof, "");
    return tokens;
}

bool isAlpha(char c) {
    return c >= 'a' && c <= 'z' || c >= 'A' && c <= 'Z' || c == '_';
}

bool isDigit(char c) {
    return c >= '0' && c <= '9';
}
