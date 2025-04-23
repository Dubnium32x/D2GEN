module backend.codegen;

import ast.nodes;
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
string[string] arrayLabels;
string[string] loopVarsUsed;
string[string] usedLibCalls; // acts as a set

string generateCode(ASTNode[] nodes) {
    string[] lines;

    lines ~= "** GENERATED CODE USING DLANG AND D2GEN COMPILER **";
    lines ~= "        ORG $1000";
    lines ~= "        JMP main"; // jump to main, regardless of function order

    int regIndex = 1;
    string[string] varAddrs;

    FunctionDecl[] functions;

    // Gather all functions
    foreach (node; nodes) {
        if (auto fn = cast(FunctionDecl) node) {
            functions ~= fn;
        }
    }

    // Emit all functions (main will be jumped to anyway)
    foreach (func; functions) {
        generateFunction(func, lines, regIndex, varAddrs);
    }

    // Emit all unique string literals (once)
    lines ~= "";
    lines ~= "        ; String literals";
    foreach (val, label; strLabels) {
        lines ~= label ~ ":";
        lines ~= format("        dc.b \'%s\', 0", val);
    }

    // Emit array memory (once)
    lines ~= "        ; Array storage";
    foreach (name, base; globalArrays) {
        foreach (i; 0 .. 10) { // or use known array length if tracked
            lines ~= base ~ "_" ~ to!string(i) ~ ":    ds.l 1";
        }
    }

    // Emit all loop variables (once)
    lines ~= "        ; Loop variables";
    foreach (name, _; loopVarsUsed) {
        lines ~= name ~ ":    ds.l 1";
    }
    
    // Emit all scalar variables (once)
    lines ~= "        ; Scalar variables";
    foreach (name, _; emittedVars) {
        // Avoid redeclaring loop variables
        if (!(name in loopVarsUsed)) {
            lines ~= name ~ ":    ds.l 1";
        }
    }

    // Emit array labels (once)
    lines ~= "        ; Array labels";
    foreach (name, label; arrayLabels) {
        lines ~= label ~ ":    ds.l 1";
    }

    foreach (lib; usedLibCalls.keys) {
        lines ~= "";
        lines ~= lib ~ ":";
        lines ~= "    rts";
    }

    lines ~= "        END";
    return lines.join("\n");
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
        string reg = (i == 0) ? "D0" : nextReg(regIndex);
        lines ~= format("        move.l %d(A6), %s", offset, reg);
        localVarAddrs[param] = reg; // Map param name to register
        offset += 4;
    }

    foreach (stmt; func.funcBody) {
        generateStmt(stmt, lines, regIndex, localVarAddrs);
    }

    lines ~= "        ; Function epilogue";
    lines ~= "        move.l A6, SP";
    lines ~= "        move.l (SP)+, A6";
    lines ~= "        rts";
}

void generateStmt(ASTNode node, ref string[] lines, ref int regIndex, ref string[string] varAddrs) {
    regIndex = 1;

    if (auto decl = cast(VarDecl) node) {
        string addr = getOrCreateVarAddr(decl.name, varAddrs);

        final switch (decl.type) {
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
            string valReg = generateExpr(assign.value, lines, regIndex, varAddrs);
            string indexReg = generateExpr(access.index, lines, regIndex, varAddrs);

            // Calculate offset: index * 4 (for 32-bit ints)
            string offsetReg = nextReg(regIndex);
            lines ~= "        move.l " ~ indexReg ~ ", " ~ offsetReg;
            lines ~= "        mulu #4, " ~ offsetReg;

            // Get base address of array
            string baseAddr = getOrCreateVarAddr(access.arrayName, varAddrs);
            lines ~= "        lea " ~ baseAddr ~ ", A0";

            // Store value at (A0, offsetReg.l)
            lines ~= "        move.l " ~ valReg ~ ", (A0, " ~ offsetReg ~ ".l)";
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
        lines ~= "        bra end_loop";
    }
    else if (auto contstmt = cast(ContinueStmt) node) {
        lines ~= "        bra start_loop";
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
        string labelEnd = genLabel("endwhile");

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

        if (!(arr.name in declaredArrays)) {
            for (int i = 0; i < arr.elements.length; i++) {
                string reg = generateExpr(arr.elements[i], lines, regIndex, varAddrs);
                string label = base ~ "_" ~ to!string(i);
                lines ~= format("        move.l %s, %s", reg, label);
            }
            lines ~= base ~ "_len:    dc.l " ~ to!string(arr.elements.length);
            declaredArrays[arr.name] = base;
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
        string condReg = "D0";
        string[] caseLabels;
        string defaultLabel = endLabel;

        foreach (i, cNode; sw.cases) {
            auto c = cast(CaseStmt) cNode;
            string label = genLabel("case_" ~ to!string(i));
            caseLabels ~= label;

            if (c.condition !is null) {
                // If the case value is a constant, use immediate
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

            foreach (stmt; c.caseBody) {
                generateStmt(stmt, lines, regIndex, varAddrs);
            }
            lines ~= "        bra " ~ endLabel;
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

        lines ~= "        bsr " ~ call.name;
        lines ~= "        add.l #" ~ to!string(4 * call.args.length) ~ ", SP";
    }
}

void generateForeachStmt(ForeachStmt node, ref string[] lines, ref int regIndex, ref string[string] varAddrs) {
    string loopLabel = genLabel("foreach");
    string endLabel = genLabel("end_foreach");
    
    // Get clean variable names (without declarations)
    string counterVar = getCleanVarName(node.varName ~ "_counter");
    string loopVar = getCleanVarName(node.varName);
    string charBuf = getCleanVarName("char_buffer");
    // Initialize loop (range 1..5)
    lines ~= "        ; Initialize foreach loop (" ~ node.varName ~ ")";
    lines ~= "        move.l #1, D1          ; Start value";
    lines ~= "        move.l #5, D2          ; End value";
    lines ~= "        move.l D1, (" ~ counterVar ~ ") ; Store initial value";
    
    // Loop start
    lines ~= loopLabel ~ ":";
    lines ~= "        ; Check loop condition";
    lines ~= "        cmp.l D2, D1";
    lines ~= "        bge " ~ endLabel;
    
    // Store current value in loop variable
    lines ~= "        move.l D1, (" ~ loopVar ~ ") ; Update " ~ node.varName;
    
    // Generate loop body
    lines ~= "        ; === Loop body begin ===";
    foreach (stmt; node.forEachBody) {
        generateStmt(stmt, lines, regIndex, varAddrs);
    }
    lines ~= "        ; === Loop body end ===";
    
    // Increment and loop
    lines ~= "        ; Update loop counter";
    lines ~= "        addq.l #1, D1          ; " ~ node.varName ~ "++";
    lines ~= "        move.l D1, (" ~ counterVar ~ ") ; Store updated value";
    lines ~= "        bra " ~ loopLabel;
    
    // Track loop variable and counter variable
    loopVarsUsed[loopVar] = "1";
    loopVarsUsed[counterVar] = "1";

    // End label
    lines ~= endLabel ~ ":";
    lines ~= "        ; Foreach loop complete";
    
    // Reset register counter if needed
    regIndex = 1;
    lines ~= "        ; Clean up foreach loop variables";
    lines ~= "        ; Reset register counter if needed";
    regIndex = 1;
}

// Helper to get clean variable name
string getCleanVarName(string name) {
    return "var_" ~ name;
}

string getCleanArrayName(string name) {
    return "arr_" ~ name;
}

// Helper to declare variables in data section
void declareVarIfNeeded(string fullName, string type, ref string[] lines, ref string[string] varAddrs) {
    if (!(fullName in varAddrs)) {
        varAddrs[fullName] = fullName;
        
        // Find where to insert the declaration (before END)
        bool inserted = false;
        foreach (i, line; lines) {
            if (line.strip() == "END") {
                import std.array : insertInPlace;
                lines.insertInPlace(i, fullName ~ ": " ~ type);
                inserted = true;
                break;
            }
        }
        
        // If END not found, append to end
        if (!inserted) {
            lines ~= fullName ~ ": " ~ type;
        }
    }
}

void declareArrayIfNeeded(string fullName, string type, ref string[] lines, ref string[string] varAddrs) {
    if (!(fullName in varAddrs)) {
        varAddrs[fullName] = fullName;
        
        // Find where to insert the declaration (before END)
        bool inserted = false;
        foreach (i, line; lines) {
            if (line.strip() == "END") {
                import std.array : insertInPlace;
                lines.insertInPlace(i, fullName ~ ": " ~ type);
                inserted = true;
                break;
            }
        }
        
        // If END not found, append to end
        if (!inserted) {
            lines ~= fullName ~ ": " ~ type;
        }
    }
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

        lines ~= "        bsr " ~ call.name;
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
            // add to the array label map
            if (!(access.arrayName in arrayLabels)) {
                arrayLabels[access.arrayName] = label;
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
        map[name] = "var_" ~ name;
        emittedVars["var_" ~ name] = "1"; // Track for data section
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

