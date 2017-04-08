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
      value | Flag::QWORD.value
    end

    def dword
      value | Flag::DWORD.value
    end

    def word
      value | Flag::WORD.value
    end

    def byte
      value | Flag::BYTE.value
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

    def overflow?
      (byte & Flag::OVERFLOW) != 0
    end

    def parity?
      (byte & Flag::PARITY) != 0
    end

    def zero?
      (byte & Flag::ZERO) != 0
    end

    def negative?
      (byte & Flag::NEGATIVE) != 0
    end

    def carry?
      (byte & Flag::CARRY) != 0
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
