module main;

import frontend.lexer;
import frontend.parser;
import backend.codegen;
import std.stdio;
import std.file : write;
import std.file;

bool hasErrors = false;

void main() {
    string code = readText("tests/hello.dl");
	
    auto tokens = tokenize(code);
	
	foreach (t; tokens) {
		writeln(t.type, " : ", t.lexeme);
	}

	auto ast = parse(tokens);

	foreach (stmt; ast) {
		writeln("[AST] ", typeid(stmt).name);
		// if you want: writefln("%s", stmt); if you implemented toString() on nodes
	}
	string asmOutput = generateCode(ast);

	write("output/generated.asm", asmOutput);
	writeln("[✓] Generated output/generated.asm");
}

	