import frontend.lexer;
import frontend.parser;
import backend.codegen;
import std.stdio;
import std.file : write;
import std.file;

void main() {
    string code = readText("tests/hello.dl");
	
    auto tokens = tokenize(code);
	
	foreach (t; tokens) {
		writeln(t.type, " : ", t.lexeme);
	}

	auto ast = parseProgram(tokens);

	foreach (stmt; ast) {
		writeln("[AST] ", typeid(stmt).name);
	}

	string asmOutput = generateCode(ast);

	write("output/generated.asm", asmOutput);
	writeln("[✓] Generated output/generated.asm");
}

	