# Execution
###### Status: Initial draft

> The virtual machine doesn't have a name yet, but to keep it short,
we refer to it as `the machine`.

## Default variables

Below are some variables you are able to pass to the machine in different contexts.
For example, if you instantiate the machine programmatically, you will be able to pass
them via a constructor call of some sorts. When launching via a CLI, `ARGV` is used.

| Name              | Type    | Description                                      | Default     |
|-------------------|---------|--------------------------------------------------|-------------|
| `MEMORY_SIZE`     | `Int64` | Amount of bytes the machine should allocate      | `1_000_000` |
| `MAX_MEMORY_SIZE` | `Int64` | Maximum amount of bytes the machine can allocate | `∞`         |

## Startup

On startup, the machine instantiates `$MEMORY_SIZE` amount of bytes. The complete memory is
zero-initialized. It then copies the contents of the executable file to the memory address `0x00`.
If the program doesn't fit into memory, the machine will exit with the `OUT_OF_MEMORY` error code.

## Memory alignment

Since the bytecodes are mostly position-dependent, they always start at offset `0x0` and grow towards
higher addresses. The stack starts immediately after the bytecodes (e.g If you have 25 bytes of instructions,
the stack starts at address `0x19`).

```
+------------------------+ <- 0x0
| Instructions           |
+------------------------+ <- Instruction-bytes
| Stack-memory           |
+------------------------+
| Heap-memory (unmanaged)|
+------------------------+ <- Max. memory size
```

## Register initialisation

All registers, except `sp` and `fp` will be zero-initialized.

## Execution loop

The `ip` register always points to the current instruction. If the instruction modified the instruction
pointer, it won't be incremented. If the instruction pointer wasn't accessed during the execution,
it will be set to the address of the next instruction.

## Standard calling convention

The machine provides the `call` and `ret` instructions, which implement the standard calling
convention used in the machine. If you're not happy with my implementation, you can roll
your own and access the `ip`, `sp` and `fp` registers manually.

Below is an example of how you would call another function.

The program below calculates the sum of `25` and `45` and saves the result in the `r0` register.

```assembly
main:
  push qword, 0         ; reserve 8 bytes for the return value
  push qword, 25        ; argument 1
  push qword, 45        ; argument 2
  push dword, 16        ; bytecount of arguments

  call mymethod
  rpop r0, qword        ; the top qword of the stack is now the 8 bytes we reserved earlier

  ; more program code here

mymethod:
  load r0, qword, -20   ; fp - 20 is the offset of the first argument
  load r1, qword, -12   ; fp - 12 is the offset of the second argument

  ; do something with r0 and r1 here...

  loadi r2, qword, 100  ; this is the return value
  store -28, r2         ; fp - 28 is the address of the 8 bytes reserved earlier
  ret
```

Below is a diagram of how the stack is organized when entering the `add` block.

```
+- Low addresses
|
+-----------------------------+
| Return value : 8 Bytes      | <- Return value
+-----------------------------+
| Argument 1 : 8 Bytes        | <-- Function arguments
| Argument 2 : 8 Bytes        | <-/
| Argument count : 4 Bytes    | <- How many bytes are arguments?
+-----------------------------+
| Old Frame pointer : 8 Bytes | <- Stack frame
| Return address : 8 Bytes    |
+-----------------------------+
|
+- High addresses
```

The `call` instruction simply pushes the current frame pointer and the address of the next
instruction. It then updates the `fp` register to point to the address of the previously pushed
old frame pointer and jumps to the specified address.

The `ret` instruction restores the `fp` register to the value that's inside the current
stack frame, pops off as many bytes as the argument count specifies and jumps to the return
address.
