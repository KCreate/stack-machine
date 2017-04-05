main:
  loadi r0b, byte, 0 ; exit code
  loadi r1b, byte, 0 ; exit
  rpush r0b
  rpush r1b
  syscall

foo:
  jmp main

