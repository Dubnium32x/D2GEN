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
    string[string] varAddrs; // memory label per variable

    foreach (node; nodes) {
        generateStmt(node, lines, regIndex, varAddrs);
    }

    lines ~= "        rts"; // Add `rts` only once

    // Emit .var_ memory section
    lines ~= "";
    foreach (name, addr; varAddrs) {
        lines ~= addr ~ ":    ds.l 1";
    }

    if (strLabels.length > 0) {
        lines ~= "";
        foreach (val, label; strLabels) {
            lines ~= label ~ ":";
            lines ~= "        dc.b \'" ~ val ~ "\'"; // Emit the string without escaping
            lines ~= "        dc.b 0";              // Add the null terminator separately
        }
    }

    lines ~= "        END";

    return lines.join("\n");
}

void generateStmt(ASTNode node, ref string[] lines, ref int regIndex, ref string[string] varAddrs) {
    regIndex = 1;

    if (auto decl = cast(VarDecl) node) {
        string valReg = generateExpr(decl.value, lines, regIndex, varAddrs);
        string addr = getOrCreateVarAddr(decl.name, varAddrs);
        lines ~= "        move.l " ~ valReg ~ ", " ~ addr;
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
	else if (auto print = cast(PrintStmt) node) {
		if (auto str = cast(StringLiteral) print.value) {
			string label = getOrCreateStringLabel(str.value);
			lines ~= "        lea " ~ label ~ ", A1";
			lines ~= "        move.b #9, D0"; // TRAP #15: Print string in A1
			lines ~= "        trap #15";
		} else {
			string reg = generateExpr(print.value, lines, regIndex, varAddrs);
			lines ~= "        move.l " ~ reg ~ ", D1";
			lines ~= "        move.b #1, D0"; // TRAP #15: Print number in D1
			lines ~= "        trap #15";
		}
	}

}

string nextReg(ref int regIndex) {
    if (regIndex > 7)
        throw new Exception("Out of registers: only D0–D7 are usable");
    return "D" ~ to!string(regIndex++);
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

    if (auto unary = cast(UnaryExpr) expr) {
        string reg = generateExpr(unary.expr, lines, regIndex, varAddrs);
        string dest = nextReg(regIndex);

        final switch (unary.op) {
            case "!":
                lines ~= "        tst.l " ~ reg;
                lines ~= "        seq " ~ dest;
                lines ~= "        and.l #1, " ~ dest;
                break;
        }

        return dest;
    }

    if (auto bin = cast(BinaryExpr) expr) {
        string left = generateExpr(bin.left, lines, regIndex, varAddrs);
        string right = generateExpr(bin.right, lines, regIndex, varAddrs);

        string dest = nextReg(regIndex);
        string op;

        switch (bin.op) {
            case "+": op = "add.l"; break;
            case "-": op = "sub.l"; break;
            case "*": op = "muls"; break;
            case "/": op = "divs"; break;
            case "!=":
                lines ~= "        cmp.l " ~ right ~ ", " ~ left;
                lines ~= "        sne " ~ dest;
                return dest;
            case "<=":
                lines ~= "        cmp.l " ~ right ~ ", " ~ left;
                lines ~= "        sle " ~ dest;
                return dest;
            case ">=":
                lines ~= "        cmp.l " ~ right ~ ", " ~ left;
                lines ~= "        sge " ~ dest;
                return dest;
            case "&&":
                string labelFalse = genLabel("andFalse");
                string labelEnd = genLabel("andEnd");

                lines ~= "        move.l " ~ left ~ ", " ~ dest;
                lines ~= "        cmp.l #0, " ~ dest;
                lines ~= "        beq " ~ labelFalse;

                string rightReg = generateExpr(bin.right, lines, regIndex, varAddrs);
                lines ~= "        move.l " ~ rightReg ~ ", " ~ dest;
                lines ~= "        bra " ~ labelEnd;

                lines ~= labelFalse ~ ":";
                lines ~= "        clr.l " ~ dest;
                lines ~= labelEnd ~ ":";

                return dest;

            case "||":
                string labelTrue = genLabel("orTrue");
                string labelEnd = genLabel("orEnd");

                lines ~= "        move.l " ~ left ~ ", " ~ dest;
                lines ~= "        cmp.l #0, " ~ dest;
                lines ~= "        bne " ~ labelTrue;

                string rightReg = generateExpr(bin.right, lines, regIndex, varAddrs);
                lines ~= "        move.l " ~ rightReg ~ ", " ~ dest;
                lines ~= "        bra " ~ labelEnd;

                lines ~= labelTrue ~ ":";
                lines ~= "        move.l #1, " ~ dest;
                lines ~= labelEnd ~ ":";

                return dest;
			case "==":
				lines ~= "        cmp.l " ~ right ~ ", " ~ left;
				lines ~= "        seq " ~ dest;
				return dest;

            default:
                throw new Exception("Unknown binary op: " ~ bin.op);
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

string getOrCreateVarAddr(string name, ref string[string] varAddrs) {
    if (!(name in varAddrs)) {
        varAddrs[name] = ".var_" ~ name;
    }
    return varAddrs[name];
}

// String label tracking
string[string] strLabels;
int strLabelCounter = 0;

string getOrCreateStringLabel(string val) {
    if (!(val in strLabels)) {
        strLabels[val] = ".str_" ~ to!string(strLabelCounter++);
    }
    return strLabels[val];
}

string escapeString(string input) {
    string escaped = "";
    foreach (c; input) {
        if (c == '"') {
            escaped ~= "\\\""; // Escape double quotes
        } else if (c == '\\') {
            escaped ~= "\\\\"; // Escape backslashes
        } else {
            escaped ~= c;
        }
    }
    return escaped;
}