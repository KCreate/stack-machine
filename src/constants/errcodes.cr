module Constants

  class Error < Exception
    property code : ErrorCode

    def initialize(@code, message)
      super(message)
    end
  end

  enum ErrorCode : UInt8
    REGULAR_EXIT
    ILLEGAL_MEMORY_ACCESS
    INVALID_INSTRUCTION
    INVALID_REGISTER
    INVALID_JUMP
    OUT_OF_MEMORY
  end

end
