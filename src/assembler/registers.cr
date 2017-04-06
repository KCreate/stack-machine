module Assembler

  enum Regs : UInt8
    {% for i in 0..59 %}
      R{{i}}
    {% end %}

    IP
    SP
    FP
    FLAGS

    def dword
      value | 0b01000000
    end

    def word
      value | 0b10000000
    end

    def byte
      value | 0b11000000
    end

    def self.from(value : String)
      {% for name in Regs.constants %}
        if value == "{{name.downcase}}"
          return Regs::{{name}}
        end
      {% end %}

      return Regs::R0
    end
  end

end
