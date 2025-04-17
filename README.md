# D2GEN - D to Genesis Compiler

**D2GEN** is a custom compiler that transforms a simplified subset of the D programming language into **Motorola 68000 assembly**, with the ultimate goal of targeting the **Sega Genesis / Mega Drive**.

Inspired by SGDK. Rewritten in D. Retro as hell.

> ? Stage 1: Compiles to Easy68k-compatible 68k ASM  
> ?? Stage 2: Emits bootable Genesis ROMs

---

## ?? Project Goals

- Compile D-lite ? Motorola 68k Assembly
- Produce `.asm` files that can run in Easy68k (Windows XP dev friendly)
- Transition to ROM generation targeting Sega Genesis
- Build a D-powered runtime similar to SGDK

---

## ?? Features (Current / Planned)

- [x] Lexer for D-lite syntax
- [x] AST-building parser
- [ ] 68k assembly generator (Easy68k style)
- [ ] ROM linker / Sega Genesis header injector
- [ ] Genesis runtime for VDP, input, audio (in D)

---

## ?? Development Environment

- ?? **Windows XP Compatible**
- Runs with:
  - [Digital Mars DMD](https://dlang.org/download.html)
  - [GDC (GCC D Compiler)](https://gcc.gdcproject.org/)
- Outputs `.asm` files readable by:
  - **Easy68k**
  - Eventually: **VASM** or **custom binary emitter**

---

## ?? Build Instructions

With `dmd`:
```bash
dmd compiler/main.d
