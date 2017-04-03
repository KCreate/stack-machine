module Assembler

  class Reader
    getter io : IO::Memory
    getter current_char : Char
    getter buffer : IO::Memory
    getter frame : IO::Memory
    getter row : Int32
    getter column : Int32

    def initialize(@io)
      @current_char = '\0'
      @buffer = IO::Memory.new
      @frame = IO::Memory.new
      @row = 1
      @column = 0

      read
    end

    def read
      char = io.read_char

      unless char.is_a? Char
        char = '\0'
      end

      @buffer << char
      @frame << char

      if current_char == '\n'
        @row += 1
        @column = 1
      else
        @column += 1
      end

      @current_char = char

      char
    end

    def peek
      char = io.read_char

      unless char.is_a? Char
        char = '\0'
      end

      io.pos -= 1
      char
    end

    def current
      @current_char
    end
  end

end
