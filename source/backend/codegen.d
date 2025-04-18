module backend.codegen;

import ast.nodes;
import std.conv : to;
import std.array;
import std.string;

int labelCounter = 0;

string generateCode(ASTNode[] nodes) {
    string[] lines;
    lines ~= "        ORG $1000";
    lines ~= "main:";

    int regIndex = 1;
    string[string] varRegs;

    foreach (node; nodes) {
        generateStmt(node, lines, regIndex, varRegs);
    }

    lines ~= "        END";
    return lines.join("\n");
}

void generateStmt(ASTNode node, ref string[] lines, ref int regIndex, ref string[string] varRegs) {
    if (auto decl = cast(VarDecl) node) {
        string reg = generateExpr(decl.value, lines, regIndex, varRegs);
        varRegs[decl.name] = reg;
    }
    else if (auto assign = cast(AssignStmt) node) {
        string reg = generateExpr(assign.value, lines, regIndex, varRegs);
        varRegs[assign.name] = reg;
        // Optional: store to memory or just track in reg
    }
    else if (auto ret = cast(ReturnStmt) node) {
        string reg = generateExpr(ret.value, lines, regIndex, varRegs);
        lines ~= "        move.l " ~ reg ~ ", D0 ; return";
        lines ~= "        rts";
    }
    else if (auto ifstmt = cast(IfStmt) node) {
        string labelEnd = genLabel("endif");

        // Compare condition
        string condReg = generateExpr(ifstmt.condition, lines, regIndex, varRegs);
        lines ~= "        cmp.l #0, " ~ condReg;
        lines ~= "        beq " ~ labelEnd;

        // Emit body
        foreach (s; ifstmt.thenBody) {
            generateStmt(s, lines, regIndex, varRegs);
        }

        lines ~= labelEnd ~ ":";
    }
    else if (auto whilestmt = cast(WhileStmt) node) {
        string labelStart = genLabel("while");
        string labelEnd = genLabel("endwhile");

        lines ~= labelStart ~ ":";

        string condReg = generateExpr(whilestmt.condition, lines, regIndex, varRegs);
        lines ~= "        cmp.l #0, " ~ condReg;
        lines ~= "        beq " ~ labelEnd;

        foreach (s; whilestmt.loopBody) {
            generateStmt(s, lines, regIndex, varRegs);
        }

        lines ~= "        bra " ~ labelStart;
        lines ~= labelEnd ~ ":";
    }
}


string generateExpr(ASTNode expr, ref string[] lines, ref int regIndex, string[string] varRegs) {
    if (auto lit = cast(IntLiteral) expr) {
        string reg = "D" ~ to!string(regIndex++);
        lines ~= "        move.l #" ~ to!string(lit.value) ~ ", " ~ reg;
        return reg;
    }
    if (auto var = cast(VarExpr) expr) {
        return varRegs.get(var.name, "D1"); // fallback
    }
    if (auto bin = cast(BinaryExpr) expr) {
        string left = generateExpr(bin.left, lines, regIndex, varRegs);
        string right = generateExpr(bin.right, lines, regIndex, varRegs);

        string dest = "D" ~ to!string(regIndex++);
        string op;

        switch (bin.op) {
            case "+": op = "add.l"; break;
            case "-": op = "sub.l"; break;
            case "*": op = "muls";  break;
            case "/": op = "divs";  break;
            default: op = "add.l"; break;
        }

        lines ~= "        move.l " ~ left ~ ", " ~ dest;
        lines ~= "        " ~ op ~ " " ~ right ~ ", " ~ dest;
        return dest;
    }

    return "#0";
}

string genLabel(string base) {
    return "." ~ base ~ "_" ~ to!string(labelCounter++);
}

