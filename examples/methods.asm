; this program is the assembly for the following
; pseudo-code
;
; add(5, 6) * sub(20, 10)
; exit(0)

main:

  ; add(5, 6)
  add sp, sp, 8             ; reserve 8 bytes for the return value
  push qword, 5             ; argument 1
  push qword, 6             ; argument 2
  push dword, 16            ; bytecount of all arguments

  call _add                 ; call the _add function
  rpop r0, qword            ; pop the return value into r0

  ; sub(20, 10)
  add sp, sp, 8             ; reserve 8 bytes for the return value
  push qword, 20            ; argument 1
  push qword, 10            ; argument 2
  push dword, 16            ; bytecount of all arguments

  call _sub                 ; call the _sub function
  rpop r1, qword            ; pop the return value into r0

  ; multiply r0 and r1
  ;
  ; r0 contains the result of add(5, 6)
  ; r1 contains the result of sub(20, 10)
  mul r0, r0, r1

  ; exit the machine
  call _halt

; Uses r0 and r1 (callee saved)
_add:
  rpush r0                  ; push r0 onto the stack
  rpush r1                  ; push r1 onto the stack

  load r0, qword, -20       ; read qword at fp - 20 into r0
  load r1, qword, -12       ; read qword at fp - 12 into r1
  add r0, r0, r1            ; add r0 and r1 and save into r0
  store -28, r0             ; store r0 at fp - 28

  rpop r1, qword            ; restore r1 from the stack
  rpop r0, qword            ; restore r0 from the stack

  ret

; Uses r0 and r1 (callee saved)
_sub:
  rpush r0                  ; push r0 onto the stack
  rpush r1                  ; push r1 onto the stack

  load r0, qword, -20       ; read qword at fp - 20 into r0
  load r1, qword, -12       ; read qword at fp - 12 into r1
  sub r0, r0, r1            ; sub r1 from r0 and save into r0
  store -28, r0             ; store r0 at fp - 28

  rpop r1, qword            ; restore r1 from the stack
  rpop r0, qword            ; restore r0 from the stack

  ret

; exit the machine with status code 0
_halt:
  push byte, 0              ; exit code
  push word, 0              ; syscall id (exit)
  syscall
