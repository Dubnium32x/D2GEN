// COMPILE

// main.d

module main;

import std.stdio;
import std.string;
import std.file;

import gen_compiler : gen_compiler;

int main() {
    // This is a test to see if we can make a Sega Genesis program from a D file.
    int a = 5;
    int b = 10;
    int c = a + b;
    writeln("The result of a + b is: ", c);
    return 0;
}