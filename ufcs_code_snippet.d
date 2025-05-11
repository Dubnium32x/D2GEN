// Add these functions to the end of generateExpr in codegen.d

// Add support for MemberCallExpr (UFCS)
    if (auto memberCall = cast(MemberCallExpr) expr) {
        // First, get the object's expression
        string objectReg = generateExpr(memberCall.object, lines, regIndex, varAddrs);
        
        // Handle the UFCS call by converting it to a regular function call
        // Push the object as the first argument
        lines ~= "        move.l " ~ objectReg ~ ", -(SP)";
        
        // Push the rest of the arguments in reverse order
        foreach_reverse (arg; memberCall.arguments) {
            string argReg = generateExpr(arg, lines, regIndex, varAddrs);
            lines ~= "        move.l " ~ argReg ~ ", -(SP)";
        }
        
        // Call the function using the method name
        lines ~= "        bsr " ~ memberCall.method;
        
        // Clean up the stack
        lines ~= "        add.l #" ~ to!string(4 * (memberCall.arguments.length + 1)) ~ ", SP";
        
        // Move the result to a register
        string dest = nextReg(regIndex);
        lines ~= "        move.l D0, " ~ dest;
        return dest;
    }
