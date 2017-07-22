# Design
###### Status: Initial draft

> The virtual machine doesn't have a name yet, but to keep it short,
we refer to it as `the machine`.

This document contains the specification for available registers, error codes,
a list of instructions together with their arguments and descriptions.

For a syntactic overview of the language, see the [assembly.md](./assembly.md) file.

For the specification on binary encoding, see the [encoding.md](./encoding.md) file.

## Error codes

| Name                    | Value  | Description                           |
|-------------------------|--------|---------------------------------------|
| `REGULAR_EXIT`          | `0x00` | The machine exited normally           |
| `ILLEGAL_MEMORY_ACCESS` | `0x01` | Memory read or write is out-of-bounds |
| `INVALID_INSTRUCTION`   | `0x02` | Unknown instruction                   |
| `INVALID_REGISTER`      | `0x03` | Unknown register                      |
| `INVALID_SYSCALL`       | `0x04` | Unknown syscall id                    |
| `EXECUTABLE_TOO_BIG`    | `0x05` | Executable won't fit into memory      |
| `INVALID_EXECUTABLE`    | `0x06` | Executable is invalid                 |
| `ALLOCATION_FAILURE`    | `0x07` | Memory allocation failure             |
| `INTERNAL_FAILURE`      | `0x08` | Internal failure                      |

## Registers

| Name           | Description         |
|----------------|---------------------|
| `r0` .. `r59`  | General purpose     |
| `ip`           | Instruction pointer |
| `sp`           | Stack pointer       |
| `fp`           | Frame pointer       |
| `flags`        | Flags register      |

- `ip` holds a pointer to the current instruction
- `sp` holds a pointer to the top-most item on the stack
- `fp` holds a pointer to the base of the current stack-frame
- `flags` each bit is a specific flag that can be set by other instructions

Currently, only the lower `byte` of the `flags` register has anything meaningful in it. All other bytes
are untouched by the machine.

```
      + Reserved / Undefined
      |
vvvvvvv
00000000
^^^^^^^^
       |
       +-- Zero flag - Set if the last operation resulted in zero (or a comparison resulted in true)
```

Registers can hold a 64-bit value. The default addressing mode is 32-bit (`dword`). You can target
the lower `byte`, `word` or the full register `qword` by either appending `b`, `w` or `q` to the register name.
Below is a visual representation of how a register can be accessed:

```
r0q:  00000000 00000000 00000000 00000000 00000000 00000000 00000000 00000000
r0:   00000000 00000000 00000000 00000000
r0w:  00000000 00000000
r0b:  00000000
```

When writing a value to a register that is bigger than what can ultimately fit into it, the value is trimmed.

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

Memory layout is described in the [encoding](./encoding.md) doc.

## Size specifiers

Size specifiers can be used to describe a given amount of bytes.

A few constants are available for commonly used sizes.

- `byte` - `1 byte`
- `word` - `2 bytes`
- `dword` - `4 bytes`
- `qword` - `8 bytes`

## Instructions

Instructions are names assigned to a specific opcode.
Instruction encoding is described in the [encoding](./encoding.md) doc.

## Instruction descriptions

Each instruction in the machine is documented below.
The `Arguments` section, if present, follows the following naming convention:

- `value` Immediate value.
- `reg` Register descriptor.
- `type` Size specifier (e.g `byte` or `word`).
- `address` Absolute address
- `offset` Relative offset from a given point

If a register is surrounded with brackets, the value inside the register is meant.

## Reading from and writing to registers

| Name     | Arguments         | Description                                        |
|----------|-------------------|----------------------------------------------------|
| `rpush`  | reg               | Push `reg` onto the stack                          |
| `rpop`   | reg               | Pop a `reg.size` value from the stack into `reg`   |
| `mov`    | reg1, reg2        | Copies `reg2` into `r1`                            |
| `loadi`  | reg, value        | Read an immediate `reg.size` and store it in `reg` |
| `rst`    | reg               | Reset a register to `0`                            |

## Integer arithmetic instructions

| Name   | Arguments  | Description                                               |
|--------|------------|-----------------------------------------------------------|
| `add`  | reg1, reg2 | Add `reg2` to `reg1`                                      |
| `sub`  | reg1, reg2 | Subtract `reg2` from `reg1`                               |
| `mul`  | reg1, reg2 | Multiply `reg1` by `reg2`                                 |
| `div`  | reg1, reg2 | Divide `reg1` by `reg2`                                   |
| `idiv` | reg1, reg2 | Divide `reg1` by `reg2` (signed)                          |
| `rem`  | reg1, reg2 | Put the remainder of (`reg1` % `reg2`) in `reg1`          |
| `irem` | reg1, reg2 | Put the remainder of (`reg1` % `reg2`) in `reg1` (signed) |

## Floating-point arithmetic instructions

All registers of these instructions need to be in `qword` (e.g `r0q`) mode. If a register
with a smaller mode is specified, this will result in a garbage value.

| Name   | Arguments  | Description                                      |
|--------|------------|--------------------------------------------------|
| `fadd` | reg1, reg2 | Add `reg2` to `reg1`                             |
| `fsub` | reg1, reg2 | Subtract `reg2` from `reg1`                      |
| `fmul` | reg1, reg2 | Multiply `reg1` by `reg2`                        |
| `fdiv` | reg1, reg2 | Divide `reg1` by `reg2`                          |
| `frem` | reg1, reg2 | Put the remainder of (`reg1` % `reg2`) in `reg1` |
| `fexp` | reg1, reg2 | Raise `reg1` to the power of `reg2`              |

## Floating-point comparison instructions

| Name   | Arguments   | Description                                            |
|--------|-------------|--------------------------------------------------------|
| `flt`  | reg1, reg2  | Set `flags` zero bit, if `reg1` is less than `reg2`    |
| `fgt`  | reg1, reg2  | Set `flags` zero bit, if `reg1` is greater than `reg2` |

## Integer comparison instructions

| Name  | Arguments  | Description                                                       |
|-------|------------|-------------------------------------------------------------------|
| `cmp` | reg1, reg2 | Set `flags` zero bit, if `reg1` and `reg2` are equal              |
| `lt`  | reg1, reg2 | Set `flags` zero bit, if `reg1` is less than `reg2`               |
| `gt`  | reg1, reg2 | Set `flags` zero bit, if `reg1` is greater than `reg2`            |
| `ult` | reg1, reg2 | Set `flags` zero bit, if `reg1` is less than `reg2` (unsigned)    |
| `ugt` | reg1, reg2 | Set `flags` zero bit, if `reg1` is greater than `reg2` (unsigned) |

## Bitwise instructions

| Name   | Arguments  | Description                     |
|--------|------------|---------------------------------|
| `shr`  | reg1, reg2 | Right-Shift `reg1` `reg2` times |
| `shl`  | reg1, reg2 | Left-Shift `reg1` `reg2` times  |
| `and`  | reg1, reg2 | Perform bitwise `reg1 & reg2`   |
| `xor`  | reg1, reg2 | Perform bitwise `reg1 ^ reg2`   |
| `or`   | reg1, reg2 | Perform bitwise `reg1 | reg2`   |
| `not`  | reg1       | Perform bitwise `~reg1`         |

## Casting instructions

| Name       | Arguments | Description                                |
|------------|-----------|--------------------------------------------|
| `inttofp`  | reg       | Convert `reg` from `int` to `float`        |
| `sinttofp` | reg       | Convert `reg` from `signed int` to `float` |
| `fptoint`  | reg       | Convert `reg` from `float` to `signed int` |

## Stack instructions

| Name     | Arguments    | Description                                                        |
|----------|--------------|--------------------------------------------------------------------|
| `load`   | reg, offset  | Read a `reg.size` value from `fp + offset` and store it in `reg`   |
| `loadr`  | reg, offset  | Read a `reg.size` value from `fp + [offset]` and store it in `reg` |
| `loads`  | type, offset | Read a `type` value from `fp + offset` and push it onto the stack  |
| `loadsr` | type, reg    | Read a `type` value from `fp + [reg]` and push it onto the stack   |
| `store`  | offset, reg  | Store the contents of `reg` at `fp + offset`                       |
| `push`   | type, value  | Push `value` onto the stack                                        |

## Memory read / write

| Name      | Arguments            | Description                                                     |
|-----------|----------------------|-----------------------------------------------------------------|
| `read`    | reg, address         | Read `reg.size` bytes at `[address]` and store in `reg`         |
| `readc`   | reg, address         | Read `reg.size` bytes at `address` and store in `reg`           |
| `reads`   | type, address        | Read a `type` value from `[address]` and push it onto the stack |
| `readcs`  | type, address        | Read a `type` value from `address` and push it onto the stack   |
| `write`   | address, reg         | Write the contents of `reg` to `[address]`                      |
| `writec`  | address, reg         | Write the contents of `reg` to `address`                        |
| `writes`  | address, type        | Pop a `type` value from the stack and write it to `[address]`   |
| `writecs` | address, type        | Pop a `type` value from the stack and write it to `address`     |
| `copy`    | target, type, source | Copy a `type` value from `[source]` to `[target]`               |
| `copyc`   | target, type, source | Copy a `type` value from `source` to `target`                   |

## Jump instructions

| Name    | Arguments | Description                                                         |
|---------|-----------|---------------------------------------------------------------------|
| `jz`    | offset    | Jump to `offset` if the `zero bit` in the `flags` register is set   |
| `jzr`   | offset    | Jump to `[offset]` if the `zero bit` in the `flags` register is set |
| `jmp`   | offset    | Jump to `offset`                                                    |
| `jmpr`  | offset    | Jump to `[offset]`                                                  |
| `call`  | offset    | Push a stack frame and jump to `offset`                             |
| `callr` | offset    | Push a stack frame and jump to `[offset]`                           |
| `ret`   |           | Return from the current stack frame                                 |

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

| Name    | Opcode | Arguments      | Description                                                 |
|---------|--------|----------------|-------------------------------------------------------------|
| `exit`  | `0x00` | code           | Halt the machine with `code` as the exit code (single byte) |
| `sleep` | `0x01` | seconds        | Sleeps for `seconds`. `seconds` is a `float64`              |
| `write` | `0x02` | address, count | Writes `count` bytes from `address` into stdout             |
| `puts`  | `0x03` | reg            | Prints the contents of `reg`                                |
| `read`  | `0x04` | reg            | Reads one character from stdin and saves it to `reg`        |

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
