module gen_compiler;

// This module generates a Sega Genesis program from a D file.

import std.stdio;
import std.file;
import std.string;

import compiler.lexer;
import compiler.parser;
import compiler.semantic;
import compiler.codegen;

void gen_compiler(string directory) {
    try {
        // Read the source code from main.d
        string mainFile = directory ~ "/src/main.d";
        if (!exists(mainFile)) {
            throw new Exception("Main file not found: " ~ mainFile);
        }
        string sourceCode = readText(mainFile);

        // Check for a header marker in main.d
        if (!sourceCode.startsWith("// COMPILE")) {
            throw new Exception("Invalid main file format. Expected '// COMPILE' header.");
        }

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
        
        // Output the generated assembly code
        writeln("Generated Assembly:");
        writeln(asmCode);
        
        // Save the assembly code to a .s file
        string outputFile = directory ~ "/output.s";
        generator.emitToFile(outputFile, asmCode);
        writeln("Assembly saved to ", outputFile);
        
    } catch (Exception e) {
        stderr.writeln("Error: ", e.msg);
    }
}
