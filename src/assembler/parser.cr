require "./lexer.cr"
require "./ast.cr"

module Assembler
  class Parser < Lexer

    def self.parse(file)
      parser = new file
      tree = parser.parse
      yield parser
      tree
    end

    def initialize(file)
      super file
      read_token
    end

    def read_token
      token = super

      case token.type
      when :whitespace
        read_token
      when :comment
        read_token
      else
        token
      end
    end

    def parse
      parse_module
    end

    # Parses a module
    def parse_module
      mod = Module.new

      until @token.type == :EOF
        next read_token if @token.type == :newline
        statement = parse_statement

        case statement
        when .is_a? Block
          mod.blocks << statement
        when .is_a? Constant
          mod.constants << statement
        else
          raise error "can't append node of type #{statement.class} to #{mod}"
        end
      end

      mod
    end

    # Parses a statement
    def parse_statement
      case @token.type
      when :dot
        expect :label
        return parse_constant
      when :label
        label = Label.new @token.value
        block = Block.new label

        expect :colon
        expect :newline
        read_token

        until @token.type == :label || @token.type == :dot || @token.type == :EOF
          next read_token if @token.type == :newline
          block.instructions << parse_instruction
        end

        return block
      else
        raise error "unexpected token: #{@token}"
      end
    end

    # Parses a single constant definition
    def parse_constant
      label = @token.value
      read_token
      size = parse_size_specifier
      value = parse_value
      skip :newline

      Constant.new label, size, value
    end

    # Parses a single instruction
    def parse_instruction
      assert :instruction
      instruction = Instruction.new @token.value

      read_token

      until @token.type == :newline
        instruction.arguments << parse_argument
        unless @token.type == :comma
          break
        end
        skip :comma
      end

      skip :newline
      instruction
    end

    # Parse a single argument to an instruction
    def parse_argument
      case @token.type
      when :register
        value = @token.value

        mode = case value[-1]?
        when "d" then 1
        when "w" then 2
        when "b" then 4
        else
          0
        end

        unless mode == 0
          value = value[0..-2]
        end

        read_token
        return Register.new value, mode
      when :label
        value = @token.value
        read_token
        return Label.new value
      when :size
        value = @token.value
        read_token
        byte_count = SizeSpecifier.new(value).byte_count.to_u64
        return IntegerValue.new byte_count
      else
        return parse_value
      end
    end

    # Parses a single size specifier
    def parse_size_specifier
      case @token.type
      when :size
        value = @token.value
        read_token
        return SizeSpecifier.new(value).byte_count.to_i32
      when :numeric_int
        value = parse_numeric_i64(@token.value).to_i32
        read_token
        return value
      else
        raise error "unexpected token: #{@token}, expected a size specifier or byte count"
      end
    end

    # Parses a single value
    def parse_value
      case @token.type
      when :numeric_int
        value = parse_numeric_i64(token.value).to_u64
        read_token
        return IntegerValue.new value
      when :leftbracket
        read_token

        array = ByteArray.new

        until @token.type == :rightbracket
          assert :numeric_int
          value = parse_numeric_i64(@token.value).to_i8
          array.value << value

          read_token
          unless @token.type == :comma
            break
          end
          skip :comma
        end

        skip :rightbracket

        return array
      else
        raise error "unexpected token: #{@token}, expected a value"
      end
    end

    # Tries to parse a i64 value
    def parse_numeric_i64(value : String)
      num = value.to_i64?

      unless num
        raise error "could not convert #{value} to i64"
      end

      num
    end

    private def expect(type, value : String? = nil)
      token = read_token

      unless token.type == type
        raise error "unexpected token: #{@token}, expected: #{type}"
      end

      if value.is_a? String
        unless token.value == value
          raise error "unexpected token: #{@token}, expected: #{value}"
        end
      end

      token
    end

    private def skip(type, value : String? = nil)
      token = @token

      unless token.type == type
        raise error "unexpected token: #{@token}, expected: #{type}"
      end

      if value.is_a? String
        unless token.value == value
          raise error "unexpected token: #{@token}, expected: #{value}"
        end
      end

      read_token
    end

    private def assert(type, value : String? = nil)
      token = @token

      unless token.type == type
        raise error "unexpected token: #{@token}, expected: #{type}"
      end

      if value.is_a? String
        unless token.value == value
          raise error "unexpected token: #{@token}, expected: #{value}"
        end
      end
    end

  end
end
