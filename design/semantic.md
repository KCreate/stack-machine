# Design
###### Status: Initial draft

> The virtual machine doesn't have a name yet, but to keep it short,
we refer to it as `the machine`.

This document contains the specification for available registers, error codes,
a list of instructions together with their arguments and descriptions.

For the specification on binary encoding, check the [encoding.md](./encoding.md) file.

## Error codes

| Name                    | Value  | Description                                                       |
|-------------------------|--------|-------------------------------------------------------------------|
| `REGULAR_EXIT`          | `0x00` | The machine exited normally                                       |
| `STACKOVERFLOW`         | `0x01` | Operation would overflow the stack                                |
| `ILLEGAL_MEMORY_ACCESS` | `0x03` | Memory read or write is out-of-bounds                             |
| `INVALID_INSTRUCTION`   | `0x04` | Unknown instruction                                               |
| `INVALID_REGISTER`      | `0x05` | Unknown register                                                  |
| `INVALID_JUMP`          | `0x06` | Trying to jump to an address that's out of bounds                 |
| `OUT_OF_MEMORY`         | `0x07` | Not enough memory to load a program                               |

## Registers

| Name           | Description         |
|----------------|---------------------|
| `r0` .. `r59`  | General purpose     |
| `ip`           | Instruction pointer |
| `sp`           | Stack pointer       |
| `fp`           | Frame pointer       |
| `flags`        | Flags register      |

- `ip` holds a pointer to the current instruction
- `sp` holds a pointer to the first byte above the stack
- `fp` holds a pointer to the base of the current stack-frame
- `flags` each bit is a specific flag that can be set by other instructions

```
00000000
^^^^^^^^
||||||||
|||||||+-- Overflow flag - Set if the last operation overflowed
|||||||
||||||+-- Parity flag - Set if the number of set bits is even in the result of the last operation
||||||
|||||+-- Zero flag - Set if the last operation resulted in zero
|||||
||||+-- Negative flag - Set if the most significant bit
||||
|||+-- Carry flag - Set if the last operation caused an arithmetic carry out of the most significant bit
|||
||+-- Reserved
||
|+-- Reserved
|
+-- Reserved
```

Currently, only the lower `byte` of the `flags` register has anything meaningful in it. All other bytes
are untouched by the machine.

Registers can hold a 64-bit value. You can also target the lower `dword`, `word` or `byte` of a register.
Do so by appending either `d`, `w`, or `b` to the end of the register name. Below is a visual representation
of how a register can be accessed:

```
r0:   00000000 00000000 00000000 00000000 00000000 00000000 00000000 00000000
r0d:  00000000 00000000 00000000 00000000
r0w:  00000000 00000000
r0b:  00000000
```

If you try to write a value bigger than the capacity of a register(e.g `mov r0b, r0w`), the value is trimmed.

```assembly
; Before
;
; r0w: 00000011 11000000
; r0b: 00000000

mov r0b, r0w

; After
;
; r0b: 00000011
```

## Memory

The machine can be initialized with a variable amount of memory. The stack grows towards high
addresses.

## Size specifiers

Size specifiers can be used to describe a given amount of bytes.

A few constants are available for commonly used sizes.

- `byte` - `1 byte`
- `word` - `2 bytes`
- `dword` - `4 bytes`
- `qword` - `8 bytes`

## Instructions

Instructions are names assigned to a specific opcode. Opcodes range from `0` to `255`.
For more information, [see encoding.md](./encoding.md).

## Instruction descriptions

Each instruction in the machine is documented below.
The `Arguments` section, if present, follows the following naming convention:

- `value` Immediate value.
- `reg` Register descriptor.
- `type` Size specifier (e.g `byte` or `word`).

If a register is surrounded with brackets it's to be interpreted as a pointer.

## Reading from and writing to registers

| Name     | Arguments         | Description                                    |
|----------|-------------------|------------------------------------------------|
| `rpush`  | reg               | Push `reg` onto the stack                      |
| `rpop`   | reg, type         | Pop a `type` value from the stack into `reg`   |
| `mov`    | target, source    | Copies `source` into `target`                  |
| `loadi`  | reg, type, value  | Read an immediate `type` and store it in `reg` |
| `rst`    | reg               | Reset a register to `0`                        |

## Integer arithmetic instructions

| Name   | Arguments       | Description                                                |
|--------|-----------------|------------------------------------------------------------|
| `add`  | rst, reg1, reg2 | Add `reg2` to `reg1` and store in `rst`                    |
| `sub`  | rst, reg1, reg2 | Subtract `reg2` from `reg1` and store in `rst`             |
| `mul`  | rst, reg1, reg2 | Multiply `reg1` by `reg2` and store in `rst`               |
| `div`  | rst, reg1, reg2 | Divide `reg1` by `reg2` and store in `rst`                 |
| `idiv` | rst, reg1, reg2 | Divide `reg1` by `reg2` and store in `rst` (signed)        |
| `rem`  | rst, reg1, reg2 | Put the remainder of (`reg1` % `reg2`) into `rst`          |
| `irem` | rst, reg1, reg2 | Put the remainder of (`reg1` % `reg2`) into `rst` (signed) |

## Floating-point arithmetic instructions

If a full mode register is passed, the type is assumbed to be `float`, if the register
is in DWORD mode, `double` is assumed. When trying to store in a register that has
insufficient size, the result will be truncated.

| Name   | Arguments       | Description                                            |
|--------|-----------------|--------------------------------------------------------|
| `fadd` | rst, reg1, reg2 | Add `reg2` to `reg1` and store in `rst`                |
| `fsub` | rst, reg1, reg2 | Subtract `reg2` from `reg1` and store in `rst`         |
| `fmul` | rst, reg1, reg2 | Multiply `reg1` by `reg2` and store in `rst`           |
| `fdiv` | rst, reg1, reg2 | Divide `reg1` by `reg2` and store in `rst`             |
| `frem` | rst, reg1, reg2 | Put the remainder of (`reg1` % `reg2`) into `rst`      |
| `fexp` | rst, reg1, reg2 | Raise `reg1` to the power of `reg2` and store in `rst` |

## Comparison instructions

| Name  | Arguments  | Description                                                           |
|-------|------------|-----------------------------------------------------------------------|
| `cmp` | reg1, reg2 | Set `flags` zero bit, if `[reg1]` and `reg[2]` are equal              |
| `lt`  | reg1, reg2 | Set `flags` zero bit, if `[reg1]` is less than `[reg2]`               |
| `gt`  | reg1, reg2 | Set `flags` zero bit, if `[reg1]` is greater than `[reg2]`            |
| `ult` | reg1, reg2 | Set `flags` zero bit, if `[reg1]` is less than `[reg2]` (unsigned)    |
| `ugt` | reg1, reg2 | Set `flags` zero bit, if `[reg1]` is greater than `[reg2]` (unsigned) |

## Bitwise instructions

| Name   | Arguments       | Description                                        |
|--------|-----------------|----------------------------------------------------|
| `shr`  | rst, reg1, reg2 | Right-shift `reg1` `reg2` times and store in `rst` |
| `shl`  | rst, reg1, reg2 | Left-shift `reg1` `reg2` times and store in `rst`  |
| `and`  | rst, reg1, reg2 | Store bitwise AND of `reg1` and `reg2` into `rst`  |
| `xor`  | rst, reg1, reg2 | Store bitwise XOR of `reg1` and `reg2` into `rst`  |
| `nand` | rst, reg1, reg2 | Store bitwise NAND of `reg1` and `reg2` into `rst` |
| `or`   | rst, reg1, reg2 | Store bitwise OR of `reg1` and `reg2` into `rst`   |
| `not`  | rst, reg1       | Store bitwise NOT of `reg1` into `rst`             |

## Stack instructions

| Name     | Arguments         | Description                                                       |
|----------|-------------------|-------------------------------------------------------------------|
| `load`   | reg, type, offset | Read a `type` value from `fp + offset` and store it in `reg`      |
| `loadr`  | reg, type, offset | Read a `type` value from `fp + [offset]` and store it in `reg`    |
| `pushs`  | type, offset      | Read a `type` value from `fp + offset` and push it onto the stack |
| `loads`  | type, reg         | Read a `type` value from `fp + [reg]` and push it onto the stack  |
| `store`  | offset, reg       | Store the contents of `reg` at `fp + offset`                      |
| `push`   | type, value       | Push `value` onto the stack                                       |

## Memory read / write

| Name      | Arguments            | Description                                                     |
|-----------|----------------------|-----------------------------------------------------------------|
| `read`    | reg, type, address   | Read a `type` value from `[address]` and store it in `reg`      |
| `readc`   | reg, type, address   | Read a `type` value from `address` and store it in `reg`        |
| `reads`   | type, address        | Read a `type` value from `[address]` and push it onto the stack |
| `readcs`  | type, address        | Read a `type` value from `address` and push it onto the stack   |
| `write`   | address, reg         | Write the contents of `reg` to `[address]`                      |
| `writec`  | address, reg         | Write the contents of `reg` to `address`                        |
| `writes`  | address, type        | Pop a `type` value from the stack and write it to `[address]`   |
| `writecs` | address, type        | Pop a `type` value from the stack and write it to `address`     |
| `copy`    | target, type, source | Copy a `type` value from `[source]` to `[target]`               |
| `copyc`   | target, type, source | Copy a `type` value from `source` to `target`                   |

## Jump instructions

| Name    | Arguments   | Description                                                         |
|---------|-------------|---------------------------------------------------------------------|
| `jz`    | offset      | Jump to `offset` if the `zero bit` in the `flags` register is set   |
| `jzr`   | offset      | Jump to `[offset]` if the `zero bit` in the `flags` register is set |
| `jmp`   | offset      | Jump to `offset`                                                    |
| `jmpr`  | offset      | Jump to `[offset]`                                                  |
| `call`  | offset      | Push a stack frame and jump to `offset`                             |
| `callr` | offset      | Push a stack frame and jump to `[offset]`                           |
| `ret`   |             | Return from the current stack frame                                 |

## Miscellaneous instructions

| Name      | Description  |
|-----------|--------------|
| `nop`     | Does nothing |
| `syscall` | VM syscall   |

## Syscalls

Syscalls are subroutines implemented directly inside the machine that provide some useful functionality,
such as doing IO or getting input from the user. To make a syscall, push any arguments first and the
syscall id onto the stack. The syscall id is a `word`.

### Available syscalls

| Name       | Opcode | Arguments | Description                                                 |
|------------|--------|-----------|-------------------------------------------------------------|
| `exit`     | `0x00` | code      | Halt the machine with `code` as the exit code (single byte) |
| `debugger` | `0x01` | arg       | Breakpoint for debuggers.                                   |
| `grow`     | `0x02` |           | Doubles the machines memory. Pushes `0_u32` on error        |

Return values of syscalls are pushed onto the stack. Different syscalls may produce different return values.

## License

The MIT License (MIT)

Copyright (c) 2017 Leonard Schuetz

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in
all copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
THE SOFTWARE.
