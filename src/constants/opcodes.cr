module Constants

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
    LOADS
    LOADSR
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

  # Lookup table for instruction lengths
  INSTRUCTION_LENGTH = [
    2, # rpush
    6, # rpop
    3, # mov
    0, # loadi (this is calculated in the vm itself)
    2, # rst

    4, # add
    4, # sub
    4, # mul
    4, # div
    4, # idiv
    4, # rem
    4, # irem

    4, # fadd
    4, # fsub
    4, # fmul
    4, # fdiv
    4, # frem
    4, # fexp

    3, # cmp
    3, # lt
    3, # gt
    3, # ult
    3, # ugt

    4, # shr
    4, # shl
    4, # and
    4, # xor
    4, # nand
    4, # or
    3, # not

    14, # load
    7, # loadr
    13, # loads
    6, # loadsr
    10, # store
    0, # push (this is calculated in the vm itself)

    7, # read
    14, # readc
    14, # reads
    13, # readcs
    3, # write
    10, # writec
    6, # writes
    13, # writecs
    7, # copy
    11, # copyc

    9, # jz
    2, # jzr
    9, # jmp
    2, # jmpr
    9, # call
    2, # callr
    1, # ret

    1, # nop
    1 # syscall
  ] of Int32

end
