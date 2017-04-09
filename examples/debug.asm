main:
  push qword, 0
  mov fp, sp

  loadi r0, qword, 25
  store -8, r0
