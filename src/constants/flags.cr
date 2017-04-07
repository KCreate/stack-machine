module Constants

  enum Flag : UInt8
    OVERFLOW = 0b00000001
    PARITY   = 0b00000010
    ZERO     = 0b00000100
    NEGATIVE = 0b00001000
    CARRY    = 0b00010000

    REGCODE  = 0b00111111
    REGMODE  = 0b11000000
    QWORD    = 0b00000000
    DWORD    = 0b01000000
    WORD     = 0b10000000
    BYTE     = 0b11000000
  end

end
