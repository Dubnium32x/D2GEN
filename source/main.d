module main;

import frontend.lexer;
import frontend.parser;
import backend.codegen;
import std.stdio;
import std.file : write;
import std.file;
import std.string;
import std.array;

bool hasErrors = false;

// Helper function to check if a string contains a substring
bool contains(string haystack, string needle) {
    return haystack.indexOf(needle) >= 0;
}

void main() {
    string code = readText("tests/visibility_test.dl");
    
    auto tokens = tokenize(code);
    auto ast = parse(tokens);
    
    // Disable debug output in assembly
    backend.codegen.enableDebugOutput = false;
    
    string asmOutput = generateCode(ast);
    
    // Clean up any debug statements in the generated assembly
    string[] lines = asmOutput.split('\n');
    string[] cleanedLines;
    
    foreach(line; lines) {
        if (!line.strip().startsWith("; DEBUG:") && 
            !line.strip().startsWith("; WARNING:") &&
            !line.contains("Entered handleAssignStmt"))
        {
            cleanedLines ~= line;
        }
    }
    
    // Add helpful comments to the assembly output for readability
    for (int i = 0; i < cleanedLines.length; i++) {
        // Add comments for constant initialization
        if (cleanedLines[i].contains("move.l #")) {
            // Look for constant initialization patterns
            if (i > 0 && cleanedLines[i-1].contains("move.l") && 
                !cleanedLines[i-1].contains("; ")) {
                cleanedLines[i] ~= "  ; Initialize constant";
            }
        }
        
        // Add separator comments for array and pointer operations
        if (cleanedLines[i].contains("lea ") && !cleanedLines[i].contains("; ")) {
            cleanedLines[i] ~= "  ; Load effective address";
        }
        
        // Add comments for array indexing
        if (cleanedLines[i].contains("mulu #") && !cleanedLines[i].contains("; ")) {
            cleanedLines[i] ~= "  ; Compute array offset";
        }
        
        // Add comments for loop counters
        if (cleanedLines[i].contains("addq.l #1") && !cleanedLines[i].contains("; ")) {
            cleanedLines[i] ~= "  ; Increment loop counter";
        }
    }
    
    asmOutput = cleanedLines.join('\n');
    write("output/generated.asm", asmOutput);
    writeln("[✓] Generated output/generated.asm");
}

	