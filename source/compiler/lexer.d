module compiler.lexer;

import core.stdc.string;
import std.array;
import std.ascii;
import std.conv;

enum TokenType {
    Identifier,
    Keyword,
    Number,
    Symbol,
    OpenParen,
    CloseParen,
    OpenBrace,
    CloseBrace,
    Semicolon,
    Comma,
    Assign,
    Return,
    EOF
}

string toString(TokenType type) {
	final switch (type) {
		case TokenType.Identifier: return "Identifier";
		case TokenType.Keyword: return "Keyword";
		case TokenType.Number: return "Number";
		case TokenType.Symbol: return "Symbol";
		case TokenType.OpenParen: return "OpenParen";
		case TokenType.CloseParen: return "CloseParen";
		case TokenType.OpenBrace: return "OpenBrace";
		case TokenType.CloseBrace: return "CloseBrace";
		case TokenType.Semicolon: return "Semicolon";
		case TokenType.Comma: return "Comma";
		case TokenType.Assign: return "Assign";
		case TokenType.Return: return "Return";
		case TokenType.EOF: return "EOF";
	}
}

struct Token {
    TokenType type;
    string lexeme;
    size_t line;
    size_t column;
}

class Lexer {
    private string source;
    private size_t pos = 0;
    private size_t line = 1;
    private size_t column = 1;

    this(string code) {
        this.source = code;
    }

	private void advance() {
		if (!eof()) {
			pos++;
			column++;
		}
	}
	
	private Token makeToken(TokenType type, string lexeme) {
		return Token(type, lexeme, line, column);
	}
	
    Token[] tokenize() {
        Token[] tokens;

        while (!eof()) {
            skipWhitespace();

            if (eof()) break;

            char c = peek();

            if (isAlpha(c)) {
                tokens ~= readIdentifierOrKeyword();
            } else if (isDigit(c)) {
                tokens ~= readNumber();
            } else {
                switch (c) {
                    case '(': tokens ~= makeToken(TokenType.OpenParen, "("); advance(); break;
                    case ')': tokens ~= makeToken(TokenType.CloseParen, ")"); advance(); break;
                    case '{': tokens ~= makeToken(TokenType.OpenBrace, "{"); advance(); break;
                    case '}': tokens ~= makeToken(TokenType.CloseBrace, "}"); advance(); break;
                    case ';': tokens ~= makeToken(TokenType.Semicolon, ";"); advance(); break;
                    case ',': tokens ~= makeToken(TokenType.Comma, ","); advance(); break;
                    case '=': tokens ~= makeToken(TokenType.Assign, "="); advance(); break;
                    default:
                        tokens ~= makeToken(TokenType.Symbol, c.to!string);
                        advance();
                }
            }
        }

        tokens ~= Token(TokenType.EOF, "", line, column);
        return tokens;
    }

    private Token readIdentifierOrKeyword() {
        auto start = pos;
        while (!eof() && (isAlpha(peek()) || isDigit(peek()) || peek() == '_'))
            this.advance();

        string lexeme = source[start .. pos];

        if (lexeme == "int" || lexeme == "short" || lexeme == "byte")
            return Token(TokenType.Keyword, lexeme, line, column);
        else if (lexeme == "return")
            return Token(TokenType.Return, lexeme, line, column);
        else
            return Token(TokenType.Identifier, lexeme, line, column);
    }

    private Token readNumber() {
        auto start = pos;
        while (!eof() && isDigit(peek()))
            this.advance();

        return Token(TokenType.Number, source[start .. pos], line, column);
    }

    private void skipWhitespace() {
        while (!eof()) {
            char c = peek();
            if (c == ' ' || c == '\t') {
                this.advance();
            } else if (c == '\n') {
                line++;
                column = 1;
                this.advance();
            } else {
                break;
            }
        }
    }

	private char peek() {
		if (pos < source.length) return source[pos];
		return '\0';
	}
	
	private bool eof() {
		return pos >= source.length;
	}
	
	private bool isAlpha(char c) {
		return c.isAlpha() || c == '_';
	}
	
	private bool isDigit(char c) {
		return c >= '0' && c <= '9';
	}
}
