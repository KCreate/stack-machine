.foo word 25

main:
  nop
  add r0, r1, r2
  loadi ipd, ipw, ipb
  loadi r0, qword, 55

.foo word 25

_add:
  rpush 25

.foo qword 25
.bar byte 25
.baz 5 [1, 2, 3, 4, 5]

