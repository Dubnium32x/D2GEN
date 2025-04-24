module backend.codegen;

import ast.nodes;
import globals;
import std.conv : to;
import std.array;
import std.stdio;
import std.string;
import std.algorithm : map;
import std.format : format;

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
                // Emit a base label for arrays of structs if public
                if (decl.type.endsWith("]")) {
                    import std.regex : matchFirst;
                    auto m = decl.type.matchFirst(`([A-Za-z_][A-Za-z0-9_]*)\\[(\\d+)\\]`);
                    if (!m.empty && m.captures.length == 3) {
                        string structType = m.captures[1];
                        if (structType in structFieldOffsets) {
                            string arrayLabel = decl.name ~ ":";
                            if (!(arrayLabel in emittedSymbols)) {
                                lines ~= arrayLabel;
                                emittedSymbols[arrayLabel] = "1";
                            }
                        }
                    }
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
                // Emit a base label for arrays of structs if public
                if (decl.type.endsWith("]")) {
                    import std.regex : matchFirst;
                    auto m = decl.type.matchFirst(`([A-Za-z_][A-Za-z0-9_]*)\\[(\\d+)\\]`);
                    if (!m.empty && m.captures.length == 3) {
                        string structType = m.captures[1];
                        if (structType in structFieldOffsets) {
                            string arrayLabel = decl.name ~ ":";
                            if (!(arrayLabel in emittedSymbols)) {
                                lines ~= arrayLabel;
                                emittedSymbols[arrayLabel] = "1";
                            }
                        }
                    }
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
        // Assignment to variable
        if (auto var = cast(VarExpr) assign.lhs) {
            string valReg = generateExpr(assign.value, lines, regIndex, varAddrs);
            string addr = getOrCreateVarAddr(var.name, varAddrs);
            lines ~= "        move.l " ~ valReg ~ ", " ~ addr;
        }
        // Assignment to array element
        else if (auto access = cast(ArrayAccessExpr) assign.lhs) {
            // Special case: array of function pointers assignment
            if (varTypes.get(access.arrayName, "").startsWith("void function(")) {
                // Only support constant index for now
                if (auto intLit = cast(IntLiteral) access.index) {
                    string label = access.arrayName ~ "_" ~ to!string(intLit.value);
                    string valReg = generateExpr(assign.value, lines, regIndex, varAddrs);
                    // If assigning &func, valReg will be an address register (A1, etc.)
                    // Move the address to the slot
                    lines ~= "        move.l " ~ valReg ~ ", " ~ label;
                } else {
                    lines ~= "; ERROR: Only constant indices supported for function pointer array assignment";
                }
            } else {
                string valReg = generateExpr(assign.value, lines, regIndex, varAddrs);
                string indexReg = generateExpr(access.index, lines, regIndex, varAddrs);
                string offsetReg = nextReg(regIndex);
                lines ~= "        move.l " ~ indexReg ~ ", " ~ offsetReg;
                lines ~= "        mulu #4, " ~ offsetReg;
                string baseAddr = getOrCreateVarAddr(access.arrayName, varAddrs);
                lines ~= "        lea " ~ baseAddr ~ ", A0";
                lines ~= "        move.l " ~ valReg ~ ", (A0, " ~ offsetReg ~ ".l)";
            }
        }
        else if (auto field = cast(StructFieldAccess) assign.lhs) {
            string elemField = resolveNestedStructFieldName(assign.lhs);
            string valReg = generateExpr(assign.value, lines, regIndex, varAddrs);
            string addr = getOrCreateVarAddr(elemField, varAddrs);
            lines ~= "        move.l " ~ valReg ~ ", " ~ addr;
        }
        else {
            throw new Exception("Left-hand side of assignment must be a variable or array element");
        }
    }
    else if (auto ret = cast(ReturnStmt) node) {
        string reg = generateExpr(ret.value, lines, regIndex, varAddrs);
        if (reg != "D0") lines ~= "        move.l " ~ reg ~ ", D0 ; return";
    }
    else if (auto breakstmt = cast(BreakStmt) node) {
        lines ~= "        bra " ~ breakLabel;
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
        generateExpr(exprStmt.expr, lines, regIndex, varAddrs);
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
            throw new Exception("Only constant indices supported for struct array field access");
        }
    } else if (auto var = cast(VarExpr) node) {
        return var.name;
    }
    return "";
}

string generateExpr(ASTNode expr, ref string[] lines, ref int regIndex, string[string] varAddrs) {
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

    if (auto field = cast(StructFieldAccess) expr) {
        // Handle arr[index].field for struct arrays
        if (auto arrAccess = cast(ArrayAccessExpr) field.baseExpr) {
            // Only support constant index for now
            if (auto intLit = cast(IntLiteral) arrAccess.index) {
                string elemField = arrAccess.arrayName ~ "_" ~ to!string(intLit.value) ~ "_" ~ field.field;
                string reg = nextReg(regIndex);
                string addr = getOrCreateVarAddr(elemField, varAddrs);
                lines ~= "        move.l " ~ addr ~ ", " ~ reg;
                return reg;
            } else {
                lines ~= "; ERROR: Only constant indices supported for struct array field access";
                // Return a dummy register to allow codegen to continue
                string reg = nextReg(regIndex);
                lines ~= "        move.l #0, " ~ reg;
                return reg;
            }
        }
        // Nested struct field access
        else {
            string elemField = resolveNestedStructFieldName(expr);
            string reg = nextReg(regIndex);
            string addr = getOrCreateVarAddr(elemField, varAddrs);
            lines ~= "        move.l " ~ addr ~ ", " ~ reg;
            return reg;
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

    if (auto blit = cast(ByteLiteral) expr) {
        string reg = nextReg(regIndex);
        lines ~= "        move.b #" ~ to!string(blit.value) ~ ", " ~ reg;
        return reg;
    }

    if (auto func = cast(FunctionDecl) expr) {
        lines ~= func.name ~ ":";

        foreach (stmt; func.funcBody) {
            generateStmt(stmt, lines, regIndex, varAddrs);
        }

        lines ~= "        rts";
        return "";
    }

    if (auto access = cast(ArrayAccessExpr) expr) {
        // Evaluate the index expression
        string indexReg = generateExpr(access.index, lines, regIndex, varAddrs);

        // If array is constant-indexed, we can optimize
        if (auto intLit = cast(IntLiteral) access.index) {
            string label = access.arrayName ~ "_" ~ to!string(intLit.value);
            string reg = nextReg(regIndex);
            lines ~= "        move.l " ~ label ~ ", " ~ reg;
            // Ensure the label is emitted
            emittedVars[label] = "1";
            // Only emit array base label for primitive/function pointer arrays
            bool isStructArray = false;
            foreach (stype, _; structFieldOffsets) {
                if (access.arrayName == stype || access.arrayName.startsWith(stype ~ "_")) {
                    isStructArray = true;
                    break;
                }
            }
            // FINAL: never add arrPixels to emittedVars or arrayLabels for struct arrays
            if (!isStructArray && !(access.arrayName in arrayLabels)) {
                string base = "arr" ~ capitalize(access.arrayName);
                arrayLabels[access.arrayName] = base;
                emittedVars[base] = "1";
            }
            return reg;
        }

        // Otherwise: dynamic access
        string baseAddr = getOrCreateVarAddr(access.arrayName, varAddrs); // Retrieve the array name properly
        string tmpAddr = nextReg(regIndex);
        string scaledIndex = nextReg(regIndex);

        // Multiply index by 4 to get byte offset (longs)
        lines ~= "        move.l " ~ indexReg ~ ", " ~ scaledIndex;
        lines ~= "        mulu #4, " ~ scaledIndex;

        // Load address of base into a register (assumes label exists)
        lines ~= "        lea " ~ baseAddr ~ ", A0";

        // Offset into array
        lines ~= "        move.l (A0, " ~ scaledIndex ~ ".l), " ~ tmpAddr;

        return tmpAddr;
    }
    if (auto str = cast(StringLiteral) expr) {
        string label = getOrCreateStringLabel(str.value);
        string reg = "A" ~ to!string(regIndex++); // Use A1, A2, etc.
        lines ~= "        lea " ~ label ~ ", " ~ reg;
        return reg;
    }

    if (auto arrLit = cast(ArrayLiteralExpr) expr) {
        foreach (i, elem; arrLit.elements) {
            string valReg = generateExpr(elem, lines, regIndex, varAddrs);
            string label = "arr_" ~ to!string(i);
            lines ~= "        move.l " ~ valReg ~ ", " ~ label;
        }
    }


    return "#0";
}

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

// Foreach loop code generation
void generateForeachStmt(ForeachStmt node, ref string[] lines, ref int regIndex, ref string[string] varAddrs) {
    string loopLabel = genLabel("foreach");
    string endLabel = genLabel("end_foreach");
    string counterVar = "foreach_counter_" ~ to!string(labelCounter++);
    string iterVar = node.varName;

    // Assume iterable is a variable with _len label
    string arrName = (cast(VarExpr)node.iterable).name;
    string lenLabel = arrName ~ "_len";
    string idxReg = nextReg(regIndex);
    string lenReg = nextReg(regIndex);

    // idx = 0
    lines ~= "        move.l #0, " ~ idxReg;
    lines ~= loopLabel ~ ":";
    // if idx >= arr_len goto endLabel
    lines ~= "        move.l " ~ lenLabel ~ ", " ~ lenReg;
    lines ~= "        cmp.l " ~ lenReg ~ ", " ~ idxReg;
    lines ~= "        bge " ~ endLabel;
    // assign arr[idx] to iterVar (assume int for simplicity)
    string elemLabel = arrName ~ "_" ~ idxReg;
    string iterAddr = getOrCreateVarAddr(iterVar, varAddrs);
    lines ~= "        move.l " ~ elemLabel ~ ", " ~ iterAddr;
    // loop body
    foreach (stmt; node.forEachBody) {
        generateStmt(stmt, lines, regIndex, varAddrs);
    }
    // idx++
    lines ~= "        addq.l #1, " ~ idxReg;
    lines ~= "        bra " ~ loopLabel;
    lines ~= endLabel ~ ":";
}
