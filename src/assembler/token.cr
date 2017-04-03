module Assembler

  class Token
    property type : Symbol
    property value : String
    property row : Int32
    property column : Int32

    def initialize(@type, @value, @row, @column)
    end

    def to_s(io)
      location = "#{@row.to_s.rjust(4, ' ')}:#{@column.to_s.ljust(4, ' ')}"
      type = "#{@type.to_s.ljust(10, ' ')}"
      io << "#{location}: #{type}: #{@value.strip}"
    end
  end

end
