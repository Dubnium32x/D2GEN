module backend.codegen;

import ast.nodes;
import std.conv : to;
import std.array;

string generateCode(ASTNode[] nodes) {
    string buf = "";
    buf ~= "        ORG $1000\n";
    buf ~= "main:\n";

    int regIndex = 1; // Start with D1 for variables
    string[string] varRegs; // Map variable name → register (e.g. x → D1)

    foreach (node; nodes) {
        if (auto var = cast(VarDecl) node) {
            auto name = var.name;
            auto val = generateExpr(var.value, varRegs, regIndex);
            string reg = "D" ~ to!string(regIndex);
            varRegs[name] = reg;
            buf ~= "        move.l " ~ val ~ ", " ~ reg ~ " ; int " ~ name ~ "\n";
            regIndex++;
        }
        else if (auto ret = cast(ReturnStmt) node) {
            auto val = generateExpr(ret.value, varRegs, regIndex);
            buf ~= "        move.l " ~ val ~ ", D0 ; return\n";
            buf ~= "        rts\n";
        }
    }

    buf ~= "        END\n";
    return buf;
}

string generateExpr(ASTNode expr, string[string] varRegs, int regIndex) {
    if (auto lit = cast(IntLiteral) expr) {
        return "#" ~ to!string(lit.value);
    }
    if (auto var = cast(VarExpr) expr) {
        return varRegs.get(var.name, "D1"); // fallback if not found
    }
    if (auto bin = cast(BinaryExpr) expr) {
        // Simple: put left in D1, apply op with right
        string left = generateExpr(bin.left, varRegs, regIndex);
        string right = generateExpr(bin.right, varRegs, regIndex);

        string result = "D" ~ to!string(regIndex);
        string op;

        switch (bin.op) {
            case "+": op = "add.l"; break;
            case "-": op = "sub.l"; break;
            case "*": op = "muls";  break;
            case "/": op = "divs";  break;
            default: op = "add.l"; break; // fallback
        }

        string buf = "";
        buf ~= "        move.l " ~ left ~ ", " ~ result ~ "\n";
        buf ~= "        " ~ op ~ " " ~ right ~ ", " ~ result ~ "\n";

        return result; // caller will use this register
    }

    return "#0"; // fallback
}
