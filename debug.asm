.foo word 25

main:
  nop
  add r0, r1, r2
  loadi ipd, ipw, ipb

.foo word 25

_add:
  rpush 25

.foo qword 25
.bar byte 25
.baz 2 1

