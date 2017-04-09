require "./flags.cr"

module Constants

  enum Register : UInt8
    {% for i in 0..59 %}
      R{{i}}
    {% end %}

    IP
    SP
    FP
    FLAGS

    def regcode
      value & Flag::REGCODE.value
    end

    def mode
      value & Flag::REGMODE.value
    end

    def qword
      Register.new value | Flag::QWORD.value
    end

    def dword
      Register.new value | Flag::DWORD.value
    end

    def word
      Register.new value | Flag::WORD.value
    end

    def byte
      Register.new value | Flag::BYTE.value
    end

    def bytecount
      case mode
      when Flag::BYTE.value then 1
      when Flag::WORD.value then 2
      when Flag::DWORD.value then 4
      when Flag::QWORD.value then 8
      else
        0
      end
    end

    def self.from(value : String)
      {% for name in Register.constants %}
        if value == "{{name.downcase}}"
          return Register::{{name}}
        end
      {% end %}

      return Register.new 255_u8
    end
  end

end
