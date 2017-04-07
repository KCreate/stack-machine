require "./syntax/ast.cr"

module Assembler

  enum Opcode : UInt8
    RPUSH
    RPOP
    MOV
    LOADI
    RST

    ADD
    SUB
    MUL
    DIV
    IDIV
    REM
    IREM

    FADD
    FSUB
    FMUL
    FDIV
    FREM
    FEXP

    CMP
    LT
    GT
    ULT
    UGT

    SHR
    SHL
    AND
    XOR
    NAND
    OR
    NOT

    LOAD
    LOADR
    PUSHS
    LOADS
    STORE
    PUSH

    READ
    READC
    READS
    READCS
    WRITE
    WRITEC
    WRITES
    WRITECS
    COPY
    COPYC

    JZ
    JZR
    JMP
    JMPR
    CALL
    CALLR
    RET

    NOP
    SYSCALL

    def self.from(value : String)
      {% for name in Opcode.constants %}
        if value == "{{name.downcase}}"
          return Opcode::{{name}}
        end
      {% end %}

      return Opcode::NOP
    end
  end

end
