import frontend.lexer;
import frontend.parser;
import backend.codegen;
import std.stdio;
import std.file : write;
import std.file;

void main() {
    string code = readText("tests/hello.dl");

    auto tokens = tokenize(code);
	auto ast = parseProgram(tokens); // returns ASTNode[]
	string asmOutput = generateCode(ast);

	write("output/generated.asm", asmOutput);
	writeln("[✓] Generated output/generated.asm");
}

