main:
  push qword, 25
  mov fp, sp

  loadi r0, qword, -8
  loadr r1, qword, r0
