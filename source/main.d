module main;


// This was tested on a Windows XP virtual machine. 
// This is not even close to a final product. It uses DMD v2.067.1 for now.

import std.stdio;
import compiler.lexer;
import compiler.parser;
import compiler.semantic;
import compiler.codegen;

void main() {
    string sourceCode = 
    "int main() {\n" ~ 
    "    return 42;\n" ~
    "}";
    
    try {
        // Lexing
        Lexer lexer = new Lexer(sourceCode);
        Token[] tokens = lexer.tokenize();
        
        // Parsing
        Parser parser = new Parser(tokens);
        auto ast = parser.parseFunction();
        
        // Semantic analysis
        SemanticAnalyzer analyzer = new SemanticAnalyzer();
        analyzer.analyze(ast);
        
        // Code generation
        CodeGenerator generator = new CodeGenerator();
        string asmCode = generator.generate(ast);
        
        // Output
        writeln("Generated Assembly:");
        writeln(asmCode);
        
        // Save to file
        generator.emitToFile("output.s", asmCode);
        writeln("Assembly saved to output.s");
        
        // On Linux/Unix you could call: gcc output.s -o output
    } catch (Exception e) {
        stderr.writeln("Error: ", e.msg);
    }
}
