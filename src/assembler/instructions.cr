require "./syntax/ast.cr"

module Assembler

  enum Opcode : UInt8
    RPUSH     # 0x00 :  0
    RPOP      # 0x01 :  1
    MOV       # 0x02 :  2
    LOADI     # 0x03 :  3
    RST       # 0x04 :  4

    ADD       # 0x05 :  5
    SUB       # 0x06 :  6
    MUL       # 0x07 :  7
    DIV       # 0x08 :  8
    IDIV      # 0x09 :  9
    REM       # 0x0a : 10
    IREM      # 0x0b : 11

    FADD      # 0x0c : 12
    FSUB      # 0x0d : 13
    FMUL      # 0x0e : 14
    FDIV      # 0x0f : 15
    FREM      # 0x10 : 16
    FEXP      # 0x11 : 17

    CMP       # 0x12 : 18
    LT        # 0x13 : 19
    GT        # 0x14 : 20
    ULT       # 0x15 : 21
    UGT       # 0x16 : 22

    SHR       # 0x17 : 23
    SHL       # 0x18 : 24
    AND       # 0x19 : 25
    XOR       # 0x1a : 26
    NAND      # 0x1b : 27
    OR        # 0x1c : 28
    NOT       # 0x1d : 29

    LOAD      # 0x1e : 30
    LOADR     # 0x1f : 31
    PUSHS     # 0x20 : 32
    LOADS     # 0x21 : 33
    STORE     # 0x22 : 34
    PUSH      # 0x23 : 35

    READ      # 0x24 : 36
    READC     # 0x25 : 37
    READS     # 0x26 : 38
    READCS    # 0x27 : 39
    WRITE     # 0x28 : 40
    WRITEC    # 0x29 : 41
    WRITES    # 0x2a : 42
    WRITECS   # 0x2b : 43
    COPY      # 0x2c : 44
    COPYC     # 0x2d : 45

    JZ        # 0x2e : 46
    JZR       # 0x2f : 47
    JMP       # 0x30 : 48
    JMPR      # 0x31 : 49
    CALL      # 0x32 : 50
    CALLR     # 0x33 : 51
    RET       # 0x34 : 52

    NOP       # 0x35 : 53
    SYSCALL   # 0x36 : 54

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
