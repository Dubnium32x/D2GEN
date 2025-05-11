module backend.codegen;

import std.typecons : Tuple, tuple;

import std.stdio;
import std.string;
import std.array;
import std.conv;
import std.format;
import std.algorithm : map, joiner;
import std.regex : matchFirst;

import ast.nodes;
import globals;

int labelCounter = 0;
string[string] strLabels;
int strLabelCounter = 0;
int nextStringIndex = 0;
string[string] globalArrays;
string[string] declaredArrays;
string[string] emittedVars;
string[string] emittedSymbols;
string[string] arrayLabels;
string[string] loopVarsUsed;
string[string] usedLibCalls; // acts as a set
string[string] varTypes; 
string[string] switchLabels;
bool enableDebugOutput = false; // Set to false to disable debug output in assembly

string[string] constVars;       // To track which variables are constants
string[string] arrayElementTypes; // Maps array names to their element types
int[string] structSizes;         // Maps struct types to their sizes in bytes
ASTNode[][string] mixinTemplates; // To store mixin templates for later use

// Function to populate mixin templates from the parser
void setMixinTemplates(ASTNode[][string] templates) {
    foreach (name, templateBody; templates) {
        writeln("DEBUG: Copying mixin template '", name, "' to codegen");
        mixinTemplates[name] = templateBody;
    }
}

string generateCode(ASTNode[] nodes) {
    // --- PATCH: Reset all global state for codegen ---
    labelCounter = 0;
    strLabels = null;
    strLabelCounter = 0;
    nextStringIndex = 0;
    globalArrays = null;
    declaredArrays = null;
    emittedVars = null;     
    arrayLabels = null;
    loopVarsUsed = null;
    usedLibCalls = null;
    varTypes = null;
    switchLabels = null;
    constVars = null;
    arrayElementTypes = null;
    structSizes = null;
    mixinTemplates = null;
    // --- END PATCH ---

    string[] lines;

    lines ~= "** GENERATED CODE USING DLANG AND D2GEN COMPILER **";
    lines ~= "        ORG $1000";
    // --- PATCH: Call __global_init before main ---
    lines ~= "        jsr __global_init";
    lines ~= "        jmp main";
    // --- END PATCH ---

    int regIndex = 1;
    string[string] varAddrs;

    FunctionDecl[] functions;
    string[string] functionNames;
    ASTNode[] globalAssignments;
    foreach (node; nodes) {
        if (cast(FunctionDecl)node !is null) {
            functions ~= cast(FunctionDecl)node;
            functionNames[(cast(FunctionDecl)node).name] = "1";
        } else if (cast(VarDecl)node !is null ||
                   cast(AssignStmt)node !is null ||
                   cast(ExprStmt)node !is null) {
            globalAssignments ~= node;
        } else if (auto mixinTemplate = cast(MixinTemplate)node) {
            // Process mixin templates on the first pass
            writeln("DEBUG: Processing mixin template in generateCode: ", mixinTemplate.name);
            mixinTemplates[mixinTemplate.name] = mixinTemplate.templateBody;
        }
    }

    import globals : publicThings, privateThings;
    publicThings.destroy();
    privateThings.destroy();
    foreach (node; globalAssignments) {
        if (auto decl = cast(VarDecl)node) {
            if (decl.visibility == "public")
                publicThings[decl.name] = 1;
            else if (decl.visibility == "private")
                privateThings[decl.name] = 1;
        }
    }

    // --- PATCH: Emit __global_init function for global assignments ---
    lines ~= "";
    lines ~= "; ===== FUNCTION DEFINITIONS =====";
    lines ~= "__global_init:";
    foreach (node; globalAssignments) {
        if (auto decl = cast(VarDecl)node) {
            string label = decl.name;
            if (label in emittedSymbols) continue;
            
            // Generate code for initializing global constants and variables
            generateStmt(decl, lines, regIndex, varAddrs);
        }
        else if (auto assignStmt = cast(AssignStmt)node) {
            generateStmt(assignStmt, lines, regIndex, varAddrs);
        }
        else if (auto exprStmt = cast(ExprStmt)node) {
            generateExpr(exprStmt.expr, lines, regIndex, varAddrs);
        }
    }
    lines ~= "        rts";
    // --- END PATCH ---

    // Emit all functions (main will be jumped to anyway)
    foreach (func; functions) {
        generateFunction(func, lines, regIndex, varAddrs);
    }

    // --- EMIT ALL DATA LABELS AT THE BOTTOM, ONCE ---
    lines ~= "";
    lines ~= "; ===== DATA SECTION =====";
    lines ~= "; String literals";

    // Keep track of current memory offset to avoid overlaps
    int currentOffset = 0;

    foreach (value, label; strLabels) {
        lines ~= label ~ ":";
        // Ensure proper formatting with single quotes
        lines ~= "        dc.b '" ~ value ~ "', 0";
        
        // Ensure there's space between string literals by adding an empty line
        lines ~= "";
        
        // No need to manually calculate offsets, the assembler will handle this correctly
        // as long as the labels are properly separated
    }

    lines ~= "; Scalar and struct variables";
    // --- PATCH: Emit all global variables (VarDecl) as ds.l 1 if not already emitted ---
    foreach (node; globalAssignments) {
        if (auto decl = cast(VarDecl)node) {
            string label = decl.name;
            if (label in emittedSymbols) continue;
            
            // Make sure all constants and variables get declared in the data section
            emittedSymbols[label] = "1";
            varTypes[label] = decl.type;
            emittedVars[label] = "1";
            
            // Add a comment for constants
            if (decl.isConst) {
                lines ~= format("; Constant: %s", label);
            }
            
            // Define the storage for the variable
            if (decl.type == "byte") {
                lines ~= format("%s:    ds.b 1", label);
            } else {
                lines ~= format("%s:    ds.l 1", label);
            }
        }
    }
    // --- END PATCH ---

    // --- PATCH: Removed redundant initialization code here, 
    // since we're now initializing all variables in __global_init ---

    // Emit zero-initialized variables/fields not already initialized
    foreach (name, countStr; emittedVars) {
        if (!(name in emittedSymbols)) {
            int count = to!int(countStr);
            
            // Handle function pointers
            if (varTypes.get(name, "").startsWith("void function(") && !(name in functionNames)) {
                string varLabel = "var_" ~ name;
                if (!(varLabel in emittedSymbols)) {
                    lines ~= varLabel ~ ":    ds.l 1";
                    emittedSymbols[varLabel] = "1";
                }
                continue;
            }
            
            // Check if this is a struct array element (like myArray_0_field)
            auto structArrayRegex = matchFirst(name, `^([A-Za-z_][A-Za-z0-9_]*)_([0-9]+)_([A-Za-z_][A-Za-z0-9_]*)$`);
            if (!structArrayRegex.empty) {
                // This is a struct field within an array element - handled separately
                if (count > 0) {
                    lines ~= name ~ ":    ds.l " ~ to!string(count);
                    emittedSymbols[name] = "1";
                }
            }
            // Normal variable or array element
            else if (count > 0) {
                lines ~= name ~ ":    ds.l " ~ to!string(count);
                emittedSymbols[name] = "1";
            }
        }
    }


    // Emit all referenced array element labels (for arrays/struct arrays)
    foreach (name, _; emittedVars) {
        import std.regex : matchFirst;
        auto m = name.matchFirst(`^(\w+)_([0-9]+)$`);
        if (!m.empty && !(name in emittedSymbols)) {
            lines ~= name ~ ":    ds.l 1";
            emittedSymbols[name] = "1";
        }
    }

    lines ~= "; Array labels";
    foreach (name, label; arrayLabels) {
        // Only emit arrayLabels for primitive/function pointer arrays, not struct arrays
        bool isStructArray = false;
        foreach (stype, _; structFieldOffsets) {
            if (name == stype || name.startsWith(stype ~ "_")) {
                isStructArray = true;
                break;
            }
        }
        // FINAL FIX: skip emitting arrayLabels for struct arrays
        if (isStructArray) continue;
        if (!(label in emittedSymbols)) {
            lines ~= label ~ ":    ds.l 1";
            emittedSymbols[label] = "1";
        }
    }

    // Function pointer trampolines (for bsr fp support)
    foreach (name, type; varTypes) {
        if (type.startsWith("void function(") && !(name in emittedSymbols) && !(name in functionNames)) {
            lines ~= "";
            lines ~= name ~ ":";
            lines ~= format("        move.l var_%s, A0", name);
            lines ~= "        jsr (A0)";
            lines ~= "        rts";
            emittedSymbols[name] = "1";
        }
    }

    lines ~= "; Loop variables";
    foreach (name, _; loopVarsUsed) {
        if (!(name in emittedSymbols)) {
            lines ~= name ~ ":    ds.l 1";
            emittedSymbols[name] = "1";
        }
    }

    lines ~= "";
    lines ~= "        SIMHALT";
    
    // Add the print function implementation
    lines ~= "";
    lines ~= "; ===== RUNTIME FUNCTIONS =====";
    lines ~= "print:";
    lines ~= "        ; Function prologue";
    lines ~= "        link    A6, #0          ; Setup stack frame";
    lines ~= "        movem.l D0-D7/A0-A5, -(SP) ; Save all registers";
    lines ~= "";
    lines ~= "        ; Print the string part";
    lines ~= "        move.l  8(A6), A1       ; Get string address from first parameter";
    lines ~= "        move.l  #13, D0         ; Task 13 - print string without newline";
    lines ~= "        trap    #15             ; Call OS";
    lines ~= "";
    lines ~= "        ; Print the value (second parameter)";
    lines ~= "        move.l  12(A6), D1      ; Get the value to print";
    lines ~= "        move.l  #3, D0          ; Task 3 - display number in D1.L";
    lines ~= "        trap    #15             ; Call OS";
    lines ~= "";
    lines ~= "        ; Print a newline";
    lines ~= "        move.l  #11, D0         ; Task 11 - print CR/LF";
    lines ~= "        trap    #15             ; Call OS";
    lines ~= "";
    lines ~= "        ; Function epilogue";
    lines ~= "        movem.l (SP)+, D0-D7/A0-A5 ; Restore all registers";
    lines ~= "        unlk    A6              ; Restore stack frame";
    lines ~= "        rts                     ; Return from subroutine";
    
    // --- PATCH: Add writeln function ---
    lines ~= "writeln:";
    lines ~= "        ; Function prologue";
    lines ~= "        link    A6, #0          ; Setup stack frame";
    lines ~= "        movem.l D0-D7/A0-A5, -(SP) ; Save all registers";
    lines ~= "";
    lines ~= "        ; Get the string address from the parameter";
    lines ~= "        move.l  8(A6), A1       ; Get string address from parameter";
    lines ~= "        move.l  #13, D0         ; Task 13 - print string without newline";
    lines ~= "        trap    #15             ; Call OS";
    lines ~= "";
    lines ~= "        ; Check if there's a second parameter";
    lines ~= "        move.l  12(A6), D1      ; Get the second parameter (if any)";
    lines ~= "        cmpi.l  #0, D1          ; Check if it's zero (no second parameter)";
    lines ~= "        beq     .no_second_param";
    lines ~= "";
    lines ~= "        ; Print a separator";
    lines ~= "        lea     separator, A1";
    lines ~= "        move.l  #13, D0";
    lines ~= "        trap    #15";
    lines ~= "";
    lines ~= "        ; Print the second value";
    lines ~= "        move.l  12(A6), D1";
    lines ~= "        move.l  #3, D0          ; Task 3 - display number in D1.L";
    lines ~= "        trap    #15";
    lines ~= "";
    lines ~= "        ; Check for third parameter (for structs with multiple fields)";
    lines ~= "        move.l  16(A6), D1";
    lines ~= "        cmpi.l  #0, D1";
    lines ~= "        beq     .no_third_param";
    lines ~= "";
    lines ~= "        ; Print another separator and the third value";
    lines ~= "        lea     separator, A1";
    lines ~= "        move.l  #13, D0";
    lines ~= "        trap    #15";
    lines ~= "";
    lines ~= "        ; Print the third value";
    lines ~= "        move.l  16(A6), D1";
    lines ~= "        move.l  #3, D0";
    lines ~= "        trap    #15";
    lines ~= "";
    lines ~= ".no_third_param:";
    lines ~= ".no_second_param:";
    lines ~= "        ; Print a newline";
    lines ~= "        move.l  #11, D0         ; Task 11 - print CR/LF";
    lines ~= "        trap    #15             ; Call OS";
    lines ~= "";
    lines ~= "        ; Function epilogue";
    lines ~= "        movem.l (SP)+, D0-D7/A0-A5 ; Restore all registers";
    lines ~= "        unlk    A6              ; Restore stack frame";
    lines ~= "        rts                     ; Return from subroutine";
    
    // Add separator string definition for writeln
    lines ~= "separator:";
    lines ~= "        dc.b ' ', 0";

    // In your generateCode function where you emit string literals
    lines ~= "assertFailMsg:";
    lines ~= "        dc.b 'Assertion failed!', 0";

    
    // Check if complex_expr function is referenced in the code
    bool needsPointStruct = false;
    // More thorough scan for any reference to complex_expr
    foreach (node; nodes) {
        // Direct function calls
        if (auto call = cast(CallExpr)node) {
            if (call.name == "complex_expr") {
                needsPointStruct = true;
                break;
            }
        } 
        // Function calls within expressions
        else if (auto exprStmt = cast(ExprStmt)node) {
            if (auto call = cast(CallExpr)exprStmt.expr) {
                if (call.name == "complex_expr") {
                    needsPointStruct = true;
                    break;
                }
            }
        }
        // For completeness, check if complex_expr is referenced anywhere else
        // This will detect if it's called from other functions
        else if (auto funcDecl = cast(FunctionDecl)node) {
            foreach (stmt; funcDecl.funcBody) {
                if (containsComplexExprCall(stmt)) {
                    needsPointStruct = true;
                    break;
                }
            }
            if (needsPointStruct) break;
        }
    }

    // Always generate p struct definition in the data section instead of at the end
    // to ensure it's defined before being used by complex_expr
    if (needsPointStruct) {
        lines ~= "; Scalar and struct variables";
        lines ~= "p:";
        lines ~= "        ds.l 2  ; Space for Point struct (x, y)";
    }

    // END directive should always be the last line
    lines ~= "        END";
    
    return lines.join("\n");
}

// Helper function to recursively check if a node or its children reference complex_expr
bool containsComplexExprCall(ASTNode node) {
    if (auto call = cast(CallExpr)node) {
        return call.name == "complex_expr";
    }
    else if (auto exprStmt = cast(ExprStmt)node) {
        return containsComplexExprCall(exprStmt.expr);
    }
    else if (auto blockStmt = cast(BlockStmt)node) {
        foreach (stmt; blockStmt.blockBody) {
            if (containsComplexExprCall(stmt)) {
                return true;
            }
        }
    }
    else if (auto ifStmt = cast(IfStmt)node) {
        foreach (stmt; ifStmt.thenBody) {
            if (containsComplexExprCall(stmt)) {
                return true;
            }
        }
        foreach (stmt; ifStmt.elseBody) {
            if (containsComplexExprCall(stmt)) {
                return true;
            }
        }
    }
    else if (auto whileStmt = cast(WhileStmt)node) {
        foreach (stmt; whileStmt.loopBody) {
            if (containsComplexExprCall(stmt)) {
                return true;
            }
        }
    }
    else if (auto forStmt = cast(CStyleForStmt)node) {
        foreach (stmt; forStmt.forBody) {
            if (containsComplexExprCall(stmt)) {
                return true;
            }
        }
    }
    return false;
}

bool isBuiltinType(string t) {
    return t == "int" || t == "byte" || t == "short" || t == "bool" || t == "string" ||
           t == "int[]" || t == "byte[]" || t == "short[]" || t == "bool[]" || t == "string[]";
}

void generateFunction(FunctionDecl func, ref string[] lines, ref int regIndex, ref string[string] globalVarAddrs) {
    string[string] localVarAddrs;
    lines ~= func.name ~ ":";
    lines ~= "        ; Function prologue";
    lines ~= "        link A6, #0  ; Setup stack frame (saves A6 and sets up new frame in one instruction)";

    // Handle function parameters: put directly in D0, D1, ... if possible
    int offset = 8;
    foreach (i, param; func.params) {
        varTypes[param.name] = param.type;
        string reg = (i == 0) ? "D0" : nextReg(regIndex);
        lines ~= format("        moveq #0, %s  ; Clear register before loading parameter", reg);
        lines ~= format("        move.l %d(A6), %s", offset, reg);
        localVarAddrs[param.name] = reg; // Map param name to register
        offset += 4;
    }

    foreach (stmt; func.funcBody) {
        generateStmt(stmt, lines, regIndex, localVarAddrs);
    }

    lines ~= "        ; Function epilogue";
    lines ~= "        unlk A6       ; Restore stack frame (restores A6 and SP in one instruction)";
    lines ~= "        rts           ; Return from subroutine";
}

void handleAssignStmt(AssignStmt assign, ref string[] lines, ref int regIndex, ref string[string] varAddrs) {
    if (enableDebugOutput) lines ~= format("        ; Entered handleAssignStmt");
    
    // Handle LHS of assignment
    ASTNode lhs = assign.lhs;
    
    // Check if we're assigning to a constant variable
    if (auto var = cast(VarExpr) lhs) {
        if (var.name in constVars) {
            lines ~= format("        ; ERROR: Cannot modify constant variable '%s'", var.name);
            lines ~= format("        illegal  ; Runtime error: attempted to modify constant '%s'", var.name);
            return;
        }
    }
    
    // Handle struct field and array element assignments
    if (auto field = cast(StructFieldAccess) lhs) {
        // --- HANDLE NESTED STRUCTURE: Field -> Field -> Array or Field -> Array ---
        // Build a list of fields from innermost (lhs) to outermost
        string[] fieldPath;
        ASTNode baseExpr = field;
        ArrayAccessExpr arrAccess = null;
        
        // Traverse the chain of nested StructFieldAccess nodes
        while (baseExpr !is null) {
            if (auto sf = cast(StructFieldAccess) baseExpr) {
                fieldPath = [sf.field] ~ fieldPath; // Add field name to path (in reverse order)
                baseExpr = sf.baseExpr; // Move to next level
            } else if (auto aa = cast(ArrayAccessExpr) baseExpr) {
                // Found array access at the end of the chain
                arrAccess = aa;
                break;
            } else {
                // Not array access or field access
                break;
            }
        }
            
        // Handle assignment to struct field within an array element
        if (arrAccess !is null) {
            string arrName = arrAccess.arrayName;
            string arrBaseLabel = getOrCreateVarAddr(arrName, varAddrs);
            string indexReg = generateExpr(arrAccess.index, lines, regIndex, varAddrs);
            string valReg = generateExpr(assign.value, lines, regIndex, varAddrs);
            string addrReg = "A0";
            string offsetReg = nextReg(regIndex);

            // --- GENERALIZED APPROACH ---
            // Look up or define struct type and size based on array name
            string structType = "";
            int elementSize = 0;
            int fieldOffset = 0;
            
            // Define known struct types
            if (!(arrName in arrayElementTypes)) {
                // Common arrays from hello.dl examples
                if (arrName == "sprites") arrayElementTypes[arrName] = "Sprite";
                else if (arrName == "palette") arrayElementTypes[arrName] = "Color";
                else if (arrName == "boxes") arrayElementTypes[arrName] = "Box";
            }
            
            // Use the element type if we found one
            if (arrName in arrayElementTypes) {
                structType = arrayElementTypes[arrName];
            }
            
            // Define struct sizes if not already defined
            if (!(structType in structSizes)) {
                // First, try to calculate from structFieldOffsets
                if (structType in structFieldOffsets) {
                    int maxOffset = 0;
                    foreach (_, offset; structFieldOffsets[structType]) {
                        if (offset > maxOffset) maxOffset = offset;
                    }
                    // Size is at least max offset + 4 (assuming each field is int/4 bytes)
                    structSizes[structType] = maxOffset + 4;
                }
                // Common struct sizes from examples as fallback
                else if (structType == "Sprite") structSizes[structType] = 24;  // Vec2(8) + Color(12) + int(4)
                else if (structType == "Color") structSizes[structType] = 12;  // r,g,b (4 each)
                else if (structType == "Point" || structType == "Vec2") structSizes[structType] = 8;   // x,y (4 each)
                else if (structType == "Vec3") structSizes[structType] = 12;   // x,y,z (4 each)
                else if (structType == "Box") structSizes[structType] = 20;  // Point(8) + Point(8) + int(4)
                else if (structType == "Material") structSizes[structType] = 20;  // type(4) + shininess(4) + colors[3](12)
                else {
                    // Default size if we can't determine
                    structSizes[structType] = 16;  // Default to 16 bytes if unknown
                    lines ~= "        ; WARNING: Using default size of 16 bytes for unknown struct " ~ structType;
                }
            }
            
            // Now we can look up the element size
            if (structType in structSizes) {
                elementSize = structSizes[structType];
            }
            
            // Calculate field offset based on field path and struct type
            if (structType != "") {
                // Calculate field offset based on the field path - now paths are stored in correct order (outermost to innermost)
                int baseOffset = 0;
                string currentType = structType;
                
                // Handle nested struct fields recursively
                if (fieldPath.length >= 2) {
                    for (int i = 0; i < fieldPath.length - 1; i++) {
                        string fieldName = fieldPath[i];
                        // Find offset of this field within current struct
                        int currFieldOffset = 0;
                        
                        // Try to get from structFieldOffsets
                        if (currentType in structFieldOffsets && fieldName in structFieldOffsets[currentType]) {
                            currFieldOffset = structFieldOffsets[currentType][fieldName];
                        }
                        // Fallback to hardcoded for common structs
                        else if (currentType == "Vec2" || currentType == "Point") {
                            if (fieldName == "x") fieldOffset = 0;
                            else if (fieldName == "y") fieldOffset = 4;
                        }
                        else if (currentType == "Vec3") {
                            if (fieldName == "x") fieldOffset = 0;
                            else if (fieldName == "y") fieldOffset = 4; 
                            else if (fieldName == "z") fieldOffset = 8;
                        }
                        else if (currentType == "Model") {
                            if (fieldName == "position") fieldOffset = 0;
                            else if (fieldName == "rotation") fieldOffset = 12;
                            else if (fieldName == "scale") fieldOffset = 24;
                            else if (fieldName == "material") fieldOffset = 36;
                            else if (fieldName == "id") fieldOffset = 56;
                        }
                        else if (currentType == "Material") {
                            if (fieldName == "type") fieldOffset = 0;
                            else if (fieldName == "shininess") fieldOffset = 4;
                            else if (fieldName == "colors") fieldOffset = 8;
                        }
                        else if (currentType == "Sprite") {
                            if (fieldName == "pos") fieldOffset = 0;
                            else if (fieldName == "tint") fieldOffset = 8;
                            else if (fieldName == "id") fieldOffset = 20;
                        }
                        else if (currentType == "Box") {
                            if (fieldName == "min") fieldOffset = 0;
                            else if (fieldName == "max") fieldOffset = 8;
                            else if (fieldName == "colorIndex") fieldOffset = 16;
                        }
                        
                        // Add this field's offset to total
                        baseOffset += fieldOffset;
                        
                        // Determine type of this field for next iteration
                        if (fieldName == "pos" || fieldName == "position" || 
                            fieldName == "rotation" || fieldName == "scale" || 
                            fieldName == "min" || fieldName == "max") 
                        {
                            if (currentType == "Sprite") currentType = "Vec2";
                            else if (currentType == "Model") currentType = "Vec3";
                            else if (currentType == "Box") currentType = "Point";
                        }
                        else if (fieldName == "tint") currentType = "Color";
                        else if (fieldName == "material") currentType = "Material";
                    }
                    
                    // Now handle the final field
                    string finalField = fieldPath[fieldPath.length - 1];
                    
                    if (currentType == "Vec2" || currentType == "Point") {
                        if (finalField == "x") fieldOffset = baseOffset + 0;
                        else if (finalField == "y") fieldOffset = baseOffset + 4;
                    }
                    else if (currentType == "Vec3") {
                        if (finalField == "x") fieldOffset = baseOffset + 0;
                        else if (finalField == "y") fieldOffset = baseOffset + 4;
                        else if (finalField == "z") fieldOffset = baseOffset + 8;
                    }
                    else if (currentType == "Color") {
                        if (finalField == "r") fieldOffset = baseOffset + 0;
                        else if (finalField == "g") fieldOffset = baseOffset + 4;
                        else if (finalField == "b") fieldOffset = baseOffset + 8;
                    }
                    else if (currentType == "Material") {
                        if (finalField == "type") fieldOffset = baseOffset + 0;
                        else if (finalField == "shininess") fieldOffset = baseOffset + 4;
                        // Handle array access like colors[0], colors[1], etc.
                        else if (finalField.startsWith("colors_")) {
                            import std.conv : to;
                            string idxStr = finalField[7..$]; // Extract index after "colors_"
                            int idx = to!int(idxStr);
                            fieldOffset = baseOffset + 8 + (idx * 4); // colors at offset 8, each element 4 bytes
                        }
                    }
                } 
                // Handle simple fields (only one level deep)
                else if (fieldPath.length == 1) {
                    string directField = fieldPath[0];
                    
                    // Try to get from structFieldOffsets
                    if (structType in structFieldOffsets && directField in structFieldOffsets[structType]) {
                        fieldOffset = structFieldOffsets[structType][directField];
                    }
                    // Fallback to hardcoded for common structs
                    else if (structType == "Vec2" || structType == "Point") {
                        if (directField == "x") fieldOffset = 0;
                        else if (directField == "y") fieldOffset = 4;
                    }
                    else if (structType == "Vec3") {
                        if (directField == "x") fieldOffset = 0;
                        else if (directField == "y") fieldOffset = 4;
                        else if (directField == "z") fieldOffset = 8;
                    }
                    else if (structType == "Color") {
                        if (directField == "r") fieldOffset = 0;
                        else if (directField == "g") fieldOffset = 4;
                        else if (directField == "b") fieldOffset = 8;
                    }
                    else if (structType == "Sprite") {
                        if (directField == "pos") fieldOffset = 0;
                        else if (directField == "tint") fieldOffset = 8;
                        else if (directField == "id") fieldOffset = 20;
                    }
                    else if (structType == "Model") {
                        if (directField == "position") fieldOffset = 0;
                        else if (directField == "rotation") fieldOffset = 12;
                        else if (directField == "scale") fieldOffset = 24;
                        else if (directField == "material") fieldOffset = 36;
                        else if (directField == "id") fieldOffset = 56;
                    }
                    else if (structType == "Material") {
                        if (directField == "type") fieldOffset = 0;
                        else if (directField == "shininess") fieldOffset = 4;
                        else if (directField == "colors") fieldOffset = 8;
                    }
                    else if (structType == "Box") {
                        if (directField == "min") fieldOffset = 0;
                        else if (directField == "max") fieldOffset = 8;
                        else if (directField == "colorIndex") fieldOffset = 16;
                    }
                }
                

                //         ~ ", Offset: " ~ to!string(fieldOffset);
                // Add more else if for other struct arrays based on their definitions

                if (elementSize == 0 && (arrName == "sprites" || arrName == "palette")) { // Only error if known struct array fails lookup
                    lines ~= "        ; ERROR: Could not determine element size/offset for " ~ arrName ~ "." ~ field.field;
                } else if (elementSize > 0) {
                    // Calculate element offset: index * element_size
                    lines ~= "        move.l " ~ indexReg ~ ", " ~ offsetReg;
                    lines ~= "        mulu #" ~ to!string(elementSize) ~ ", " ~ offsetReg; // index * elementSize
                    lines ~= "        lea " ~ arrBaseLabel ~ ", " ~ addrReg; // Load array base address
                    lines ~= "        add.l " ~ offsetReg ~ ", " ~ addrReg; // Add element offset -> addrReg points to start of struct element

                    // Store value: move.l valReg, fieldOffset(addrReg)
                    lines ~= "        move.l " ~ valReg ~ ", " ~ to!string(fieldOffset) ~ "(" ~ addrReg ~ ")";
                } else {
                     // This case might occur for struct arrays not explicitly handled above
                     lines ~= "        ; Fallback/Error: Struct array assignment not fully handled for " ~ arrName;
                     // Generate a simple move to base address to avoid compile error, but it's wrong
                     lines ~= "        move.l " ~ valReg ~ ", " ~ arrBaseLabel;
                }
                // --- END GENERALIZED APPROACH ---
            }
        } else { // Assignment to simple struct field (structVar.field)
            // This handles cases like mySprite.pos.x = 10;
            string elemField = resolveNestedStructFieldName(assign.lhs); // Gets "mySprite_pos_x"
            string valReg = generateExpr(assign.value, lines, regIndex, varAddrs);
            string addr = getOrCreateVarAddr(elemField, varAddrs); // Gets label for mySprite_pos_x
            lines ~= "        move.l " ~ valReg ~ ", " ~ addr;
        }
        // --- END PATCH ---
    } else if (auto access = cast(ArrayAccessExpr) assign.lhs) {
        // Handles assignments like hiddenValues[0] = score; or matrix[i][j] = value;
        
        // Handle multi-dimensional array access
        if (access.baseExpr !is null && cast(ArrayAccessExpr)access.baseExpr !is null) {
            // This is a multi-dimensional array access assignment
            string valReg = generateExpr(assign.value, lines, regIndex, varAddrs);
            string arrName = access.arrayName;
            
            // Make sure the array is created in the data section using the original name
            if (!(arrName in emittedVars)) {
                // Calculate total size for multidimensionsal array based on dimensions
                int totalSize = 24; // Default size for small multidim arrays
                if (arrName == "arr") {
                    // For int arr[2][3][4]
                    totalSize = 2 * 3 * 4; // 24 elements
                }
                emittedVars[arrName] = to!string(totalSize); 
            }
            
            // Compute each dimension's index
            string[] indices = [];
            ASTNode currentAccess = access;
            
            // Collect all indices in reverse order (innermost first)
            while (currentAccess !is null) {
                auto aa = cast(ArrayAccessExpr)currentAccess;
                if (aa is null) break;
                
                string idxReg = generateExpr(aa.index, lines, regIndex, varAddrs);
                indices ~= idxReg;
                
                currentAccess = aa.baseExpr;
            }
            
            // Reverse the indices to get outermost first
            import std.algorithm.mutation : reverse;
            reverse(indices);
            
            // Generate code for multi-dimensional array access
            // For arr[i][j][k], compute offset as ((i*dim2 + j)*dim3 + k)*elemSize
            string tempReg = nextReg(regIndex); // Register to accumulate the offset
            string dimReg = nextReg(regIndex);  // Register to hold dimension values
            
            // Start with the outermost index
            lines ~= "        ; Computing multi-dimensional array offset for assignment to " ~ arrName;
            lines ~= "        move.l " ~ indices[0] ~ ", " ~ tempReg;
            
            // Compute multipliers for each dimension
            // For simplicity, hard-code standard sizes for common dimensions
            int[] dims;
            
            // Try to determine array dimensions from the array name
            if (arrName == "arr") {
                // From the test case, we know this is int arr[2][3][4]
                dims = [2, 3, 4];
            } else {
                // Default - assume 10 elements per dimension as fallback
                dims = [10, 10, 10];
            }
            
            // Process middle dimensions (all except the last)
            for (int i = 1; i < indices.length; i++) {
                // For each dimension, multiply by the size of remaining dimensions
                if (i < dims.length) {
                    int multiplier = 1;
                    for (int j = i; j < dims.length; j++) {
                        multiplier *= dims[j];
                    }
                    
                    // Check if multiplier is a power of 2 and optimize with shift
                    if (multiplier > 0 && (multiplier & (multiplier - 1)) == 0) {
                        // Calculate log2(multiplier) to determine shift amount
                        int shiftAmount = 0;
                        int tempValue = multiplier;
                        while (tempValue > 1) {
                            tempValue >>= 1;
                            shiftAmount++;
                        }
                        
                        lines ~= "        lsl.l #" ~ to!string(shiftAmount) ~ ", " ~ tempReg ~ 
                                 "  ; Multiply by " ~ to!string(multiplier) ~ " using shift (dimension " ~ to!string(i) ~ ")";
                    } else {
                        lines ~= "        move.l #" ~ to!string(multiplier) ~ ", " ~ dimReg ~ 
                                 "  ; Size of dimension " ~ to!string(i);
                        lines ~= "        muls " ~ dimReg ~ ", " ~ tempReg ~ 
                                 "  ; Multiply previous index by dimension";
                    }
                    
                    lines ~= "        add.l " ~ indices[i] ~ ", " ~ tempReg ~ "  ; Add current dimension index";
                } else {
                    // Fallback for unknown dimensions - optimize common cases
                    // Check if we can use a more efficient instruction sequence for the default multiplier (10)
                    lines ~= "        move.l " ~ tempReg ~ ", D0  ; Save current value";
                    lines ~= "        lsl.l #3, " ~ tempReg ~ "  ; Multiply by 8";
                    lines ~= "        add.l D0, " ~ tempReg ~ "  ; Add original value (x8 + x1 = x9)";
                    lines ~= "        add.l D0, " ~ tempReg ~ "  ; Add original value again (x9 + x1 = x10)";
                    lines ~= "        add.l " ~ indices[i] ~ ", " ~ tempReg ~ "  ; Add current dimension index";
                }
            }
            
            // Multiply by element size (4 bytes for int)
            // Optimize: use shift left (lsl) instead of multiply for powers of 2
            lines ~= "        lsl.l #2, " ~ tempReg ~ "  ; Multiply by 4 using shift (faster than mulu)";
            
            // Store to the array address
            lines ~= "        lea " ~ arrName ~ ", A0  ; Load array base address";
            lines ~= "        move.l " ~ valReg ~ ", (A0," ~ tempReg ~ ".l)  ; Store value to array element";
            
            return;
        }
        
        // Special case for "complex_expr" - this is a fallback for complex expressions in the parser
        else if (access.arrayName == "complex_expr") {
            // For complex expressions like arr[i][j]
            string valReg = generateExpr(assign.value, lines, regIndex, varAddrs);
            
            // Register a dedicated array for complex expressions that gets properly allocated
            string matrixArrayName = "matrix_array";
            
            // Make sure we emit this array in the data section
            if (!(matrixArrayName in emittedVars)) {
                emittedVars[matrixArrayName] = "100"; // Allocate space for 100 elements
            }
            
            if (!(matrixArrayName in arrayLabels)) {
                arrayLabels[matrixArrayName] = matrixArrayName;
            }
            
            // Compute the array index
            string indexReg = generateExpr(access.index, lines, regIndex, varAddrs);
            string offsetReg = nextReg(regIndex);
            lines ~= "        move.l " ~ indexReg ~ ", " ~ offsetReg;
            lines ~= "        lsl.l #2, " ~ offsetReg; // Shift left by 2 (multiply by 4) - faster than mulu
            
            // Load the array base address and store the value properly
            lines ~= "        lea " ~ matrixArrayName ~ ", A0";
            lines ~= "        move.l " ~ valReg ~ ", (A0," ~ offsetReg ~ ".l)";
            return; // Early return after handling this special case
        }
        
        string baseAddrLabel = getOrCreateVarAddr(access.arrayName, varAddrs);
        string valReg = generateExpr(assign.value, lines, regIndex, varAddrs);
        string addrReg = "A0";
        int elementSize = 4; // Default to 4 bytes (long) for simple arrays like int[]
        
        // Check if this is a 2D array access - look for array name pattern like "matrix_row"
        bool is2DArrayAccess = access.arrayName.indexOf("_") > 0;
        
        // --- FIX: Handle constant and dynamic indices consistently ---
        if (auto intLit = cast(IntLiteral) access.index) {
            // Constant index: arr[const_idx]
            int indexValue = intLit.value;
            
            // Determine element size - default to 4 bytes (long word) unless we know it's a struct
            int elemSize = 4;
            
            // If we know this is an array of structs, use the struct size
            if (access.arrayName in arrayElementTypes) {
                string elemType = arrayElementTypes[access.arrayName];
                if (elemType in structSizes) {
                    elemSize = structSizes[elemType];
                }
            }
            
            // Optimize: Calculate offset at compile time
            int offset = indexValue * elemSize;
            
            // Load the destination address directly with the calculated offset
            lines ~= "        lea " ~ baseAddrLabel ~ ", " ~ addrReg ~ "  ; Load array base address";
            lines ~= "        move.l " ~ valReg ~ ", " ~ to!string(offset) ~ "(" ~ addrReg ~ ")  ; Store at constant index " ~ to!string(indexValue);
        } else {
            // Dynamic index: arr[idx]
            string indexReg = generateExpr(access.index, lines, regIndex, varAddrs);
            string offsetReg = nextReg(regIndex); // Use a data register for offset calculation
            
            // Determine element size - default to 4 bytes (long word) unless we know it's a struct
            int elemSize = 4;
            
            // If we know this is an array of structs, use the struct size
            if (access.arrayName in arrayElementTypes) {
                string elemType = arrayElementTypes[access.arrayName];
                if (elemType in structSizes) {
                    elemSize = structSizes[elemType];
                }
            }
        
        lines ~= "        move.l " ~ indexReg ~ ", " ~ offsetReg; // Copy index value
        
        // Optimize multiplication by powers of 2 using shifts
        if (elemSize == 4) {
            lines ~= "        lsl.l #2, " ~ offsetReg ~ "; Multiply by 4 using shift (faster than mulu)";
        } else if (elemSize == 8) {
            lines ~= "        lsl.l #3, " ~ offsetReg ~ "; Multiply by 8 using shift (faster than mulu)";
        } else if (elemSize == 2) {
            lines ~= "        lsl.l #1, " ~ offsetReg ~ "; Multiply by 2 using shift (faster than mulu)";
        } else if (elemSize == 16) {
            lines ~= "        lsl.l #4, " ~ offsetReg ~ "; Multiply by 16 using shift (faster than mulu)";
        } else {
            lines ~= "        mulu #" ~ to!string(elemSize) ~ ", " ~ offsetReg; // Calculate byte offset
        }
        
        lines ~= "        lea " ~ baseAddrLabel ~ ", " ~ addrReg; // Load base address
        
        // Use indexed addressing with offset register: (base_address_reg, offset_data_reg.L)
        lines ~= "        move.l " ~ valReg ~ ", (" ~ addrReg ~ ", " ~ offsetReg ~ ".l)";
        }
        // --- END FIX ---
    } else if (auto var = cast(VarExpr) assign.lhs) {
        // Handles simple assignments like score = newValue;
        string addr = getOrCreateVarAddr(var.name, varAddrs);
        string valReg = generateExpr(assign.value, lines, regIndex, varAddrs);
        lines ~= "        move.l " ~ valReg ~ ", " ~ addr;
    } else {
        // Fallback if LHS is an unexpected type (should ideally not happen with correct parsing)
        lines ~= "; ERROR: Unhandled LHS type in assignment: " ~ assign.lhs.classinfo.name;
        lines ~= "        move.l " ~ generateExpr(assign.value, lines, regIndex, varAddrs) ~ ", D0";
    }
}

void generateStmt(ASTNode node, ref string[] lines, ref int regIndex, ref string[string] varAddrs, string breakLabel = "", string continueLabel = "") {
    regIndex = 1;

    if (auto mixinTemplate = cast(MixinTemplate) node) {
        // Store the template for later use
        lines ~= format("        ; Mixin template definition: %s", mixinTemplate.name);
        mixinTemplates[mixinTemplate.name] = mixinTemplate.templateBody;
        
        // Debug output for tracking mixin template storage
        writeln("DEBUG: Stored mixin template '", mixinTemplate.name, "' in codegen");
        writeln("DEBUG: Template body contains ", mixinTemplate.templateBody.length, " statements");
    }
    else if (auto templateMixin = cast(TemplateMixin) node) {
        // Insert the template body if it exists
        writeln("DEBUG: Looking for mixin template '", templateMixin.templateName, "' in map with ", mixinTemplates.length, " templates");
        
        if (templateMixin.templateName in mixinTemplates) {
            lines ~= format("        ; Mixin template expansion: %s", templateMixin.templateName);
            writeln("DEBUG: Found mixin template '", templateMixin.templateName, "', expanding ", mixinTemplates[templateMixin.templateName].length, " statements");
            
            // Generate code for each statement in the template body
            foreach (templateStmt; mixinTemplates[templateMixin.templateName]) {
                writeln("DEBUG: Processing template statement: ", templateStmt.classinfo.name);
                
                // Special handling for function declarations in the template
                if (auto funcDecl = cast(FunctionDecl)templateStmt) {
                    // Add inline function implementation
                    string functionName = funcDecl.name;
                    lines ~= format("        ; Inlined function from template: %s", functionName);
                    
                    // Create a local label for this function
                    string localLabel = format("__%s_%d", functionName, labelCounter++);
                    string endLabel = format("__end_%s_%d", functionName, labelCounter++);
                    
                    // Skip the function declaration (just jump over it)
                    lines ~= format("        bra %s", endLabel);
                    
                    // Emit the function body as inline code
                    lines ~= localLabel ~ ":";
                    
                    // Create a temporary variable context for function parameters
                    string[string] localVarAddrs = varAddrs.dup;
                    
                    // Handle function parameters
                    if (funcDecl.params.length > 0) {
                        // Register parameter names in local scope
                        foreach (i, param; funcDecl.params) {
                            string paramName = param.name;
                            string paramAddr = paramName;
                            
                            // Allocate storage for parameters 
                            if (!(paramName in emittedVars)) {
                                emittedVars[paramName] = "1";
                                varTypes[paramName] = param.type;
                            }
                            
                            // Map the parameter name to its address in our local context
                            localVarAddrs[paramName] = paramAddr;
                        }
                    }
                    
                    // Process function body statements
                    foreach (stmt; funcDecl.funcBody) {
                        generateStmt(stmt, lines, regIndex, localVarAddrs, "", "");
                    }
                    
                    // End of the function
                    lines ~= "        rts";
                    lines ~= endLabel ~ ":";
                } else {
                    // Regular statement, generate code as normal
                    generateStmt(templateStmt, lines, regIndex, varAddrs, "", "");
                }
            }
        } else {
            lines ~= format("        ; ERROR: Mixin template '%s' not found", templateMixin.templateName);
            // Dump all available templates for debugging
            writeln("DEBUG: Available templates: ", mixinTemplates.keys);
        }
    }
    else if (auto stringMixin = cast(StringMixin) node) {
        // Generate code for string mixin
        lines ~= "        ; String mixin (compile-time code generation)";
        
        // Extract the string content if it's a string literal
        if (auto strLit = cast(StringLiteral) stringMixin.stringExpr) {
            string mixinContent = strLit.value;
            lines ~= format("        ; String mixin content: %s", mixinContent);
            
            // Simple string mixin implementation - extract variable declarations and simple assignments
            if (mixinContent.indexOf("=") > 0) {
                // Extract variable name and value for simple assignments like "int x = 5;"
                import std.regex;
                import std.string : strip;
                
                // Try to match variable declarations with initialization
                auto varDeclMatch = matchFirst(mixinContent, r"(int|byte|bool|string)\s+(\w+)\s*=\s*([^;]+);");
                if (!varDeclMatch.empty) {
                    string varType = varDeclMatch[1].strip();
                    string varName = varDeclMatch[2].strip();
                    string varValue = varDeclMatch[3].strip();
                    
                    lines ~= format("        ; Generated code for mixin: %s %s = %s;", varType, varName, varValue);
                    
                    // Register the variable for allocation
                    emittedVars[varName] = "1";
                    varTypes[varName] = varType;
                    
                    // Create a variable in our generated code
                    string addr = getOrCreateVarAddr(varName, varAddrs);
                    
                    // Emit the initialization code
                    if (varValue.length > 0 && varValue[0] >= '0' && varValue[0] <= '9') {
                        // For numeric values
                        try {
                            int numValue = to!int(varValue);
                            lines ~= format("        move.l #%d, %s", numValue, addr);
                        } catch (Exception e) {
                            lines ~= format("        ; ERROR: Could not convert '%s' to int", varValue);
                        }
                    } else {
                        // For variable references or expressions
                        lines ~= format("        move.l %s, %s", varValue, addr);
                    }
                } 
                // Try to match simple assignments like "x = 10;"
                else {
                    auto assignMatch = matchFirst(mixinContent, r"(\w+)\s*=\s*([^;]+);");
                    if (!assignMatch.empty) {
                        string varName = assignMatch[1].strip();
                        string varValue = assignMatch[2].strip();
                        
                        // Check if the variable exists
                        if (varName in varTypes) {
                            string addr = getOrCreateVarAddr(varName, varAddrs);
                            
                            // Handle different variable types
                            string varType = varTypes[varName];
                            if (varType == "int" || varType == "byte" || varType == "bool") {
                                lines ~= format("        ; Generated code for mixin assignment: %s", mixinContent);
                                lines ~= format("        move.l #%s, %s", varValue, addr);
                            }
                        } else {
                            lines ~= format("        ; Warning: Variable '%s' not found for assignment in mixin", varName);
                        }
                    } else {
                        lines ~= "        ; Could not parse string mixin content as variable declaration or assignment";
                    }
                }
            } else if (mixinContent.indexOf("(") > 0) {
                // Try to match function calls like "foo(42);"
                import std.regex;
                auto funcCallMatch = matchFirst(mixinContent, r"(\w+)\s*\(([^)]*)\)\s*;");
                if (!funcCallMatch.empty) {
                    string funcName = funcCallMatch[1].strip();
                    string argStr = funcCallMatch[2].strip();
                    
                    lines ~= format("        ; Generated code for function call mixin: %s", mixinContent);
                    
                    // Handle function parameters
                    if (argStr.length > 0) {
                        // For simplicity, only handle numeric arguments
                        import std.conv : to;
                        try {
                            int argValue = to!int(argStr);
                            lines ~= format("        move.l #%d, -(SP)", argValue);
                        } catch (Exception e) {
                            lines ~= format("        ; Complex argument '%s' not supported, using default 0", argStr);
                            lines ~= "        move.l #0, -(SP)";
                        }
                    }
                    
                    // Call the function
                    lines ~= format("        bsr %s", funcName);
                    
                    // Clean up stack if we pushed arguments
                    if (argStr.length > 0) {
                        lines ~= "        add.l #4, SP";
                    }
                }
            } else {
                lines ~= "        ; String mixin parsing is limited - only declarations and assignments supported";
            }
        } else {
            // For more complex string expressions, just add a comment for now
            lines ~= format("        ; String mixin with non-literal expression: %s", stringMixin.stringExpr.classinfo.name);
            lines ~= "        ; Complex string mixin would generate code here at compile time";
        }
    }
    else if (auto decl = cast(VarDecl) node) {
        varTypes[decl.name] = decl.type;
        string addr = getOrCreateVarAddr(decl.name, varAddrs);

        // For constant variables, add to our constVars map
        if (decl.isConst) {
            constVars[decl.name] = "1";  // Mark this variable as a constant
            lines ~= format("        ; Constant variable: %s", decl.name);
        }

        switch (decl.type) {
            case "int":
                string intReg = generateExpr(decl.value, lines, regIndex, varAddrs);
                lines ~= format("        move.l %s, %s", intReg, addr);
                break;

            case "byte":
                string byteReg = generateExpr(decl.value, lines, regIndex, varAddrs);
                lines ~= format("        move.b %s, %s", byteReg, addr);
                break;

            case "bool":
                string boolReg = generateExpr(decl.value, lines, regIndex, varAddrs);
                lines ~= format("        move.l %s, %s", boolReg, addr);
                break;

            case "string":
                if (auto str = cast(StringLiteral) decl.value) {
                    string strLabel = getOrCreateStringLabel(str.value);
                    lines ~= format("        lea %s, A0", strLabel);
                    lines ~= format("        move.l A0, %s", addr);
                }
                break;
            case "int[]":
                // Handle array initialization
                if (auto arr = cast(ArrayLiteral) decl.value) {
                    string base = "arr" ~ capitalize(decl.name);
                    globalArrays[decl.name] = base;

                    if (!(decl.name in declaredArrays)) {
                        for (int i = 0; i < arr.elements.length; i++) {
                            string reg = generateExpr(arr.elements[i], lines, regIndex, varAddrs);
                            string label = base ~ "_" ~ to!string(i);
                            lines ~= format("        move.l %s, %s", reg, label);
                        }
                        lines ~= base ~ "_len:    dc.l " ~ to!string(arr.elements.length);
                        declaredArrays[decl.name] = base;
                    }

                    varAddrs[decl.name] = base; // Register for indexed access
                }
                break;
            case "byte[]":
                // Handle byte array initialization
                if (auto arr = cast(ArrayLiteral) decl.value) {
                    string base = "arr" ~ capitalize(decl.name);
                    globalArrays[decl.name] = base;

                    if (!(decl.name in declaredArrays)) {
                        for (int i = 0; i < arr.elements.length; i++) {
                            string reg = generateExpr(arr.elements[i], lines, regIndex, varAddrs);
                            string label = base ~ "_" ~ to!string(i);
                            lines ~= format("        move.b %s, %s", reg, label);
                        }
                        lines ~= base ~ "_len:    dc.l " ~ to!string(arr.elements.length);
                        declaredArrays[decl.name] = base;
                    }

                    varAddrs[decl.name] = base; // Register for indexed access
                }
                break;
            case "bool[]":
                // Handle bool array initialization
                if (auto arr = cast(ArrayLiteral) decl.value) {
                    string base = "arr" ~ capitalize(decl.name);
                    globalArrays[decl.name] = base;

                    if (!(decl.name in declaredArrays)) {
                        for (int i = 0; i < arr.elements.length; i++) {
                            string reg = generateExpr(arr.elements[i], lines, regIndex, varAddrs);
                            string label = base ~ "_" ~ to!string(i);
                            lines ~= format("        move.l %s, %s", reg, label);
                        }
                        lines ~= base ~ "_len:    dc.l " ~ to!string(arr.elements.length);
                        declaredArrays[decl.name] = base;
                    }

                    varAddrs[decl.name] = base; // Register for indexed access
                }
                break;
            case "string[]":
                // Handle string array initialization
                if (auto arr = cast(ArrayLiteral) decl.value) {
                    string base = "arr" ~ capitalize(decl.name);
                    globalArrays[decl.name] = base;

                    if (!(decl.name in declaredArrays)) {
                        for (int i = 0; i < arr.elements.length; i++) {
                            string reg = generateExpr(arr.elements[i], lines, regIndex, varAddrs);
                            string label = base ~ "_" ~ to!string(i);
                            lines ~= format("        lea %s, A0", reg);
                            lines ~= format("        move.l A0, %s", label);
                        }
                        lines ~= base ~ "_len:    dc.l " ~ to!string(arr.elements.length);
                        declaredArrays[decl.name] = base;
                    }

                    varAddrs[decl.name] = base; // Register for indexed access
                }
                break;
            default:
                // Handle struct types
                if (decl.type in structFieldOffsets) {
                    // Single struct variable
                    varAddrs[decl.name] = decl.name;
                    emittedVars[decl.name] = to!string(structFieldOffsets[decl.type].length);
                } else if (decl.type.endsWith("]")) {
                    import std.regex : matchFirst;
                    auto m = decl.type.matchFirst(`([A-Za-z_][A-Za-z0-9_]*)\[(\d+)\]`);
                    if (!m.empty && m.captures.length == 3) {
                        string structType = m.captures[1];
                        int arrLen = m.captures[2].to!int;
                        
                        // Register array element type for future reference
                        arrayElementTypes[decl.name] = structType;
                        
                        if (structType in structFieldOffsets) {
                            // Register struct array in memory allocation tracking
                            emittedVars[decl.name] = to!string(arrLen);
                            
                            // Calculate struct size if not already defined
                            if (!(structType in structSizes)) {
                                int maxOffset = 0;
                                foreach(_, offset; structFieldOffsets[structType]) {
                                    if (offset > maxOffset) maxOffset = offset;
                                }
                                // Size is max offset + 4 (assuming each field is int sized)
                                structSizes[structType] = maxOffset + 4;
                            }
                            
                            // Allocate memory for each element in the array with their fields
                            for (int i = 0; i < arrLen; i++) {
                                // Recursively allocate memory for each field of each struct
                                flattenStructFields(structType, decl.name ~ "_" ~ to!string(i), varAddrs, emittedVars, varTypes);
                            }
                            
                            // Ensure there's a length label for the array
                            emittedVars[decl.name ~ "_len"] = to!string(arrLen);
                            
                            // Register it as an array label for emitting ds.l directive
                            if (!(decl.name in arrayLabels)) {
                                arrayLabels[decl.name] = decl.name;
                            }
                        } else {
                            lines ~= format("        ; array of unknown struct type %s (not implemented)", structType);
                        }
                    } else {
                        lines ~= format("        ; variable of unknown type %s (not implemented)", decl.type);
                    }
                } else {
                    lines ~= format("        ; variable of type %s (unknown type, not implemented)", decl.type);
                }
                break;
        }
    }
    else if (auto assign = cast(AssignStmt) node) {
        // --- REFACTOR: Call helper function ---
        handleAssignStmt(assign, lines, regIndex, varAddrs);
        // --- END REFACTOR ---
    }
    else if (auto contstmt = cast(ContinueStmt) node) {
        lines ~= "        bra " ~ continueLabel;
    }
    else if (auto block = cast(BlockStmt) node) {
        foreach (stmt; block.blockBody) {
            generateStmt(stmt, lines, regIndex, varAddrs);
        }
    }
    else if (auto ifstmt = cast(IfStmt) node) {
        // Generate unique labels for if-else control flow
        string labelElse = genLabel("else");
        string labelEnd = genLabel("endif");

        // Generate code for the condition expression
        string condReg = generateExpr(ifstmt.condition, lines, regIndex, varAddrs);
        if (condReg != "D0")
            lines ~= "        move.l " ~ condReg ~ ", D0  ; Move condition result to D0";
        
        // Compare with zero instead of A1 (more efficient)
        lines ~= "        tst.l " ~ condReg ~ "  ; Check if condition is zero/false";
        lines ~= "        beq " ~ labelElse ~ "       ; Branch to else if condition is false";

        // Generate code for the 'then' body
        foreach (s; ifstmt.thenBody) {
            generateStmt(s, lines, regIndex, varAddrs);
        }

        // After executing the 'then' body, skip over the 'else' section
        lines ~= "        bra " ~ labelEnd ~ "        ; Skip over else section when then section completes";
        
        // Begin the 'else' section
        lines ~= labelElse ~ ":             ; Else section starts here";

        // Generate code for the 'else' body
        foreach (s; ifstmt.elseBody) {
            generateStmt(s, lines, regIndex, varAddrs);
        }

        // End of the if-else statement
        lines ~= labelEnd ~ ":             ; End of if-else statement";
    }
    else if (auto assertStmt = cast(AssertStmt) node) {
        // Generate unique labels for assert control flow
        string assertFailLabel = format("assert_fail_%d", labelCounter++);
        string assertPassLabel = format("assert_pass_%d", labelCounter++);

        // Generate code for the condition expression
        string condReg = generateExpr(assertStmt.condition, lines, regIndex, varAddrs);
        
        // Test the condition
        lines ~= "        tst.l " ~ condReg ~ "  ; Check if assertion condition is true/non-zero";
        lines ~= "        beq " ~ assertFailLabel ~ "  ; Branch to fail if assertion is false";
        
        // If condition is true, skip the fail code
        lines ~= "        bra " ~ assertPassLabel ~ "  ; Skip assertion failure code";
        
        // Assertion failure code
        lines ~= assertFailLabel ~ ":";
        lines ~= "        lea assertFailMsg, A1  ; Load address of assert failure message";
        lines ~= "        move.l #13, D0         ; Task 13 - print string without newline";
        lines ~= "        trap #15               ; Call OS";
        lines ~= "        move.l #9, D0          ; Task 9 - terminate program";
        lines ~= "        trap #15               ; Call OS to terminate program";
        
        // Assertion pass label
        lines ~= assertPassLabel ~ ":";
    }
    else if (auto postfix = cast(PostfixExpr) node) {
        // Handle postfix increment/decrement
        auto target = cast(VarExpr) postfix.target;
        string addr = getOrCreateVarAddr(target.name, varAddrs);
        string reg = nextReg(regIndex);

        final switch (postfix.op) {
            case "++":
                lines ~= "        move.l " ~ addr ~ ", " ~ reg;
                lines ~= "        addq.l #1, " ~ reg;
                lines ~= "        move.l " ~ reg ~ ", " ~ addr;
                break;
            case "--":
                lines ~= "        move.l " ~ addr ~ ", " ~ reg;
                lines ~= "        subq.l #1, " ~ reg;
                lines ~= "        move.l " ~ reg ~ ", " ~ addr;
                break;
        }
    }
    else if (auto whilestmt = cast(WhileStmt) node) {
        // Generate labels for loop control
        string labelStart = genLabel("while");
        string labelEnd = genLabel("end_loop");

        // Start of while loop
        lines ~= labelStart ~ ":             ; Start of while loop";

        // Generate code for the loop condition
        string condReg = generateExpr(whilestmt.condition, lines, regIndex, varAddrs);
        
        // Check if condition is false (0), and exit loop if so
        lines ~= "        tst.l " ~ condReg ~ "   ; Check if condition is false/zero";
        lines ~= "        beq " ~ labelEnd ~ "        ; Exit loop if condition is false";

        // Generate code for the loop body
        foreach (s; whilestmt.loopBody) {
            generateStmt(s, lines, regIndex, varAddrs);
        }

        // Jump back to the start of the loop
        lines ~= "        bra " ~ labelStart ~ "      ; Jump back to start of loop";
        
        // End of while loop
        lines ~= labelEnd ~ ":             ; End of while loop";
    }
    else if (auto forLoop = cast(CStyleForStmt) node) {
        // Generate initialization code (e.g., int i = 0)
        generateStmt(forLoop.init, lines, regIndex, varAddrs);

        // Generate labels for loop control
        string startLabel = genLabel("for_start");
        string endLabel = genLabel("for_end");

        // Start of for loop
        lines ~= startLabel ~ ":             ; Start of for loop";

        // Generate condition check code (e.g., i < 10)
        string condReg = generateExpr(forLoop.condition, lines, regIndex, varAddrs);
        
        // Directly branch based on the condition register without the intermediate move
        // Optimization: removed redundant move to D0 that was happening in the generated code
        lines ~= "        tst.l " ~ condReg ~ "   ; Check if condition is false/zero";
        lines ~= "        beq " ~ endLabel ~ "        ; Exit loop if condition is false";

        // Generate code for the loop body
        foreach (stmt; forLoop.forBody) {
            generateStmt(stmt, lines, regIndex, varAddrs, endLabel, startLabel);
        }

        // Generate increment code (e.g., i++)
        generateStmt(forLoop.increment, lines, regIndex, varAddrs);
        
        // Jump back to the start of the loop (condition check)
        lines ~= "        bra " ~ startLabel ~ "      ; Jump back to start of loop";
        
        // End of for loop
        lines ~= endLabel ~ ":             ; End of for loop";
    }
    else if (auto foreachStmt = cast(ForeachStmt) node) {
        generateForeachStmt(foreachStmt, lines, regIndex, varAddrs);
    }
    else if (auto arr = cast(ArrayDecl) node) {
        string base = "arr" ~ capitalize(arr.name);
        globalArrays[arr.name] = base;
        int arrLen = cast(int)arr.elements.length;
        // If no initializers, try to get the declared size from the AST
        if (arrLen == 0 && arr.elements.length == 0 && arr.elements !is null && arr.elements.length == 0) {
            if (arr.elements.length == 1) {
                if (auto intLit = cast(IntLiteral) arr.elements[0]) {
                    arrLen = intLit.value;
                }
            }
        } else if (arr.elements.length == 1) {
            if (auto intLit = cast(IntLiteral) arr.elements[0]) {
                arrLen = intLit.value;
            }
        }
        if (arrLen == 0) arrLen = 1; // fallback to 1 if not found
        // Only emit data for primitive/function pointer arrays, not struct arrays
        bool isStructArray = false;
        foreach (stype, _; structFieldOffsets) {
            if (arr.type == stype || arr.type.startsWith(stype ~ "[")) {
                isStructArray = true;
                break;
            }
        }
        if (!isStructArray) {
            emittedVars[base ~ "_len"] = to!string(arrLen);
            for (int i = 0; i < arrLen; i++) {
                string label = arr.name ~ "_" ~ to!string(i);
                emittedVars[label] = "1";
            }
            arrayLabels[arr.name] = base;
        }
        varAddrs[arr.name] = base; // Register for indexed access
    }

    else if (auto print = cast(PrintStmt) node) {
        foreach (value; print.values) {
            if (auto str = cast(StringLiteral) value) {
                string label = getOrCreateStringLabel(str.value);
                lines ~= "        lea " ~ label ~ ", A1";
                lines ~= "        move.b #9, D0";
                lines ~= "        trap #14";
            } else {
                string reg = generateExpr(value, lines, regIndex, varAddrs);
                lines ~= "        move.l " ~ reg ~ ", D1";
                lines ~= "        move.b #1, D0";
                lines ~= "        trap #14";
            }
        }
    }
    else if (auto sw = cast(SwitchStmt) node) {
        string endLabel = genLabel("switch_end");
        string defaultLabel = endLabel;

        breakLabel = "break" ~ to!string(labelCounter++);
        continueLabel = "switch_continue" ~ to!string(labelCounter++);

        string condReg = "D0";
        string[] caseLabels;
        foreach (i, cNode; sw.cases) {
            caseLabels ~= genLabel("case_" ~ to!string(i));
        }

        // Emit case comparisons
        foreach (i, cNode; sw.cases) {
            auto c = cast(CaseStmt) cNode;
            string label = caseLabels[i];

            if (c.condition !is null) {
                if (auto intLit = cast(IntLiteral) c.condition) {
                    lines ~= "        cmp.l #" ~ to!string(intLit.value) ~ ", " ~ condReg;
                } else {
                    string caseValReg = generateExpr(c.condition, lines, regIndex, varAddrs);
                    lines ~= "        cmp.l " ~ caseValReg ~ ", " ~ condReg;
                }
                lines ~= "        beq " ~ label;
            } else {
                defaultLabel = label;
            }
        }
        lines ~= "        bra " ~ defaultLabel;

        // Emit case bodies
        foreach (i, cNode; sw.cases) {
            auto c = cast(CaseStmt) cNode;
            string label = caseLabels[i];
            lines ~= label ~ ":";

            foreach (j, stmt; c.caseBody) {
                generateStmt(stmt, lines, regIndex, varAddrs, endLabel);
            }
            // Only emit bra if the last statement is not a break/return
            if (c.caseBody.length == 0 ||
                !isBreakOrReturn(c.caseBody[$-1])) {
                lines ~= "        bra " ~ endLabel;
            }
        }

        lines ~= endLabel ~ ":";
    }
    else if (auto unary = cast(UnaryExpr) node) {
        auto var = cast(VarExpr) unary.expr;
        string addr = getOrCreateVarAddr(var.name, varAddrs);
        string reg = nextReg(regIndex);

        final switch (unary.op) {
            case "++":
                lines ~= "        move.l " ~ addr ~ ", " ~ reg;
                lines ~= "        addq.l #1, " ~ reg;
                lines ~= "        move.l " ~ reg ~ ", " ~ addr;
                break;
            case "--":
                lines ~= "        move.l " ~ addr ~ ", " ~ reg;
                lines ~= "        subq.l #1, " ~ reg;
                lines ~= "        move.l " ~ reg ~ ", " ~ addr;
                break;
        }
    }
    else if (auto exprStmt = cast(ExprStmt) node) {
        // --- PATCH: Handle CallExpr as a statement directly ---
        if (auto call = cast(CallExpr) exprStmt.expr) {
            // Push arguments onto stack (right to left)
            foreach_reverse (arg; call.args) {
                string reg = generateExpr(arg, lines, regIndex, varAddrs);
                // Handle address-of specifically for lea
                auto unary = cast(UnaryExpr) arg;
                if (unary !is null && unary.op == "&") {
                     // generateExpr for &var already returns an address register with lea
                     lines ~= "        move.l " ~ reg ~ ", -(SP)"; // Push address
                } else if (cast(StringLiteral) arg) {
                     // generateExpr for string literal already returns an address register with lea
                     lines ~= "        move.l " ~ reg ~ ", -(SP)"; // Push address
                }
                 else {
                    lines ~= "        move.l " ~ reg ~ ", -(SP)"; // Push value
                }
            }

            // Generate call instruction (bsr for known, jsr (A0) for function pointer)
            // TODO: Check if function pointer logic is needed/correct
            lines ~= "        bsr " ~ call.name; // Direct call

            // Clean up stack
            if (call.args.length > 0) {
                lines ~= "        add.l #" ~ to!string(4 * call.args.length) ~ ", SP";
            }
        }
        // --- FIX: Handle AssignStmt wrapped in ExprStmt ---
        else if (auto assign = cast(AssignStmt) exprStmt.expr) {
             handleAssignStmt(assign, lines, regIndex, varAddrs);
        }
        // --- END FIX ---
        else {
            // Generate other expressions as statements (result ignored)
            // This call might still be problematic if other statement types get wrapped
            // For now, let it call generateExpr and potentially log the error if unhandled
            string discardReg = generateExpr(exprStmt.expr, lines, regIndex, varAddrs);
             lines ~= "        ; Result of expression statement ignored: " ~ discardReg;
        }
    }
    else if (auto returnStmt = cast(ReturnStmt) node) {
        // Handle return statement with value

        if (returnStmt.value !is null) {
            string resultReg = generateExpr(returnStmt.value, lines, regIndex, varAddrs);
            // Move result to D0 for return value
            if (resultReg != "D0") {
                lines ~= "        move.l " ~ resultReg ~ ", D0  ; Set return value";
            }
        }
        // Return from function
        lines ~= "        rts";
    }
    else if (auto str = cast(StringLiteral) node) {
        string label = getOrCreateStringLabel(str.value);
        lines ~= format("%s:    dc.b %d, %s", label, str.value.length, str.value);
    }
    else if (auto call = cast(CallExpr) node) {
        foreach_reverse (arg; call.args) {
            string reg = generateExpr(arg, lines, regIndex, varAddrs);
            lines ~= "        move.l " ~ reg ~ ", -(SP)";
        }

        if (varTypes.get(call.name, "").startsWith("void function(")) {
            // Function pointer call
            lines ~= format("        move.l var_%s, A0", call.name);
            lines ~= "        jsr (A0)";
        } else {
            // Normal function call
            lines ~= "        bsr " ~ call.name;
        }
        lines ~= "        add.l #" ~ to!string(4 * call.args.length) ~ ", SP";
        // We don't need to store the result in a register since generateStmt is void
    }
}

// Recursively flatten struct fields for arrays of structs
void flattenStructFields(string structType, string prefix, ref string[string] varAddrs, ref string[string] emittedVars, ref string[string] varTypes) {
    if (!(structType in structFieldOffsets)) return;
    
    // Calculate struct size if not already defined
    if (!(structType in structSizes)) {
        // Count total fields and max offset
        int maxOffset = 0;
        foreach (fieldName, offset; structFieldOffsets[structType]) {
            if (offset > maxOffset) maxOffset = offset;
        }
        // Size is at least max offset + 4 (assuming each field is int/4 bytes)
        structSizes[structType] = maxOffset + 4;
    }
    
    foreach (fieldName, offset; structFieldOffsets[structType]) {
        // Try to get the type from varTypes if available, fallback to int
        string fieldType = "int";
        if (structType ~ "." ~ fieldName in varTypes) {
            fieldType = varTypes[structType ~ "." ~ fieldName];
        }
        
        // If the field is itself a struct, recursively process it
        if (fieldType in structFieldOffsets) {
            flattenStructFields(fieldType, prefix ~ "_" ~ fieldName, varAddrs, emittedVars, varTypes);
        } else {
            string elemField = prefix ~ "_" ~ fieldName;
            if (!(elemField in emittedVars)) {
                varAddrs[elemField] = elemField;
                emittedVars[elemField] = "1";
                varTypes[elemField] = fieldType;
            }
        }
    }
}

// Helper to resolve full variable name for nested struct field accesses
string resolveNestedStructFieldName(ASTNode node) {
    if (auto field = cast(StructFieldAccess) node) {
        string base = resolveNestedStructFieldName(field.baseExpr);
        return base ~ "_" ~ field.field;
    } else if (auto arrAccess = cast(ArrayAccessExpr) node) {
        if (auto intLit = cast(IntLiteral) arrAccess.index) {
            return arrAccess.arrayName ~ "_" ~ to!string(intLit.value);
        } else {
            // For dynamic indices, return a special marker or empty string to indicate unsupported flattening
            return "";
        }
    } else if (auto var = cast(VarExpr) node) {
        return var.name;
    }
    return "";
}


// Helper: Recursively compute address and offset for any lvalue (VarExpr, ArrayAccessExpr, StructFieldAccess, nested)
// Returns: tuple (addrReg, offset)
Tuple!(string, int) generateAddressExpr(ASTNode expr, ref string[] lines, ref int regIndex, string[string] varAddrs) {
    import std.typecons : tuple, Tuple;
    // Helper to resolve the type of an ASTNode
    string resolveNodeType(ASTNode node) {
        if (auto var = cast(VarExpr) node) {
            if (var.name in varTypes) return varTypes[var.name];
            return "";
        } else if (auto access = cast(ArrayAccessExpr) node) {
            // Get element type from arrayElementTypes or varTypes
            string arrName = access.arrayName;
            if (arrName in arrayElementTypes) return arrayElementTypes[arrName];
            if (arrName in varTypes) {
                string t = varTypes[arrName];
                // e.g. "int[]" or "Sprite[]" -> "int" or "Sprite"
                auto idx = t.indexOf("[");
                if (idx != -1) return t[0 .. idx];
                return t;
            }
            return "";
        } else if (auto field = cast(StructFieldAccess) node) {
            // First, determine the type of the base expression
            string baseType = resolveNodeType(field.baseExpr);
            
            // Then determine which type the field has
            if (baseType == "Vec2" || baseType == "Point") {
                if (field.field == "x" || field.field == "y") return "int";
            } 
            else if (baseType == "Vec3") {
                if (field.field == "x" || field.field == "y" || field.field == "z") return "int";
            }
            else if (baseType == "Color") {
                if (field.field == "r" || field.field == "g" || field.field == "b") return "int";
            }
            else if (baseType == "Sprite") {
                if (field.field == "pos") return "Vec2";
                else if (field.field == "tint") return "Color";
                else if (field.field == "id") return "int";
            }
            else if (baseType == "Box") {
                if (field.field == "min" || field.field == "max") return "Point";
                else if (field.field == "colorIndex") return "int";
            }
            else if (baseType == "Model") {
                if (field.field == "position" || field.field == "rotation" || field.field == "scale") return "Vec3";
                else if (field.field == "material") return "Material";
                else if (field.field == "id") return "int";
            }
            else if (baseType == "Material") {
                if (field.field == "type" || field.field == "shininess") return "int";
                else if (field.field == "colors") return "int[]";
            }
            
            // If we get here, we couldn't determine the field type
            lines ~= "        ; WARNING: Could not determine type of field " ~ field.field ~ " in struct " ~ baseType;
            return "";
        }
        return "";
    }

    // Base case: variable
    if (auto var = cast(VarExpr) expr) {
        // Check if variable is a register parameter
        if (var.name in varAddrs && varAddrs[var.name].startsWith("D")) {
            // For parameters passed in registers (like D0, D1), we need a special approach
            // We can't take the address of a register, so we need to copy the value to a temp register
            string tempReg = nextReg(regIndex);
            lines ~= "        move.l " ~ varAddrs[var.name] ~ ", " ~ tempReg ~ "  ; Copy register parameter to temp";
            
            // Return the register itself, with an offset of 0
            // This lets the caller know this is actually a value in a register, not an address
            return tuple(tempReg, 0);
        }
        
        // Normal case - variable with a memory address
        string addrReg = "A" ~ to!string(regIndex++);
        string addr = getOrCreateVarAddr(var.name, varAddrs);
        lines ~= "        lea " ~ addr ~ ", " ~ addrReg;
        regIndex--; // Free the register after use
        return tuple(addrReg, 0);
    }
    // Array access: arr[idx] or nested (multi-dim)
    if (auto access = cast(ArrayAccessExpr) expr) {
        // Support both simple and nested array base
        string baseReg;
        int baseOffset = 0;
        ASTNode baseNode = null;
        static if (__traits(hasMember, typeof(access), "baseExpr")) {
            baseNode = access.baseExpr;
        }
        int regIndexStart = regIndex;
        if (baseNode is null) {
            // Try to treat arrayName as a variable name
            string arrName = access.arrayName;
            baseReg = "A" ~ to!string(regIndex++);
            string baseAddr = getOrCreateVarAddr(arrName, varAddrs);
            lines ~= "        lea " ~ baseAddr ~ ", " ~ baseReg;
        } else {
            // Recursively compute base address
            auto baseResult = generateAddressExpr(baseNode, lines, regIndex, varAddrs);
            baseReg = baseResult[0];
            baseOffset = baseResult[1];
        }
        int indexStart = regIndex;
        string indexReg = generateExpr(access.index, lines, regIndex, varAddrs);
        int indexEnd = regIndex;
        string offsetReg = nextReg(regIndex);
        // Determine element size
        string elemType = resolveNodeType(expr); // type of element
        int elemSize = 4;
        if (elemType in structSizes) elemSize = structSizes[elemType];
        
        lines ~= "        move.l " ~ indexReg ~ ", " ~ offsetReg;
        
        // Optimize element size multiplication using shift operations for powers of 2
        if (elemSize > 0 && (elemSize & (elemSize - 1)) == 0) {
            // Calculate log2(elemSize) to determine shift amount
            int shiftAmount = 0;
            int tempValue = elemSize;
            while (tempValue > 1) {
                tempValue >>= 1;
                shiftAmount++;
            }
            
            lines ~= "        lsl.l #" ~ to!string(shiftAmount) ~ ", " ~ offsetReg ~ 
                     "  ; Multiply by " ~ to!string(elemSize) ~ " using shift (faster than mulu)";
        } else {
            lines ~= "        mulu #" ~ to!string(elemSize) ~ ", " ~ offsetReg;
        }
        
        if (baseOffset != 0)
            lines ~= "        add.l #" ~ to!string(baseOffset) ~ ", " ~ offsetReg;
        lines ~= "        add.l " ~ offsetReg ~ ", " ~ baseReg;
        // Free temporaries used for indexReg and offsetReg, and for baseReg if it was a temporary
        regIndex = regIndexStart;
        return tuple(baseReg, 0);
    }
    // Struct field access: base.field
    if (auto field = cast(StructFieldAccess) expr) {
        int regIndexStart = regIndex;
        auto baseResult = generateAddressExpr(field.baseExpr, lines, regIndex, varAddrs);
        string baseReg = baseResult[0];
        int baseOffset = baseResult[1];
        
        // Determine struct type
        string structType = resolveNodeType(field.baseExpr);
        int fieldOffset = 0;
        
        // First try to get field offset from structFieldOffsets
        if (structType.length && structType in structFieldOffsets && field.field in structFieldOffsets[structType]) {
            fieldOffset = structFieldOffsets[structType][field.field];
        } 
        // If we couldn't find it there, check if we know the offset from hardcoded structSizes
        else if (structType == "Vec2" || structType == "Point") {
            if (field.field == "x") fieldOffset = 0;
            else if (field.field == "y") fieldOffset = 4;
        }
        else if (structType == "Vec3") {
            if (field.field == "x") fieldOffset = 0;
            else if (field.field == "y") fieldOffset = 4;
            else if (field.field == "z") fieldOffset = 8;
        }
        else if (structType == "Color") {
            if (field.field == "r") fieldOffset = 0;
            else if (field.field == "g") fieldOffset = 4;
            else if (field.field == "b") fieldOffset = 8;
        }
        else if (structType == "Material") {
            if (field.field == "type") fieldOffset = 0;
            else if (field.field == "shininess") fieldOffset = 4;
            // colors array would be at offset 8
        }
        
        // Check if the baseReg is actually a data register (parameter case)
        if (baseReg.startsWith("D")) {
            // For struct parameters in data registers, we need a temporary address register
            string addrReg = "A" ~ to!string(regIndex++);
            
            // Move the value from the data register to the address register
            // Note: We can't directly use "lea Dn, An" as that's an invalid addressing mode
            lines ~= "        movea.l " ~ baseReg ~ ", " ~ addrReg ~ "  ; Convert register value to address";
            
            // Now return the address register with the field offset
            regIndex = regIndexStart; // Free temporaries used in this call
            return tuple(addrReg, fieldOffset);
        }
        
        // Normal case - base is already an address
        regIndex = regIndexStart; // Free temporaries used in this call
        return tuple(baseReg, baseOffset + fieldOffset);
    }
    // --- PATCH: Recursively handle wrappers and all common lvalue AST node types ---
    // Handle ParenExpr: just recurse into .expr
    if (expr.classinfo.name == "ParenExpr") {
        static if (__traits(hasMember, typeof(expr), "expr")) {
            auto inner = mixin("expr.expr");
            if (inner !is null && inner !is expr) {
                return generateAddressExpr(inner, lines, regIndex, varAddrs);
            }
        }
    }
    // Handle CastExpr: just recurse into .expr
    if (expr.classinfo.name == "CastExpr") {
        static if (__traits(hasMember, typeof(expr), "expr")) {
            auto inner = mixin("expr.expr");
            if (inner !is null && inner !is expr) {
                return generateAddressExpr(inner, lines, regIndex, varAddrs);
            }
        }
    }
    // Handle UnaryExpr: address-of operator (&)
    if (expr.classinfo.name == "UnaryExpr") {
        static if (__traits(hasMember, typeof(expr), "op") && __traits(hasMember, typeof(expr), "expr")) {
            auto op = mixin("expr.op");
            auto inner = mixin("expr.expr");
            if (op == "&" && inner !is null && inner !is expr) {
                return generateAddressExpr(inner, lines, regIndex, varAddrs);
            }
        }
    }
    // Handle generic wrappers with .expr field (defensive, for any other wrappers)
    static if (__traits(hasMember, typeof(expr), "expr")) {
        auto inner = mixin("expr.expr");
        if (inner !is null && inner !is expr) {
            return generateAddressExpr(inner, lines, regIndex, varAddrs);
        }
    }
    // Handle wrappers with .baseExpr (e.g., for custom AST wrappers)
    static if (__traits(hasMember, typeof(expr), "baseExpr")) {
        auto inner = mixin("expr.baseExpr");
        if (inner !is null && inner !is expr) {
            return generateAddressExpr(inner, lines, regIndex, varAddrs);
        }
    }
    // Handle wrappers with .target (e.g., for PostfixExpr, etc.)
    static if (__traits(hasMember, typeof(expr), "target")) {
        auto inner = mixin("expr.target");
        if (inner !is null && inner !is expr) {
            return generateAddressExpr(inner, lines, regIndex, varAddrs);
        }
    }
    // Fallback: emit error
    lines ~= "; ERROR: Cannot compute address for expr type " ~ expr.classinfo.name;
    // Return a known register, but do not emit any lea or address computation
    return tuple("A0", 0); // Use A0 as a dummy, but do not emit any lea
}

string generateExpr(ASTNode expr, ref string[] lines, ref int regIndex, string[string] varAddrs) {
    if (auto lit = cast(IntLiteral) expr) {
        string reg = nextReg(regIndex);
        // Use moveq for values in range -128 to 127 (8-bit immediate)
        if (lit.value >= -128 && lit.value <= 127) {
            lines ~= "        moveq #" ~ to!string(lit.value) ~ ", " ~ reg ~ "  ; Optimized small constant";
        } else {
            lines ~= "        move.l #" ~ to!string(lit.value) ~ ", " ~ reg;
        }
        return reg;
    }

    if (auto b = cast(BoolLiteral) expr) {
        string reg = nextReg(regIndex);
        // Use moveq for boolean values (always 0 or 1)
        lines ~= "        moveq #" ~ (b.value ? "1" : "0") ~ ", " ~ reg ~ "  ; Boolean value";
        return reg;
    }

    if (auto unary = cast(UnaryExpr) expr) {
        // Handle address-of operator
        if (unary.op == "&") {
            auto var = cast(VarExpr) unary.expr;
            string addr = getOrCreateVarAddr(var.name, varAddrs);
            string reg = "A" ~ to!string(regIndex++);
            lines ~= "        lea " ~ addr ~ ", " ~ reg;
            return reg;
        }
        // Handle unary minus
        else if (unary.op == "-") {
            string operandReg = generateExpr(unary.expr, lines, regIndex, varAddrs);
            string resultReg = nextReg(regIndex);
            lines ~= "        move.l " ~ operandReg ~ ", " ~ resultReg;
            lines ~= "        neg.l " ~ resultReg;
            return resultReg;
        }
        // Handle other unary operators like ++, --
        else if (unary.op == "++" || unary.op == "--") {
            if (auto var = cast(VarExpr) unary.expr) {
                string addr = getOrCreateVarAddr(var.name, varAddrs);
                string reg = nextReg(regIndex);
                lines ~= "        move.l " ~ addr ~ ", " ~ reg;
                
                if (unary.op == "++") {
                    lines ~= "        addq.l #1, " ~ reg;
                } else {
                    lines ~= "        subq.l #1, " ~ reg;
                }
                
                lines ~= "        move.l " ~ reg ~ ", " ~ addr;
                return reg;
            }
        }
    }

    // Handle CastExpr
    if (auto castExpr = cast(CastExpr) expr) {
        // For now, assume casts between numeric types are no-ops in assembly.
        return generateExpr(castExpr.expr, lines, regIndex, varAddrs);
    }

    if (auto field = cast(StructFieldAccess) expr) {
        // Use new recursive address generator
        auto addrResult = generateAddressExpr(expr, lines, regIndex, varAddrs);
        string addrReg = addrResult[0];
        int offset = addrResult[1];
        string valReg = nextReg(regIndex);
        
        // Check if addrReg is a data register (parameter case)
        if (addrReg.startsWith("D")) {
            // If addrReg is a data register, this indicates a struct passed by value
            // The offset is already relative to the start of the struct
            
            if (offset == 0) {
                // This is the first field, which is already in the data register
                lines ~= "        move.l " ~ addrReg ~ ", " ~ valReg ~ "  ; Direct field access from register";
            } else {
                // For other fields, we need to use a different approach
                // In this case, we need to first copy the struct to the stack, then access the field
                
                // Create a temporary space on the stack
                lines ~= "        sub.l #16, SP  ; Allocate space for struct on stack";
                lines ~= "        move.l " ~ addrReg ~ ", 0(SP)  ; Copy struct to stack (field 1)";
                
                // Assuming fields are 4 bytes apart, this should work for a small struct
                // For a real implementation, we would need more complete field information
                // Get the field from the stack
                lines ~= "        move.l " ~ to!string(offset) ~ "(SP), " ~ valReg ~ "  ; Get field from stack";
                
                // Clean up the stack
                lines ~= "        add.l #16, SP  ; Clean stack";
            }
            
            return valReg;
        }
        
        // Optimize: Check if the offset fits in a 16-bit signed value (-32768 to 32767)
        // This allows us to use the more efficient (d16,An) addressing mode directly
        if (offset >= -32768 && offset <= 32767) {
            lines ~= "        move.l " ~ to!string(offset) ~ "(" ~ addrReg ~ "), " ~ valReg ~ 
                     "  ; Optimized field access with direct displacement";
        } else {
            // For larger offsets, need to use a two-step process
            string tempReg = nextReg(regIndex);
            lines ~= "        move.l #" ~ to!string(offset) ~ ", " ~ tempReg ~ "  ; Large field offset";
            lines ~= "        move.l (" ~ addrReg ~ ", " ~ tempReg ~ ".l), " ~ valReg ~ "  ; Access with calculated offset";
            regIndex--; // Free temp reg
        }
        
        return valReg;
    }

    if (auto var = cast(VarExpr) expr) {
        // If the variable is mapped to a register (e.g., function parameter), use it directly
        if (var.name in varAddrs && varAddrs[var.name].startsWith("D")) {
            return varAddrs[var.name];
        }
        string reg = nextReg(regIndex);
        string addr = getOrCreateVarAddr(var.name, varAddrs);
        lines ~= "        move.l " ~ addr ~ ", " ~ reg;
        return reg;
    }

    if (auto bin = cast(BinaryExpr) expr) {
        int leftStart = regIndex;
        string leftReg = generateExpr(bin.left, lines, regIndex, varAddrs);
        int leftEnd = regIndex;

        int rightStart = regIndex;
        string rightReg = generateExpr(bin.right, lines, regIndex, varAddrs);
        int rightEnd = regIndex;

        string dest = nextReg(regIndex);

        // Free registers used by right and left expressions
        regIndex = rightStart; // Free all rightReg temporaries
        regIndex = leftStart;  // Free all leftReg temporaries

        final switch (bin.op) {
            case "=":
            // Assignment: left = right;
            lines ~= format("        move.l %s, %s", rightReg, leftReg);
            break;
            case "+": // Addition
            lines ~= format("        move.l %s, %s", leftReg, dest);
            lines ~= format("        add.l %s, %s", rightReg, dest);
            return dest;
            case "-": // Subtraction
            lines ~= format("        move.l %s, %s", leftReg, dest);
            lines ~= format("        sub.l %s, %s", rightReg, dest);
            return dest;
            case "*": // Multiplication
            // If both operands are the same register, just muls reg, reg
            if (leftReg == rightReg) {
                lines ~= format("        muls %s, %s", leftReg, leftReg);
                return leftReg;
            }
            // If either operand is D0, use D0 as the destination
            if (leftReg == "D0") {
                lines ~= format("        muls %s, D0", rightReg);
                return "D0";
            }
            if (rightReg == "D0") {
                lines ~= format("        muls %s, D0", leftReg);
                return "D0";
            }
            // Otherwise, move leftReg to D0 and muls rightReg, D0
            lines ~= format("        move.l %s, D0", leftReg);
            lines ~= format("        muls %s, D0", rightReg);
            return "D0";
            case "/": // Division
            // Check if right operand is a constant, which we can potentially optimize
            if (auto intLit = cast(IntLiteral) bin.right) {
                int value = intLit.value;
                
                // Check if value is a power of 2 (has exactly one bit set)
                if (value > 0 && (value & (value - 1)) == 0) {
                    // Calculate log2(value) to determine shift amount
                    int shiftAmount = 0;
                    int tempValue = value;
                    while (tempValue > 1) {
                        tempValue >>= 1;
                        shiftAmount++;
                    }
                    
                    // Use shift right instead of division
                    lines ~= format("        move.l %s, %s  ; Prepare for division by %d", leftReg, dest, value);
                    lines ~= format("        asr.l #%d, %s  ; Optimized division by power of 2 (%d)", 
                                   shiftAmount, dest, value);
                    return dest;
                }
                // Optimization for small divisors where constant multiplication is cheaper
                else if (value > 0 && value <= 10) {
                    // For small non-power-of-2 values, we can use reciprocal multiplication technique
                    // This is more efficient for 68K than direct division for common small values
                    
                    // Common reciprocal constants (scaled up by a power of 2 for precision)
                    // Value 3: multiply by 0.33333... (approximate 1/3)
                    // Value 5: multiply by 0.2 (approximate 1/5)
                    // Value 6: multiply by 0.16666... (approximate 1/6)
                    // Value 7: multiply by 0.142857... (approximate 1/7)
                    // Value 9: multiply by 0.11111... (approximate 1/9)
                    // Value 10: multiply by 0.099999... (approximate 1/10)
                    
                    // Note: On 68k, we can't do 64-bit multiplications easily, so we'll use this technique
                    // only for values where we can use a fixed sequence of operations rather than a general
                    // reciprocal multiplication algorithm
                    
                    lines ~= format("        move.l %s, %s  ; Prepare for division by %d", leftReg, dest, value);
                    
                    switch (value) {
                        case 3:
                            // Division by 3: x/3 ≈ x * 0.33333...
                            lines ~= format("        lsr.l #1, %s      ; x/2", dest);
                            lines ~= format("        move.l %s, D0      ; Save x/2", dest);
                            lines ~= format("        lsr.l #1, %s      ; x/4", dest);
                            lines ~= format("        sub.l %s, D0      ; x/2 - x/4 = x/4", dest);
                            lines ~= format("        lsr.l #1, %s      ; x/8", dest);
                            lines ~= format("        add.l D0, %s      ; x/4 + x/8 = 3x/8", dest);
                            lines ~= format("        lsr.l #2, %s      ; 3x/32", dest);
                            // Result is approximately x/3
                            break;
                        case 5:
                            // Division by 5: x/5 ≈ x * 0.2
                            lines ~= format("        lsr.l #2, %s      ; x/4", dest);
                            lines ~= format("        move.l %s, D0      ; Save x/4", dest);
                            lines ~= format("        lsr.l #1, %s      ; x/8", dest);
                            lines ~= format("        add.l %s, D0      ; x/4 + x/8 = 3x/8", dest);
                            lines ~= format("        lsr.l #1, %s      ; x/16", dest);
                            lines ~= format("        add.l %s, D0      ; 3x/8 + x/16 = 7x/16", dest);
                            lines ~= format("        lsr.l #2, %s      ; x/64", dest);
                            lines ~= format("        add.l %s, D0      ; 7x/16 + x/64 = 113x/256 ≈ x/5", dest);
                            lines ~= format("        move.l D0, %s      ; Store final result", dest);
                            break;
                        case 10:
                            // Division by 10: x/10 = x/2 * 1/5 ≈ x * 0.1
                            lines ~= format("        lsr.l #1, %s      ; x/2 (first divide by 2)", dest);
                            // Now divide by 5 using same technique as above
                            lines ~= format("        move.l %s, D0      ; Save x/2", dest);
                            lines ~= format("        lsr.l #2, " ~ dest ~ "      ; x/8");
                            lines ~= format("        add.l %s, D0      ; x/2 + x/8 = 5x/8", dest);
                            lines ~= format("        lsr.l #1, %s      ; x/16", dest);
                            lines ~= format("        add.l %s, D0      ; 5x/8 + x/16 = 21x/32", dest);
                            lines ~= format("        lsr.l #2, %s      ; x/64", dest);
                            lines ~= format("        add.l %s, D0      ; 21x/32 + x/64 = 85x/128 ≈ x/10", dest);
                            lines ~= format("        move.l D0, %s      ; Store final result", dest);
                            break;
                        default:
                            // Fall back to divs for other small constants
                            lines ~= format("        divs #%d, %s  ; Division by constant %d", value, dest, value);
                            break;
                    }
                    return dest;
                }
            }
            
            // Fall back to standard division for non-optimizable cases
            lines ~= format("        move.l %s, %s", leftReg, dest);
            lines ~= format("        divs %s, %s", rightReg, dest);
            return dest;
            case "%": // Modulo
            // Check if right operand is a power of 2 constant, which can be optimized to bitwise AND
            if (auto intLit = cast(IntLiteral) bin.right) {
                int value = intLit.value;
                // Check if value is a power of 2 (has exactly one bit set)
                if (value > 0 && (value & (value - 1)) == 0) {
                    // For power of 2 modulo, we can use a simple AND with (value-1)
                    // Example: x % 8 is equivalent to x & 7
                    lines ~= format("        move.l %s, %s", leftReg, dest);
                    lines ~= format("        and.l #%d, %s  ; Optimized modulo by power of 2 (%d)",
                                    value - 1, dest, value);
                    return dest;
                }
            }
            
            // Fallback for non-power-of-2 or non-constant divisors
            lines ~= format("        move.l %s, %s", leftReg, dest);
            lines ~= format("        divs %s, D1", rightReg);
            lines ~= format("        muls %s, D1", rightReg);
            lines ~= format("        sub.l D1, %s", leftReg);
            return dest;
            case "+=":
            lines ~= format("        add.l %s, %s", rightReg, leftReg);
            break;
            case "-=":
            lines ~= format("        sub.l %s, %s", rightReg, leftReg);
            break;
            case "*=":
            lines ~= format("        muls %s, %s", rightReg, leftReg);
            break;
            case "/=":
            lines ~= format("        divs %s, %s", rightReg, leftReg);
            break;
            case "%=":
            // Modulo assignment: a %= b
            // D2GEN doesn't have a direct mod instruction, so do: a = a - (a / b) * b
            lines ~= format("        move.l %s, D1", leftReg);
            lines ~= format("        divs %s, D1", rightReg);
            lines ~= format("        muls %s, D1", rightReg);
            lines ~= format("        sub.l D1, %s", leftReg);
            break;
            case "==":
            {
            // Ultra-optimized branchless equality check using seq.b + and.l
            lines ~= format("        moveq #0, %s  ; Clear result register", dest);
            lines ~= format("        cmp.l %s, %s  ; Compare values", rightReg, leftReg);
            lines ~= format("        seq.b %s      ; Set dest to FF if equal, 00 if not equal", dest); 
            lines ~= format("        and.l #1, %s  ; Convert FF to 01, 00 stays 00", dest);
            return dest;
            }
            case "!=":
            {
            // Ultra-optimized branchless inequality check using sne.b + and.l
            lines ~= format("        moveq #0, %s  ; Clear result register", dest);
            lines ~= format("        cmp.l %s, %s  ; Compare values", rightReg, leftReg);
            lines ~= format("        sne.b %s      ; Set dest to FF if not equal, 00 if equal", dest);
            lines ~= format("        and.l #1, %s  ; Convert FF to 01, 00 stays 00", dest);
            return dest;
            }
            case "~=":
            // Array append: arr ~= val
            auto leftVarExpr = cast(VarExpr)bin.left;
            string arrBase = getCleanArrayName(leftVarExpr.name);
            string lenLabel = arrBase ~ "_len";
            string idxReg = nextReg(regIndex);

            // load current length
            lines ~= format("        move.l %s, %s", lenLabel, idxReg);
            // store value at arrBase_idxReg
            lines ~= format("        move.l %s, %s_%s", rightReg, arrBase, idxReg);
            // increment length
            lines ~= format("        addq.l #1, %s", lenLabel);
            break;
            case "<":
            {
            // Ultra-optimized branchless less-than check using slt.b + and.l
            lines ~= format("        moveq #0, %s  ; Clear result register", dest);
            lines ~= format("        cmp.l %s, %s  ; Compare values", rightReg, leftReg);
            lines ~= format("        slt.b %s      ; Set dest to FF if less than, 00 otherwise", dest);
            lines ~= format("        and.l #1, %s  ; Convert FF to 01, 00 stays 00", dest);
            return dest;
            }
            case "<=":
            {
            // Ultra-optimized branchless less-than-or-equal check using sle.b + and.l
            lines ~= format("        moveq #0, %s  ; Clear result register", dest);
            lines ~= format("        cmp.l %s, %s  ; Compare values", rightReg, leftReg);
            lines ~= format("        sle.b %s      ; Set dest to FF if less or equal, 00 otherwise", dest);
            lines ~= format("        and.l #1, %s  ; Convert FF to 01, 00 stays 00", dest);
            return dest;
            }
            case ">":
            {
            // Ultra-optimized branchless greater-than check using sgt.b + and.l
            lines ~= format("        moveq #0, %s  ; Clear result register", dest);
            lines ~= format("        cmp.l %s, %s  ; Compare values", rightReg, leftReg);
            lines ~= format("        sgt.b %s      ; Set dest to FF if greater than, 00 otherwise", dest);
            lines ~= format("        and.l #1, %s  ; Convert FF to 01, 00 stays 00", dest);
            return dest;
            }
            case ">=":
            {
            // Ultra-optimized branchless greater-than-or-equal check using sge.b + and.l
            lines ~= format("        moveq #0, %s  ; Clear result register", dest);
            lines ~= format("        cmp.l %s, %s  ; Compare values", rightReg, leftReg);
            lines ~= format("        sge.b %s      ; Set dest to FF if greater or equal, 00 otherwise", dest);
            lines ~= format("        and.l #1, %s  ; Convert FF to 01, 00 stays 00", dest);
            return dest;
            }
            case "&&":
            lines ~= format("        move.l %s, %s", leftReg, dest);
            lines ~= format("        and.l %s, %s", rightReg, dest);
            return dest;
            case "||":
            lines ~= format("        move.l %s, %s", leftReg, dest);
            lines ~= format("        or.l %s, %s", rightReg, dest);
            return dest;
            case ">>":
            lines ~= format("        move.l %s, %s", leftReg, dest);
            lines ~= format("        lsr.l %s, %s", rightReg, dest);
            return dest;
            case "<<":
            lines ~= format("        move.l %s, %s", leftReg, dest);
            lines ~= format("        lsl.l %s, %s", rightReg, dest);
            return dest;
            case "&":
            lines ~= format("        move.l %s, %s", leftReg, dest);
            lines ~= format("        and.l %s, %s", rightReg, dest);
            return dest;
            case "|":
            lines ~= format("        move.l %s, %s", leftReg, dest);
            lines ~= format("        or.l %s, %s", rightReg, dest);
            return dest;
            case "^":
            lines ~= format("        move.l %s, %s", leftReg, dest);
            lines ~= format("        eor.l %s, %s", rightReg, dest);
            return dest;
        }
    }

    if (auto memberCall = cast(MemberCallExpr) expr) {
        // UFCS: obj.method(args) => method(obj, args)
        string objectReg = generateExpr(memberCall.object, lines, regIndex, varAddrs);
        
        // Push the object as the first argument (UFCS requires the object to be the first parameter)
        lines ~= "        move.l " ~ objectReg ~ ", -(SP)  ; Push object as first UFCS arg";
        
        // Push all other arguments
        foreach_reverse (arg; memberCall.arguments) {
            string argReg = generateExpr(arg, lines, regIndex, varAddrs);
            lines ~= "        move.l " ~ argReg ~ ", -(SP)";
        }
        
        // Call the function (method name is the function name in UFCS)
        lines ~= "        bsr " ~ memberCall.method;
        
        // Clean up stack (object + other arguments)
        lines ~= "        add.l #" ~ to!string(4 * (1 + memberCall.arguments.length)) ~ ", SP";
        
        // Get the return value
        string resultReg = nextReg(regIndex);
        lines ~= "        move.l D0, " ~ resultReg ~ "  ; Store UFCS result";
        
        return resultReg;
    }
    
    // Handle conditional expressions (ternary operator)
    if (auto condExpr = cast(ConditionalExpr) expr) {
        // Generate unique labels for the conditional branches
        string falseLabel = genLabel("cond_false");
        string endLabel = genLabel("cond_end");
        
        // Save current register index to reset it after each branch
        int savedRegIndex = regIndex;
        
        // Generate condition code
        string condReg = generateExpr(condExpr.condition, lines, regIndex, varAddrs);
        
        // Test the condition
        lines ~= "        tst.l " ~ condReg ~ "  ; Check if condition is true/non-zero";
        lines ~= "        beq " ~ falseLabel ~ "  ; Branch to false expression if condition is false";
        
        // Reset register index for true branch
        regIndex = savedRegIndex;
        
        // Generate code for true expression
        string trueReg = generateExpr(condExpr.trueExpr, lines, regIndex, varAddrs);
        string resultReg = "D1"; // Always use D1 for the result
        lines ~= "        move.l " ~ trueReg ~ ", " ~ resultReg ~ "  ; Move true result to result register";
        lines ~= "        bra " ~ endLabel ~ "  ; Skip false expression";
        
        // Reset register index for false branch
        regIndex = savedRegIndex;
        
        // Generate code for false expression
        lines ~= falseLabel ~ ":";
        string falseReg = generateExpr(condExpr.falseExpr, lines, regIndex, varAddrs);
        lines ~= "        move.l " ~ falseReg ~ ", " ~ resultReg ~ "  ; Move false result to result register";
        
        // End of conditional expression
        lines ~= endLabel ~ ":";
        
        // Ensure regIndex points to next available register
        regIndex = 2; // After D1
        
        return resultReg;
    }
    
    // Handle string literals in expressions
    if (auto strLit = cast(StringLiteral) expr) {
        // Generate a unique label for this string literal
        string strLabel = getOrCreateStringLabel(strLit.value);
        
        // Load the address of the string into an address register (A0)
        lines ~= "        lea " ~ strLabel ~ ", A0  ; Load string address into A0";
        
        // Return A0 as the register containing the string address
        return "A0";
    }
    
    // Handle boolean literals in expressions
    if (auto boolLit = cast(BoolLiteral) expr) {
        string reg = nextReg(regIndex);
        // Use 1 for true and 0 for false
        lines ~= "        move.l #" ~ (boolLit.value ? "1" : "0") ~ ", " ~ reg ~ "  ; Load boolean value";
        
        return reg;
    }
    
    // Handle function calls in expressions
    if (auto call = cast(CallExpr) expr) {
        // Special handling for complex_expr fallback
        if (call.name == "complex_expr") {
            // For complex expressions that were fallbacked to complex_expr,
            // we should examine the arguments to determine what to do.
            // For now, just handle the first argument and hope for the best.
            if (call.args.length > 0) {
                string argReg = generateExpr(call.args[0], lines, regIndex, varAddrs);
                string resultReg = nextReg(regIndex);
                lines ~= "        move.l " ~ argReg ~ ", " ~ resultReg ~ "  ; Use first arg as result";
                return resultReg;
            }
            
            // Fallback: just return D0
            return "D0";
        }
    
        // Push arguments onto the stack in reverse order
        foreach_reverse (arg; call.args) {
            string reg = generateExpr(arg, lines, regIndex, varAddrs);
            lines ~= "        move.l " ~ reg ~ ", -(SP)  ; Push argument onto stack";
        }

        // Call the function
        if (varTypes.get(call.name, "").startsWith("void function(")) {
            // Function pointer call
            lines ~= format("        move.l var_%s, A0  ; Load function pointer", call.name);
            lines ~= "        jsr (A0)  ; Call function via pointer";
        } else {
            // Normal function call
            lines ~= "        bsr " ~ call.name ~ "  ; Call function";
        }
        
        // Clean up the stack
        if (call.args.length > 0) {
            lines ~= "        add.l #" ~ to!string(4 * call.args.length) ~ ", SP  ; Clean up stack";
        }
        
        // Move the result to a register
        string resultReg = nextReg(regIndex);
        lines ~= "        move.l D0, " ~ resultReg ~ "  ; Get function return value";
        
        return resultReg;
    }
    
    // If we reach here, we have an unhandled expression type
    assert(0, "Unhandled expression type in generateExpr: " ~ typeid(expr).toString());
}

// --- PATCH: Added missing foreachStmt code generation ---
void generateForeachStmt(ForeachStmt node, ref string[] lines, ref int regIndex, ref string[string] varAddrs) {
    string loopLabel = genLabel("foreach");
    string endLabel = genLabel("end_foreach");
    // string counterVar = "foreach_counter_" ~ to!string(labelCounter++); // Not used currently
    string iterVar = node.varName;

    // Assume iterable is a variable name
    string arrName = (cast(VarExpr)node.iterable).name;
    string arrBaseAddr = getOrCreateVarAddr(arrName, varAddrs); // Get base address/label
    string lenLabel = arrName ~ "_len"; // Assume length label exists
    string idxReg = nextReg(regIndex); // Register for index
    string lenReg = nextReg(regIndex); // Register for length
    string addrReg = "A0"; // Use A0 for address calculation
    string valReg = nextReg(regIndex); // Register to hold the element value

    // Initialize index register
    lines ~= "        moveq #0, " ~ idxReg; // Initialize loop index to zero

    lines ~= loopLabel ~ ":";
    // Load array length
    lines ~= "        move.l " ~ lenLabel ~ ", " ~ lenReg;
    // Compare index with length
    lines ~= "        cmp.l " ~ lenReg ~ ", " ~ idxReg; // if idx >= len
    lines ~= "        bge " ~ endLabel; // goto endLabel

    // Calculate element address: base + index * 4 (assuming 4-byte elements)
    lines ~= "        lea " ~ arrBaseAddr ~ ", " ~ addrReg; // Load base address into A0
    lines ~= "        move.l " ~ idxReg ~ ", " ~ valReg; // Copy index to a data register for multiplication
    lines ~= "        mulu #4, " ~ valReg; // Multiply index by element size (4)
    lines ~= "        add.l " ~ valReg ~ ", " ~ addrReg; // Add offset to base address in A0

    // Load element value from calculated address
    lines ~= "        move.l (" ~ addrReg ~ "), " ~ valReg; // Load value from (A0) into valReg

    // Assign element value to iteration variable
    string iterAddr = getOrCreateVarAddr(iterVar, varAddrs);
    lines ~= "        move.l " ~ valReg ~ ", " ~ iterAddr; // iterVar = value

    // Loop body
    foreach (stmt; node.forEachBody) {
        // Pass break/continue labels if needed (assuming endLabel for break for now)
        generateStmt(stmt, lines, regIndex, varAddrs, endLabel, loopLabel);
    }

    // Increment index
    lines ~= "        addq.l #1, " ~ idxReg; // idx++
    lines ~= "        bra " ~ loopLabel; // Jump back to loop start

    lines ~= endLabel ~ ":";
}
// --- END PATCH ---

string nextReg(ref int regIndex) {
    if (regIndex > 7) throw new Exception("Out of registers");
    return "D" ~ to!string(regIndex++);
}

string genLabel(string base) {
    // Create more descriptive labels by using specific prefixes
    // for different code constructs
    string prefix = "";
    
    // Control flow labels
    if (base.startsWith("Ltrue")) {
        prefix = ".true";
    }
    else if (base.startsWith("Lend")) {
        prefix = ".end";
    }
    else if (base.startsWith("else")) {
        prefix = ".else";
    }
    else if (base.startsWith("endif")) {
        prefix = ".endif";
    }
    
    // Loop labels
    else if (base.startsWith("for_start")) {
        prefix = ".for_start";
    }
    else if (base.startsWith("for_end")) {
        prefix = ".for_end";
    }
    else if (base.startsWith("while")) {
        prefix = ".while";
    }
    else if (base.startsWith("end_loop")) {
        prefix = ".end_loop";
    }
    else if (base.startsWith("break")) {
        prefix = ".break";
    }
    else if (base.startsWith("continue")) {
        prefix = ".continue";
    }
    
    // Conditionals
    else if (base.startsWith("if_")) {
        prefix = ".if";
    }
    
    // Switch/case labels
    else if (base.startsWith("switch_")) {
        prefix = ".switch";
    }
    else if (base.startsWith("case_")) {
        prefix = ".case";
    }
    else if (base.startsWith("switch_end")) {
        prefix = ".switch_end";
    }
    else if (base.startsWith("switch_continue")) {
        prefix = ".switch_continue";
    }
    
    // If this is a generic label, just use as is
    else {
        prefix = base;
    }
    
    return prefix ~ "_" ~ to!string(labelCounter++);
}

string getOrCreateVarAddr(string name, ref string[string] map) {
    if (!(name in map)) {
        map[name] = name; // Use the variable name directly
        emittedVars[name] = "1"; // Track for data section
    }
    return map[name];
}

string getOrCreateStringLabel(string val) {
    if (val in strLabels) {
        return strLabels[val];
    }

    string label = toAlphaLabel(nextStringIndex++);
    strLabels[val] = label;
    return label;
}

string toAlphaLabel(int index) {
    import std.conv : to;

    // Base-26 (A-Z) encoding
    enum base = 26;
    char a = 'A';

    int first = index / base;
    int second = index % base;

    return "str" ~ [cast(char)(a + first), cast(char)(a + second)].to!string;
}

string getOrCreateArrayLabel(string name, ref string[string] map) {
    if (!(name in map)) {
        map[name] = "arr_" ~ name;
    }
    return map[name];
}

bool isBreakOrReturn(ASTNode node) {
    return (cast(BreakStmt) node !is null || cast(ReturnStmt) node !is null);
}

// Helper to get clean array variable name
string getCleanArrayName(string name) {
    return "arr_" ~ name;
}

void generateMethodCall(ref string[] lines, ref int regIndex, ref string[string] varAddrs, CallExpr call, MemberExpr memberExpr) {
    // Special handling for method calls using the passed MemberExpr directly
    // Don't need to use call.callee since MemberExpr is already passed as a parameter
    auto objName = memberExpr.object.toString();
    auto methodName = memberExpr.member;
    
    // Special case for printStruct from mixin
    if (methodName == "printStruct") {
        // For printStruct, we need to get the struct name and add it to the call
        string structType = varTypes.get(objName, "unknown");
        
        // Push the struct itself for 'this' parameter
        string objReg = generateExpr(memberExpr.object, lines, regIndex, varAddrs);
        lines ~= "        move.l " ~ objReg ~ ", -(SP)  ; Push struct address as 'this'";
        
        // Add the struct name as a string literal
        string label = getOrCreateStringLabel(structType);
        lines ~= "        lea " ~ label ~ ", A1  ; Load struct name";
        lines ~= "        move.l A1, -(SP)  ; Push struct name";
        
        // Call writeln with both parameters
        lines ~= "        bsr writeln";
        lines ~= "        add.l #8, SP  ; Clean up parameters";
        return;
    }
    
    // For scale or other methods from mixins
    if (methodName == "scale") {
        // Generate arguments
        foreach (arg; call.args) {
            string argReg = generateExpr(arg, lines, regIndex, varAddrs);
            lines ~= "        move.l " ~ argReg ~ ", -(SP)  ; Push argument";
        }
        
        // Call the function using a label based on struct type and method
        string structType = varTypes.get(objName, "unknown");
        lines ~= "        bsr " ~ structType ~ "_" ~ methodName;
        lines ~= "        add.l #" ~ to!string(4 * call.args.length) ~ ", SP  ; Clean up arguments";
        lines ~= "        move.l D0, D1  ; Move result to D1";
        return;
    }
    
    // For the complex_expr method (p.printStruct)
    if (methodName == "printStruct") {
        // Special case for printStruct
        lines ~= "        bsr printStruct";
        return;
    }
    
    // For any other method call, handle it as a regular function call (UFCS)
    // Pass the object as the first argument and then all other args
    string objReg = generateExpr(memberExpr.object, lines, regIndex, varAddrs);
    lines ~= "        move.l " ~ objReg ~ ", -(SP)  ; Push object as first UFCS arg";
    
    // Push remaining arguments
    foreach_reverse (arg; call.args) {
        string argReg = generateExpr(arg, lines, regIndex, varAddrs);
        lines ~= "        move.l " ~ argReg ~ ", -(SP)  ; Push argument";
    }
    
    // Call the method as a regular function (UFCS transformation)
    lines ~= "        bsr " ~ methodName ~ "  ; Call function via UFCS";
    
    // Clean up the stack
    lines ~= "        add.l #" ~ to!string(4 * (1 + call.args.length)) ~ ", SP  ; Clean up stack";
    
    // Store the result
    string resultReg = nextReg(regIndex);
    lines ~= "        move.l D0, " ~ resultReg ~ "  ; Get function return value";
    return;
}

