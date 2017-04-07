; this program is the assembly for the following
; pseudo-code
;
; add(5, 6) * sub(20, 10)

main:

  ; add(5, 6)
  add sp, sp, 8             ; reserve 8 bytes for the return value

  ; method arguments
  loadi r0, qword, 5        ; write 5 into r0
  loadi r1, qword, 6        ; write 6 into r1
  rpush r0                  ; push r0 onto the stack
  rpush r1                  ; push r1 onto the stack

  ; argument bytesize
  loadi r0d, dword, 16      ; write 16 into r0d
  rpush r0d                 ; push r0d onto the stack

  call _add                 ; call the add function
  rpop r10, qword            ; pop the return value into r10


  ; sub(20, 10)
  add sp, sp, 8             ; reserve 8 bytes for the return value

  ; method arguments
  loadi r0, qword, 20       ; write 20 into r0
  loadi r1, qword, 10       ; write 10 into r1
  rpush r0                  ; push r0 onto the stack
  rpush r1                  ; push r1 onto the stack

  ; argument bytesize
  loadi r0d, dword, 16      ; write 16 into r0d
  rpush r0d                 ; push r0d onto the stack

  call _sub                 ; call the add function
  rpop r1, qword            ; pop the return value into r0

  ; multiply r0 and r1
  ;
  ; r0 contains the result of add(5, 6)
  ; r1 contains the result of sub(20, 10)
  mul r0, r0, r1

  ; exit the machine
  call _halt

; Add two qword values
;
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

; Subtract one qword value from another
;
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
  loadi r0b, byte, 0        ; exit code
  rpush r0b
  loadi r0w, word, 0        ; syscall id for exit
  rpush r0w
  syscall
