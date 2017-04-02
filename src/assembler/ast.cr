module Assembler

  # Represents a single module
  #
  # A module is a collection of blocks and constants
  class Module
    getter blocks : Array(Block)
    getter constants : Array(Constant)

    def initialize(@blocks = [] of Block, @constants = [] of Constant)
    end
  end

  # Represents a single block
  #
  # ```
  # main:                     <-+
  #   loadi r0, qword, 25       |
  #   loadi r1, qword, 25       +- this is an entire block
  #   add r0, r0, r1            |
  #   rpush r0                <-+
  # ```
  class Block
    getter label : Label
    getter instructions : Array(Instruction)

    def initialize(@label, @instructions = [] of Instruction)
    end
  end

  # Represents a single label
  #
  # ```
  # main: <- this is the label
  #   add r0, r1, r2
  #   call add
  #        ^
  #        |
  #        +- this can also be a label
  #
  # .myconstant qword 25
  #  ^
  #  |
  #  +- this is also a label
  # ```
  class Label
    getter name : String

    def initialize(@name)
    end
  end

  # Represents a single instruction
  #
  # ```
  # main:
  #   add r0, r1, r2
  #   ^
  #   |
  #   +- This is the instruction
  # ```
  class Instruction
    getter mnemonic : String
    getter arguments : Array(Argument)

    def initialize(@mnemonic, @arguments = [] of Argument)
    end
  end

  # Base class of all arguments
  class Argument
  end

  # Represents a single register
  #
  # ```
  # main:
  #   add r0, r1d, r2d
  #       ^     ^
  #       |     |
  #       |     +- This is the register mode
  #       |
  #       +- This is the register name
  # ```
  #
  # Register modes are defined as the following:
  # - `0` = `qword`
  # - `1` = `dword`
  # - `2` = `word`
  # - `3` = `byte`
  class Register < Argument
    getter name : String
    getter mode : Int32

    def initialize(@name, @mode = 0)
    end
  end

  # Represents a single address
  #
  # ```
  # main:
  #   call 0x01234
  #        ^
  #        |
  #        +- This is the address
  # ```
  class Address < Argument
    getter address : Int64

    def initialize(@address)
    end
  end

  # Represents a single size specifier
  #
  # ```
  # qword
  # dword
  # word
  # byte
  # ```
  class SizeSpecifier < Argument
    getter value : String

    def initialize(@value)
    end
  end

  # Base class for all immediate values
  class Value < Argument
  end

  # Represents a single integer
  #
  # ```
  # 155
  # 1_000_000
  # 0x005
  # 0b00011001
  # 0b00000000_00000001
  # ```
  class IntegerValue < Value
    getter value : UInt64

    def initialize(@value)
    end

    # Returns the minimum amount of bytes required to contain this value
    def required_bytes
      return 1 if @value <= (2 ** 8) - 1 # byte
      return 2 if @value <= (2 ** 16) - 1 # word
      return 4 if @value <= (2 ** 32) - 1 # dword
      return 8 if @value <= (2 ** 64) - 1 # qword
    end
  end

  # Represents a single Float32 value
  #
  # ```
  # 0.0_f32
  # 2.5_f32
  # 5_f32
  # ```
  class Float32Value < Value
    getter value : Float32

    def initialize(@value)
    end
  end

  # Represents a single Float64 value
  #
  # ```
  # 0.0
  # 2.5
  # 5_f64
  # ```
  class Float64Value < Value
    getter value : Float64

    def initialize(@value)
    end
  end

  # Represents a collection of bytes
  #
  # ```
  # loadi r0d, 4, [0, 1, 2, 3] <-+
  #                              |- these are byte arrays
  # .mybytes 5 [0, 1, 2, 3, 4] <-+
  # ```
  class ByteArray < Value
    getter bytes = Array(Int8)

    def initialize(@bytes = [] of Int8)
    end
  end

  # Represents a single constant definition
  #
  # ```
  # .myconstant qword 25
  # .mybyte byte 8
  # .myname string "hello world"
  # .mybytes 5 [0, 1, 2, 3, 4]
  # ```
  class Constant
    getter name : String
    getter type : SizeSpecifier | Int32
    getter value : Value

    def initialize(@name, @type, @value)
    end
  end
end
