main:
  loadi r0, qword, 2.5
  loadi r1, qword, 2.5
  fadd r0, r0, r1
  rpush r0
