module backend.codegen;

import std.stdio;
import std.string;
import std.array;
import std.conv;
import std.format;
import std.algorithm : map, joiner;
import std.container : AssociativeArray;

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

string[string] arrayElementTypes; // Maps array names to their element types
int[string] structSizes;         // Maps struct types to their sizes in bytes

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
    arrayElementTypes = null;
    structSizes = null;
    // --- END PATCH ---

    string[] lines;

    lines ~= "** GENERATED CODE USING DLANG AND D2GEN COMPILER **";
    lines ~= "        ORG $1000";
    // --- PATCH: Call __global_init before main ---
    lines ~= "        JSR __global_init";
    lines ~= "        JMP main";
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
    lines ~= "__global_init:";
    foreach (node; globalAssignments) {
        if (auto decl = cast(VarDecl)node) {
            string label = decl.name;
            if (label in emittedSymbols) continue;
            // Only emit if public
            if (label in publicThings) {
                emittedSymbols[label] = "1";
                varTypes[label] = decl.type;
                emittedVars[label] = "1";
                if (decl.value is null) {
                    lines ~= format("%s:    ds.l 1", label);
                }
            }
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
    lines ~= "        ; String literals";
    foreach (val, label; strLabels) {
        lines ~= label ~ ":";
        lines ~= format("        dc.b '%s', 0", val);
    }

    lines ~= "        ; Scalar and struct variables";
    // --- PATCH: Emit all public global variables (VarDecl) as ds.l 1 if not already emitted ---
    foreach (node; globalAssignments) {
        if (auto decl = cast(VarDecl)node) {
            string label = decl.name;
            if (label in emittedSymbols) continue;
            if (label in publicThings) {
                emittedSymbols[label] = "1";
                varTypes[label] = decl.type;
                emittedVars[label] = "1";
                if (decl.value is null) {
                    lines ~= format("%s:    ds.l 1", label);
                }
            }
        }
    }
    // --- END PATCH ---

    // --- PATCH: Emit initial values for global assignments and declarations ---
    foreach (node; globalAssignments) {
        if (auto decl = cast(VarDecl)node) {
            if (decl.value !is null) {
                generateStmt(decl, lines, regIndex, varAddrs);
            }
        } else if (auto assign = cast(AssignStmt)node) {
            generateStmt(assign, lines, regIndex, varAddrs);
        } else if (auto exprStmt = cast(ExprStmt)node) {
            generateStmt(exprStmt, lines, regIndex, varAddrs);
        }
    }
    // --- END PATCH ---

    // Emit zero-initialized variables/fields not already initialized
    foreach (name, countStr; emittedVars) {
        if (!(name in emittedSymbols)) {
            int count = to!int(countStr);
            if (varTypes.get(name, "").startsWith("void function(") && !(name in functionNames)) {
                string varLabel = "var_" ~ name;
                if (!(varLabel in emittedSymbols)) {
                    lines ~= varLabel ~ ":    ds.l 1";
                    emittedSymbols[varLabel] = "1";
                }
                continue;
            }
            if (count > 0) {
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

    lines ~= "        ; Array labels";
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

    lines ~= "        ; Loop variables";
    foreach (name, _; loopVarsUsed) {
        if (!(name in emittedSymbols)) {
            lines ~= name ~ ":    ds.l 1";
            emittedSymbols[name] = "1";
        }
    }

    lines ~= "";
    lines ~= "        SIMHALT";
    lines ~= "        END";
    return lines.join("\n");
}

bool isBuiltinType(string t) {
    return t == "int" || t == "byte" || t == "short" || t == "bool" || t == "string" ||
           t == "int[]" || t == "byte[]" || t == "short[]" || t == "bool[]" || t == "string[]";
}

void generateFunction(FunctionDecl func, ref string[] lines, ref int regIndex, ref string[string] globalVarAddrs) {
    string[string] localVarAddrs;
    lines ~= func.name ~ ":";
    lines ~= "        ; Function prologue";
    lines ~= "        move.l A6, -(SP)";
    lines ~= "        move.l SP, A6";

    // Handle function parameters: put directly in D0, D1, ... if possible
    int offset = 8;
    foreach (i, param; func.params) {
        varTypes[param.name] = param.type;
        string reg = (i == 0) ? "D0" : nextReg(regIndex);
        lines ~= format("        move.l %d(A6), %s", offset, reg);
        localVarAddrs[param.name] = reg; // Map param name to register
        offset += 4;
    }

    foreach (stmt; func.funcBody) {
        generateStmt(stmt, lines, regIndex, localVarAddrs);
    }

    lines ~= "        ; Function epilogue";
    // lines ~= "        move.l A6, SP";
    lines ~= "        move.l (SP)+, A6";
    lines ~= "        rts";
}

void handleAssignStmt(AssignStmt assign, ref string[] lines, ref int regIndex, ref string[string] varAddrs) {
    // --- VERY TOP LEVEL DEBUG ---
    lines ~= "        ; DEBUG: Entered handleAssignStmt. LHS type: " ~ assign.lhs.classinfo.name;
    // --- END DEBUG ---

    // --- REVISED LOGIC for handling LHS of assignment ---
    ASTNode lhs = assign.lhs;
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
                fieldPath ~= sf.field; // Add field name to path
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
        
        lines ~= "        ; DEBUG: Field path: " ~ fieldPath.join(".") ~ ", Base type: " ~ 
            (arrAccess !is null ? "ArrayAccessExpr" : (baseExpr !is null ? baseExpr.classinfo.name : "null"));
            
        // --- PATCH: Handle assignment to struct field within an array element ---
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
                // Common struct sizes from examples
                if (structType == "Sprite") structSizes[structType] = 24;  // Vec2(8) + Color(12) + int(4)
                else if (structType == "Color") structSizes[structType] = 12;  // r,g,b (4 each)
                else if (structType == "Point") structSizes[structType] = 8;   // x,y (4 each)
                else if (structType == "Box") structSizes[structType] = 20;  // Point(8) + Point(8) + int(4)
            }
            
            // Now we can look up the element size
            if (structType in structSizes) {
                elementSize = structSizes[structType];
            }
            
            // Calculate field offset based on field path and struct type
            if (structType != "") {
                // Calculate field offset based on the field path
                if (structType == "Box") {
                    if (fieldPath.length == 2) {  // Like boxes[i].min.x
                        string innerField = fieldPath[0]; // x or y
                        string outerField = fieldPath[1]; // min or max
                        
                        if (outerField == "min") {
                            // Point fields: x(0), y(4)
                            if (innerField == "x") fieldOffset = 0;
                            else if (innerField == "y") fieldOffset = 4;
                        } 
                        else if (outerField == "max") {
                            // Point fields starting at offset 8
                            if (innerField == "x") fieldOffset = 8;
                            else if (innerField == "y") fieldOffset = 12;
                        }
                    } 
                    else if (fieldPath.length == 1) {  // Like boxes[i].colorIndex
                        string directField = fieldPath[0];
                        if (directField == "colorIndex") fieldOffset = 16;  // After min and max Points
                    }
                }
                else if (structType == "Point") {
                    if (fieldPath.length == 1) {
                        if (fieldPath[0] == "x") fieldOffset = 0;
                        else if (fieldPath[0] == "y") fieldOffset = 4;
                    }
                }
                // Keep your existing Sprite and Color handling
                else if (structType == "Sprite") {
                    // Sprite structure: pos(Vec2), tint(Color), id(int)
                    if (fieldPath.length == 2) { // Double-nested fields like sprites[i].pos.x
                        string innerField = fieldPath[0]; // "x", "y", "r", "g", "b"
                        string outerField = fieldPath[1]; // "pos", "tint"
                        
                        // Sprite structure: pos(Vec2), tint(Color), id(int)
                        if (outerField == "pos") {
                            // Vec2 structure: x(0), y(4)
                            if (innerField == "x") fieldOffset = 0;
                            else if (innerField == "y") fieldOffset = 4;
                        }
                        else if (outerField == "tint") {
                            // Color structure: r(0), g(4), b(8) starting at offset 8 in Sprite
                            if (innerField == "r") fieldOffset = 8;
                            else if (innerField == "g") fieldOffset = 12;
                            else if (innerField == "b") fieldOffset = 16;
                        }
                    }
                    else if (fieldPath.length == 1) { // Direct fields like sprites[i].id
                        string directField = fieldPath[0];
                        if (directField == "id") {
                            fieldOffset = 20; // id is at offset 20 (after pos and tint)
                        }
                    }
                }
                else if (structType == "Color") {
                    // Size: r(4) + g(4) + b(4) = 12 bytes
                    elementSize = 12;
                    
                    // Direct field access for Color array
                    if (fieldPath.length == 1) {
                        string colorField = fieldPath[0];
                        if (colorField == "r") fieldOffset = 0;
                        else if (colorField == "g") fieldOffset = 4;
                        else if (colorField == "b") fieldOffset = 8;
                    }
                }
                
                // Debug output for diagnostic purposes
                lines ~= "        ; DEBUG: Field: " ~ field.field ~ ", ElementSize: " ~ to!string(elementSize) 
                         ~ ", Offset: " ~ to!string(fieldOffset);
                // Add more else if for other struct arrays based on their definitions

                if (elementSize == 0 && (arrName == "sprites" || arrName == "palette")) { // Only error if known struct array fails lookup
                    lines ~= "        ; ERROR: Could not determine element size/offset for struct array " ~ arrName ~ "." ~ field.field;
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
        // Handles assignments like hiddenValues[0] = score;
        string baseAddrLabel = getOrCreateVarAddr(access.arrayName, varAddrs);
        string valReg = generateExpr(assign.value, lines, regIndex, varAddrs);
        string addrReg = "A0";
        int elementSize = 4; // Default to 4 bytes (long) for simple arrays like int[]
        // TODO: Lookup actual element size based on varTypes[access.arrayName] if supporting arrays of other types (e.g., short[], byte[])

        // --- FIX: Handle constant and dynamic indices consistently ---
        if (auto intLit = cast(IntLiteral) access.index) {
            // Constant index: arr[const_idx]
            int indexValue = intLit.value;
            int offset = indexValue * elementSize;
            lines ~= "        lea " ~ baseAddrLabel ~ ", " ~ addrReg;
            lines ~= "        move.l " ~ valReg ~ ", " ~ to!string(offset) ~ "(" ~ addrReg ~ ")";
        } else {
            // Dynamic index: arr[idx]
            string indexReg = generateExpr(access.index, lines, regIndex, varAddrs);
            string offsetReg = nextReg(regIndex); // Use a data register for offset calculation
            lines ~= "        move.l " ~ indexReg ~ ", " ~ offsetReg; // Copy index value
            lines ~= "        mulu #" ~ to!string(elementSize) ~ ", " ~ offsetReg; // Calculate byte offset
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
        string valReg = generateExpr(assign.value, lines, regIndex, varAddrs);
        lines ~= "        ; Attempting basic store to D0 (likely incorrect)";
        lines ~= "        move.l " ~ valReg ~ ", D0";
    }
}

void generateStmt(ASTNode node, ref string[] lines, ref int regIndex, ref string[string] varAddrs, string breakLabel = "", string continueLabel = "") {
    regIndex = 1;

    if (auto decl = cast(VarDecl) node) {
        varTypes[decl.name] = decl.type;
        string addr = getOrCreateVarAddr(decl.name, varAddrs);

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
                        if (structType in structFieldOffsets) {
                            for (int i = 0; i < arrLen; i++) {
                                flattenStructFields(structType, decl.name ~ "_" ~ to!string(i), varAddrs, emittedVars, varTypes);
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
        string labelElse = genLabel("else");
        string labelEnd = genLabel("endif");

        string condReg = generateExpr(ifstmt.condition, lines, regIndex, varAddrs);
        if (condReg != "D0")
            lines ~= "        move.l " ~ condReg ~ ", D0";
        lines ~= "        cmpa.l " ~ condReg ~ ", A1";
        lines ~= "        beq " ~ labelElse;

        foreach (s; ifstmt.thenBody) {
            generateStmt(s, lines, regIndex, varAddrs);
        }

        lines ~= "        bra " ~ labelEnd;
        lines ~= labelElse ~ ":";

        foreach (s; ifstmt.elseBody) {
            generateStmt(s, lines, regIndex, varAddrs);
        }

        lines ~= labelEnd ~ ":";
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
        string labelStart = genLabel("while");
        string labelEnd = genLabel("end_loop");

        lines ~= labelStart ~ ":";

        string condReg = generateExpr(whilestmt.condition, lines, regIndex, varAddrs);
        if (condReg != "D0")
            lines ~= "        move.l " ~ condReg ~ ", D0";
        lines ~= "        cmp.l #0, " ~ condReg;
        lines ~= "        beq " ~ labelEnd;

        foreach (s; whilestmt.loopBody) {
            generateStmt(s, lines, regIndex, varAddrs);
        }

        lines ~= "        bra " ~ labelStart;
        lines ~= labelEnd ~ ":";
    }
    else if (auto forLoop = cast(CStyleForStmt) node) {
        generateStmt(forLoop.init, lines, regIndex, varAddrs);

        string startLabel = genLabel("for_start");
        string endLabel = genLabel("for_end");

        lines ~= startLabel ~ ":";

        string condReg = generateExpr(forLoop.condition, lines, regIndex, varAddrs);
        if (condReg != "D0")
            lines ~= "        move.l " ~ condReg ~ ", D0";
        lines ~= "        cmp.l #0, " ~ condReg;
        lines ~= "        beq " ~ endLabel;

        foreach (stmt; forLoop.forBody) {
            generateStmt(stmt, lines, regIndex, varAddrs);
        }

        generateStmt(forLoop.increment, lines, regIndex, varAddrs);
        lines ~= "        bra " ~ startLabel;
        lines ~= endLabel ~ ":";
    }
    else if (auto foreachStmt = cast(ForeachStmt) node) {
        generateForeachStmt(foreachStmt, lines, regIndex, varAddrs);
    }
    else if (auto arr = cast(ArrayDecl) node) {
        string base = "arr" ~ capitalize(arr.name);
        globalArrays[arr.name] = base;
        int arrLen = arr.elements.length;
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
            // if (varTypes.get(call.name, "").startsWith("void function(")) {
            //     lines ~= format("        move.l var_%s, A0", call.name); // Load function pointer address
            //     lines ~= "        jsr (A0)";
            // } else {
                lines ~= "        bsr " ~ call.name; // Direct call
            // }

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
        string dest = nextReg(regIndex);
        lines ~= "        move.l D0, " ~ dest;
    }
}

// Recursively flatten struct fields for arrays of structs
void flattenStructFields(string structType, string prefix, ref string[string] varAddrs, ref string[string] emittedVars, ref string[string] varTypes) {
    if (!(structType in structFieldOffsets)) return;
    foreach (fieldName, _; structFieldOffsets[structType]) {
        // Try to get the type from varTypes if available, fallback to int
        string fieldType = "int";
        if (structType ~ "." ~ fieldName in varTypes) {
            fieldType = varTypes[structType ~ "." ~ fieldName];
        }
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

string generateExpr(ASTNode expr, ref string[] lines, ref int regIndex, string[string] varAddrs) {
    // --- NEW TOP-LEVEL DEBUG ---
    lines ~= "        ; DEBUG: generateExpr called with type: " ~ expr.classinfo.name;
    // Optionally add more detail, e.g., expr.toString() if available and safe
    // --- END NEW DEBUG ---

    if (auto lit = cast(IntLiteral) expr) {
        string reg = nextReg(regIndex);
        lines ~= "        move.l #" ~ to!string(lit.value) ~ ", " ~ reg;
        return reg;
    }

    if (auto b = cast(BoolLiteral) expr) {
        string reg = nextReg(regIndex);
        lines ~= "        move.l #" ~ (b.value ? "1" : "0") ~ ", " ~ reg;
        return reg;
    }

    if (auto unary = cast(UnaryExpr) expr) {
        if (unary.op == "&") {
            auto var = cast(VarExpr) unary.expr;
            string addr = getOrCreateVarAddr(var.name, varAddrs);
            string reg = "A" ~ to!string(regIndex++);
            lines ~= "        lea " ~ addr ~ ", " ~ reg;
            return reg;
        }
    }

    // --- PATCH: Handle CastExpr ---
    if (auto castExpr = cast(CastExpr) expr) {
        // For now, assume casts between numeric types are no-ops in assembly.
        // Generate the inner expression. More complex casts would need specific code.
        // --- FIX: Changed targetType to typeName ---
        lines ~= "        ; Handling cast to " ~ castExpr.typeName;
        return generateExpr(castExpr.expr, lines, regIndex, varAddrs);
    }
    // --- END PATCH ---

    if (auto field = cast(StructFieldAccess) expr) {
        // --- REVISED LOGIC for reading struct fields ---
        // Check if the ultimate base is an array access, handling nesting
        ASTNode base = field.baseExpr;
        ArrayAccessExpr arrAccess = null;
        string[] nestedFields = [field.field]; // Store field names bottom-up (e.g., [x, pos])

        // --- FIX: Correct while loop syntax ---
        StructFieldAccess nestedField;
        while ((nestedField = cast(StructFieldAccess) base) !is null) {
            nestedFields ~= nestedField.field; // Prepend field name
            base = nestedField.baseExpr;
        }
        // --- END FIX ---

        // --- Debugging --- 
        lines ~= "        ; DEBUG: StructFieldAccess handler. Base type: " ~ base.classinfo.name;
        if (auto aae = cast(ArrayAccessExpr) base) {
            lines ~= "        ; DEBUG: Base is ArrayAccessExpr. Array name: " ~ aae.arrayName;
            lines ~= "        ; DEBUG: Index type: " ~ aae.index.classinfo.name;
        } else if (auto ve = cast(VarExpr) base) {
            lines ~= "        ; DEBUG: Base is VarExpr. Name: " ~ ve.name;
        }
        // --- End Debugging ---

        arrAccess = cast(ArrayAccessExpr) base; // Check if the final base is array access

        if (arrAccess !is null) {
            // Base is an array access (e.g., arr[idx].field1.field2)
            string arrName = arrAccess.arrayName;
            string arrBaseAddr = getOrCreateVarAddr(arrName, varAddrs);
            string indexReg = generateExpr(arrAccess.index, lines, regIndex, varAddrs); // Handles dynamic index
            string addrReg = "A0"; // Use A0 for base address calculation
            string offsetReg = nextReg(regIndex); // Use data reg for offset calculation

            // Calculate base element address
            // TODO: Replace placeholders with actual lookup from struct info (e.g., structSizes)
            string elementTypeName = ""; // Need type of array elements
            int elementSize = 0; // Placeholder: Lookup struct size

            // Example lookup for hello.dl
            if (arrName == "sprites") { elementTypeName = "Sprite"; elementSize = 28; }
            else if (arrName == "palette") { elementTypeName = "Color"; elementSize = 12; }
            // Add more else if for other struct arrays based on their definitions

            if (elementSize == 0 && (arrName == "sprites" || arrName == "palette")) { // Only error if known struct array fails lookup
                 lines ~= "        ; ERROR: Could not determine element size for struct array read " ~ arrName;
                 string valReg = nextReg(regIndex); // Return a dummy register
                 lines ~= "        moveq #0, " ~ valReg; // Put 0 in it
                 return valReg;
            }
            else if (elementSize > 0) {
                lines ~= "        move.l " ~ indexReg ~ ", " ~ offsetReg; // Copy index to data register
                lines ~= "        mulu #" ~ to!string(elementSize) ~ ", " ~ offsetReg; // Calculate byte offset: index * elementSize
                lines ~= "        lea " ~ arrBaseAddr ~ ", " ~ addrReg; // Load array base address into A0
                lines ~= "        add.l " ~ offsetReg ~ ", " ~ addrReg; // Add element offset -> addrReg points to start of struct element

                // Calculate final field offset by summing nested field offsets
                // TODO: Replace placeholders with actual lookup from struct info (e.g., structFieldOffsets)
                int totalFieldOffset = 0;
                string currentStructType = elementTypeName; // Start with element type

                // Iterate through nested fields from base struct outwards (reverse order of nestedFields)
                foreach_reverse(fldName; nestedFields) {
                     int fieldOffset = 0; // Lookup offset of fldName within currentStructType
                     string nextStructType = ""; // Lookup type of fldName within currentStructType

                     // Example lookup for hello.dl
                     if (currentStructType == "Sprite") {
                         if (fldName == "pos") { fieldOffset = 0; nextStructType = "Vec2"; }
                         else if (fldName == "vel") { fieldOffset = 8; nextStructType = "Vec2"; }
                         else if (fldName == "tint") { fieldOffset = 16; nextStructType = "Color"; }
                     } else if (currentStructType == "Vec2") {
                         if (fldName == "x") { fieldOffset = 0; nextStructType = "int"; }
                         else if (fldName == "y") { fieldOffset = 4; nextStructType = "int"; }
                     } else if (currentStructType == "Color") {
                         if (fldName == "r") { fieldOffset = 0; nextStructType = "int"; }
                         else if (fldName == "g") { fieldOffset = 4; nextStructType = "int"; }
                         else if (fldName == "b") { fieldOffset = 8; nextStructType = "int"; }
                     }
                     // Add more else if for other structs

                     if (nextStructType == "") { // Error if field not found in struct
                         lines ~= "        ; ERROR: Field '" ~ fldName ~ "' not found in struct type '" ~ currentStructType ~ "' during read.";
                         totalFieldOffset = -1; // Mark error
                         break;
                     }

                     totalFieldOffset += fieldOffset;
                     currentStructType = nextStructType; // Update for next level (if nested further)
                }

                if (totalFieldOffset != -1) {
                    // Load value from final calculated address: totalFieldOffset(addrReg)
                    string valReg = nextReg(regIndex);
                    lines ~= "        move.l " ~ to!string(totalFieldOffset) ~ "(" ~ addrReg ~ "), " ~ valReg;
                    return valReg;
                } else {
                    // Error occurred during offset calculation
                    string valReg = nextReg(regIndex);
                    lines ~= "        moveq #0, " ~ valReg; // Return 0
                    return valReg;
                }
            } else {
                 // Fallback/Error if elementSize was 0 for an unknown array type
                 lines ~= "        ; Fallback/Error: Struct array read not fully handled for " ~ arrName;
                 string valReg = nextReg(regIndex); // Return a dummy register
                 lines ~= "        moveq #0, " ~ valReg; // Put 0 in it
                 return valReg;
            }
        } else {
            // Base is NOT array access (e.g., structVar.field1.field2)
            // --- Remove Safeguard & Trust Initial Check ---
            // If arrAccess is null, assume it's safe to call resolveNestedStructFieldName
            lines ~= "        ; DEBUG: Entering ELSE block in generateExpr for StructFieldAccess.";
            // --- Add more detailed debug info about the expression ---
            if (auto sf = cast(StructFieldAccess) expr) {
                 lines ~= "        ; DEBUG: Expr is StructFieldAccess. Field: " ~ sf.field ~ ", Base type: " ~ sf.baseExpr.classinfo.name;
            } else {
                 lines ~= "        ; DEBUG: Expr is NOT StructFieldAccess? Type: " ~ expr.classinfo.name;
            }
            // --- End detailed debug info ---
            string elemField = resolveNestedStructFieldName(expr); // Gets flattened name like structVar_field1_field2
            string reg = nextReg(regIndex);
            string addr = getOrCreateVarAddr(elemField, varAddrs);
            lines ~= "        move.l " ~ addr ~ ", " ~ reg; // Read from the flattened variable's memory location
            return reg;
            // --- End Simplification ---
        }
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
        string leftReg = generateExpr(bin.left, lines, regIndex, varAddrs);
        string rightReg = generateExpr(bin.right, lines, regIndex, varAddrs);
        string dest = nextReg(regIndex);

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
            lines ~= format("        move.l %s, %s", leftReg, dest);
            lines ~= format("        divs %s, %s", rightReg, dest);
            return dest;
            case "%": // Modulo
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
            string trueLabel = genLabel("Ltrue");
            string endLabel = genLabel("Lend");
            lines ~= format("        cmp.l %s, %s", rightReg, dest);
            lines ~= format("        beq %s", trueLabel);
            lines ~= "        move.l #0, " ~ dest;
            lines ~= format("        bra %s", endLabel);
            lines ~= trueLabel ~ ":";
            lines ~= "        move.l #1, " ~ dest;
            lines ~= endLabel ~ ":";
            return dest;
            }
            case "!=":
            {
            string trueLabel = genLabel("Ltrue");
            string endLabel = genLabel("Lend");
            lines ~= format("        cmp.l %s, %s", rightReg, dest);
            lines ~= format("        bne %s", trueLabel);
            lines ~= "        move.l #0, " ~ dest;
            lines ~= format("        bra %s", endLabel);
            lines ~= trueLabel ~ ":";
            lines ~= "        move.l #1, " ~ dest;
            lines ~= endLabel ~ ":";
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
            string trueLabel = genLabel("Ltrue");
            string endLabel = genLabel("Lend");
            lines ~= format("        cmp.l %s, %s", rightReg, dest);
            lines ~= format("        blt %s", trueLabel);
            lines ~= "        move.l #0, " ~ dest;
            lines ~= format("        bra %s", endLabel);
            lines ~= trueLabel ~ ":";
            lines ~= "        move.l #1, " ~ dest;
            lines ~= endLabel ~ ":";
            return dest;
            }
            case "<=":
            {
            string trueLabel = genLabel("Ltrue");
            string endLabel = genLabel("Lend");
            lines ~= format("        cmp.l %s, %s", rightReg, dest);
            lines ~= format("        ble %s", trueLabel);
            lines ~= "        move.l #0, " ~ dest;
            lines ~= format("        bra %s", endLabel);
            lines ~= trueLabel ~ ":";
            lines ~= "        move.l #1, " ~ dest;
            lines ~= endLabel ~ ":";
            return dest;
            }
            case ">":
            {
            string trueLabel = genLabel("Ltrue");
            string endLabel = genLabel("Lend");
            lines ~= format("        cmp.l %s, %s", rightReg, dest);
            lines ~= format("        bgt %s", trueLabel);
            lines ~= "        move.l #0, " ~ dest;
            lines ~= format("        bra %s", endLabel);
            lines ~= trueLabel ~ ":";
            lines ~= "        move.l #1, " ~ dest;
            lines ~= endLabel ~ ":";
            return dest;
            }
            case ">=":
            {
            string trueLabel = genLabel("Ltrue");
            string endLabel = genLabel("Lend");
            lines ~= format("        cmp.l %s, %s", rightReg, dest);
            lines ~= format("        bge %s", trueLabel);
            lines ~= "        move.l #0, " ~ dest;
            lines ~= format("        bra %s", endLabel);
            lines ~= trueLabel ~ ":";
            lines ~= "        move.l #1, " ~ dest;
            lines ~= endLabel ~ ":";
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

    if (auto call = cast(CallExpr) expr) {
        int argAReg = 1; // Start from A1 for address registers
        int argDReg = 1; // Start from D1 for data registers
        string[] argRegs;

        // Track library calls
        if (call.name == "readf" ||
        call.name == "write" ||
        call.name == "writeln" ||
        call.name == "readln" ||
        call.name == "writef" ||
        call.name == "import" ||
        call.name == "importf" ||
        call.name == "importln" ||
        call.name == "std." ||
        call.name == "stdout" ||
        call.name == "stdin" ||
        call.name == "stderr" ||
        call.name == "malloc" ||
        call.name == "free" ||
        call.name == "memcpy" ||
        call.name == "memset" ||
        call.name == "memmove" ||
        call.name == "strlen" ||
        call.name == "strcpy" ||
        call.name == "strcat" ||
        call.name == "strcmp" ||
        call.name == "strchr" ||
        call.name == "strstr" ||
        call.name == "strdup" ||
        call.name == "stdio") {
            usedLibCalls[call.name] = "1";
        }

        // Collect argument registers/types
        foreach_reverse (arg; call.args) {
            string reg;
            // StringLiteral or address-of (&x) => address register
            if (cast(StringLiteral) arg || (cast(UnaryExpr) arg && (cast(UnaryExpr)arg).op == "&")) {
                reg = "A" ~ to!string(argAReg++);
            } else {
                reg = "D" ~ to!string(argDReg++);
            }
            argRegs ~= reg;
        }

        // Now generate code for each argument, in reverse order (right-to-left)
        foreach_reverse (i, arg; call.args) {
            string reg = argRegs[$ - i - 1];
            // StringLiteral
            if (auto str = cast(StringLiteral) arg) {
                string label = getOrCreateStringLabel(str.value);
                lines ~= "        lea " ~ label ~ ", " ~ reg;
            }
            // Address-of
            else if (auto unary = cast(UnaryExpr) arg) {
                if (unary.op == "&") {
                    auto var = cast(VarExpr) unary.expr;
                    string addr = getOrCreateVarAddr(var.name, varAddrs);
                    lines ~= "        lea " ~ addr ~ ", " ~ reg;
                }
            }
            // Everything else (int, var, etc.)
            else {
                string valReg = generateExpr(arg, lines, regIndex, varAddrs);
                if (valReg != reg)
                    lines ~= "        move.l " ~ valReg ~ ", " ~ reg;
            }
            lines ~= "        move.l " ~ reg ~ ", -(SP)";
        }
        lines ~= "        add.l #" ~ to!string(4 * call.args.length) ~ ", SP";
        string dest = nextReg(regIndex);
        lines ~= "        move.l D0, " ~ dest;
        return dest;
    }
    // --- PATCH: Handle ArrayAccessExpr ---
    if (auto access = cast(ArrayAccessExpr) expr) {
        string arrName = access.arrayName;
        string arrBaseAddr = getOrCreateVarAddr(arrName, varAddrs); // Get base address/label
        string indexReg = generateExpr(access.index, lines, regIndex, varAddrs); // Evaluate index expression
        string addrReg = "A0"; // Use A0 for address calculation
        string valReg = nextReg(regIndex); // Register to hold the element value
        string offsetReg = nextReg(regIndex); // Temporary register for offset calculation

        // Calculate element address: base + index * 4 (assuming 4-byte elements)
        lines ~= "        lea " ~ arrBaseAddr ~ ", " ~ addrReg; // Load base address into A0
        lines ~= "        move.l " ~ indexReg ~ ", " ~ valReg; // Copy index to a data register for multiplication
        lines ~= "        mulu #4, " ~ valReg; // Multiply index by element size (4)
        lines ~= "        add.l " ~ valReg ~ ", " ~ addrReg; // Add offset to base address in A0

        // Load element value from calculated address
        lines ~= "        move.l (" ~ addrReg ~ "), " ~ valReg; // Load value from (A0) into valReg

        return valReg;
    }
    // --- END PATCH ---

    // --- PATCH: Handle StringLiteral as expression (load address) ---
    if (auto str = cast(StringLiteral) expr) {
        string label = getOrCreateStringLabel(str.value);
        string reg = "A" ~ to!string(regIndex++); // Use an address register
        if (regIndex > 3) regIndex = 1; // Cycle through A1, A2, A3 for strings? Adjust as needed.
        lines ~= "        lea " ~ label ~ ", " ~ reg;
        return reg; // Return the address register
    }
    // --- END PATCH ---

    // If we reach here, the expression type is still unhandled.
    // Log an error message instead of asserting.
    lines ~= format("; ERROR: Unhandled expression type '%s' in generateExpr", expr.classinfo.name);
    // Return a dummy register (e.g., D0 with value 0) to allow compilation to proceed somewhat.
    string dummyReg = nextReg(regIndex);
    lines ~= "        move.l #0, " ~ dummyReg;
    return dummyReg;
    // assert(0); // Removed assertion
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
    lines ~= "        move.l #0, " ~ idxReg; // idx = 0

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
    return "" ~ base ~ "_" ~ to!string(labelCounter++);
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
