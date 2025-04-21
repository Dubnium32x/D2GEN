module backend.codegen;

import ast.nodes;
import std.conv : to;
import std.array;
import std.string;
import std.algorithm : map;
import std.format : format;

int labelCounter = 0;
string[string] strLabels;
int strLabelCounter = 0;

string generateCode(ASTNode[] nodes) {
    string[] lines;
    lines ~= "        ORG $1000";
    lines ~= "main:";

    int regIndex = 1;
    string[string] varAddrs;

    foreach (node; nodes) {
        generateStmt(node, lines, regIndex, varAddrs);
    }

    lines ~= "        rts";

    // Variable declarations
    lines ~= "";
    foreach (name, addr; varAddrs) {
        lines ~= addr ~ ":    ds.l 1";
    }

    // String constants
    if (strLabels.length > 0) {
        lines ~= "";
        foreach (val, label; strLabels) {
            lines ~= label ~ ":";
            lines ~= "        dc.b '" ~ val ~ "'";
            lines ~= "        dc.b 0";
        }
    }

    // === Emit array contents ===
    foreach (name, label; varAddrs) {
        if (label.startsWith(".arr_")) {
            foreach (i; 0 .. 10) { // or use arrayDecl.elements.length
                string elemLabel = label ~ "_" ~ to!string(i);
                lines ~= elemLabel ~ ":    dc.l 0";
            }
        }
    }


    lines ~= "        END";
    return lines.join("\n");
}

void generateStmt(ASTNode node, ref string[] lines, ref int regIndex, ref string[string] varAddrs) {
    regIndex = 1;

    if (auto decl = cast(VarDecl) node) {
        if (decl.type == "byte") {
            string valReg = generateExpr(decl.value, lines, regIndex, varAddrs);
            string addr = getOrCreateVarAddr(decl.name, varAddrs);
            lines ~= format("        move.b %s, %s", valReg, addr);
        } else if (decl.type == "int") {
            string valReg = generateExpr(decl.value, lines, regIndex, varAddrs);
            string addr = getOrCreateVarAddr(decl.name, varAddrs);
            lines ~= "        move.l " ~ valReg ~ ", " ~ addr;
        }
    }
    else if (auto assign = cast(AssignStmt) node) {
            string valReg = generateExpr(assign.value, lines, regIndex, varAddrs);
            string addr = getOrCreateVarAddr(assign.name, varAddrs);
            lines ~= "        move.l " ~ valReg ~ ", " ~ addr;
    }
    else if (auto ret = cast(ReturnStmt) node) {
        string reg = generateExpr(ret.value, lines, regIndex, varAddrs);
        lines ~= "        move.l " ~ reg ~ ", D0 ; return";
    }
    else if (auto ifstmt = cast(IfStmt) node) {
        string labelElse = genLabel("else");
        string labelEnd = genLabel("endif");

        string condReg = generateExpr(ifstmt.condition, lines, regIndex, varAddrs);
        lines ~= "        cmp.l #0, " ~ condReg;
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
        string baseLabel = ".arr_" ~ arr.name;

        varAddrs[arr.name] = baseLabel; // Register array base address

        int i = 0;
        foreach (elem; arr.elements) {
            string reg = generateExpr(elem, lines, regIndex, varAddrs);
            string label = baseLabel ~ "_" ~ to!string(i);
            lines ~= format("        move.l %s, %s", reg, label);
            i++;
        }

        // Store array length label if you want `length`
        lines ~= format("%s_len:    dc.l %d", baseLabel, arr.elements.length);
    }
    else if (auto print = cast(PrintStmt) node) {
        if (auto str = cast(StringLiteral) print.value) {
            string label = getOrCreateStringLabel(str.value);
            lines ~= "        lea " ~ label ~ ", A1";
            lines ~= "        move.b #9, D0";
            lines ~= "        trap #15";

        }
        else {
            string reg = generateExpr(print.value, lines, regIndex, varAddrs);
            lines ~= "        move.l " ~ reg ~ ", D1";
            lines ~= "        move.b #1, D0";
            lines ~= "        trap #15";
        }
    }
    else if (auto sw = cast(SwitchStmt) node) {
        string endLabel = genLabel("switch_end");
        string condReg = generateExpr(sw.condition, lines, regIndex, varAddrs);
        string[] caseLabels;
        string defaultLabel = endLabel;

        // Emit comparisons and branches
        foreach (i, cNode; sw.cases) {
            auto c = cast(CaseStmt) cNode;
            string label = genLabel("case_" ~ to!string(i));
            caseLabels ~= label;

            if (c.condition !is null) {
                string caseValReg = generateExpr(c.condition, lines, regIndex, varAddrs);
                lines ~= "        cmp.l " ~ caseValReg ~ ", " ~ condReg;
                lines ~= "        beq " ~ label;
            } else {
                // This is the default case
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
    
    // End label
    lines ~= endLabel ~ ":";
    lines ~= "        ; Foreach loop complete";
    
    // Reset register counter if needed
    regIndex = 1;
    
    lines ~= "        ; Clean up foreach loop variables";

    lines ~= format("%s:    ds.l 1 ; Clean up counter variable", counterVar);
    lines ~= format("%s:    ds.l 1 ; Clean up char buffer", charBuf);

    lines ~= "        ; Reset register counter if needed";
    regIndex = 1;
}

// Helper to get clean variable name
string getCleanVarName(string name) {
    return ".var_" ~ name;
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

    if (auto var = cast(VarExpr) expr) {
        string reg = nextReg(regIndex);
        string addr = getOrCreateVarAddr(var.name, varAddrs);
        lines ~= "        move.l " ~ addr ~ ", " ~ reg;
        return reg;
    }

    if (auto bin = cast(BinaryExpr) expr) {
        string left = generateExpr(bin.left, lines, regIndex, varAddrs);
        string right = generateExpr(bin.right, lines, regIndex, varAddrs);
        string dest = nextReg(regIndex);

        final switch (bin.op) {
            case "+": lines ~= format("        move.l %s, %s", left, dest);
                      lines ~= format("        add.l %s, %s", right, dest); break;
            case "-": lines ~= format("        move.l %s, %s", left, dest);
                      lines ~= format("        sub.l %s, %s", right, dest); break;
            case "*": lines ~= format("        move.l %s, %s", left, dest);
                      lines ~= format("        muls %s, %s", right, dest); break;
            case "/": lines ~= format("        move.l %s, %s", left, dest);
                      lines ~= format("        divs %s, %s", right, dest); break;
            case "<": lines ~= format("        cmp.l %s, %s", right, left);
                      lines ~= "        slt " ~ dest; break;
            case "<=": lines ~= format("        cmp.l %s, %s", right, left);
                       lines ~= "        sle " ~ dest; break;
            case ">": lines ~= format("        cmp.l %s, %s", left, right);
                      lines ~= "        slt " ~ dest; break;
            case ">=": lines ~= format("        cmp.l %s, %s", left, right);
                       lines ~= "        sle " ~ dest; break;
            case "!=": lines ~= format("        cmp.l %s, %s", right, left);
                       lines ~= "        sne " ~ dest; break;
            case "==": lines ~= format("        cmp.l %s, %s", right, left);
                       lines ~= "        seq " ~ dest; break;
        }

        return dest;
    }
    if (auto blit = cast(ByteLiteral) expr) {
        string reg = nextReg(regIndex);
        lines ~= "        move.b #" ~ to!string(blit.value) ~ ", " ~ reg;
        return reg;
    }
    // Removed invalid block referencing undefined variables

    return "#0";
}

string nextReg(ref int regIndex) {
    if (regIndex > 7) throw new Exception("Out of registers");
    return "D" ~ to!string(regIndex++);
}

string genLabel(string base) {
    return "." ~ base ~ "_" ~ to!string(labelCounter++);
}

string getOrCreateVarAddr(string name, ref string[string] map) {
    if (!(name in map)) {
        map[name] = ".var_" ~ name;
    }
    return map[name];
}

string getOrCreateStringLabel(string val) {
    if (!(val in strLabels)) {
        strLabels[val] = ".str_" ~ to!string(strLabelCounter++);
    }
    return strLabels[val];
}
