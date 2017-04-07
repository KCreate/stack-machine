# Binary encoding
###### Status: Initial draft

> The virtual machine doesn't have a name yet, but to keep it short,
we refer to it as `the machine`.

This document contains the specification of the binary encoding of instructions,
immediate values, constants, registers, jump addresses, block ordering and
global constants.

## Content ordering

This section describes the way a valid executable file has to be structured.

```
+--------------+
| Bytecodes    |
+--------------+
| Constants    |
+--------------+
```

Each file begins with the bytecodes of the program. The constants section directly follows the bytecode section.
There is no border or marker between these two sections, they just directly follow each other.

At startup, the whole file is loaded into memory at address `0x0`. Execution will begin at address `0x0`.
If the program allows execution flow to the constant section, this may cause undefined behaviour.

It is the sole role of the compiler to generate code that behaves correctly. The machine doesn't do any section-checking
at all.

## Registers

Registers are represented as 8 bit values. The first two bits make up the mode, the rest
is the register code.

```
   +- Register code
   |
   v
00 000000
^
|
+- Mode
```

Register modes define which part of the register is being accessed. You can target
the low `dword`, `word` or `byte`.

```
00: 00000000 00000000 00000000 00000000 00000000 00000000 00000000 00000000
01: 00000000 00000000 00000000 00000000
10: 00000000 00000000
11: 00000000
```

## Instructions

Instructions are represented as 8 bit values.

```
+- Opcode
|
v
00000000
```

## Size specifiers

Size specifiers are represented as 32-bit values and are used to denote a given amount of bytes
in an argument.

## Addresses

Addresses are encoded as 64-bit values.

## Exit code

The exit code is a `byte` value.
