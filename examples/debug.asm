main:
  push qword, 25
  mov fp, sp

  loads qword, -8

  loadi r0, qword, -8

  loadsr qword, r0
