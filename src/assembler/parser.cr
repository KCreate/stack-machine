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
      when :newline
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
        label = expect :label
        size = parse_size_specifier
        value = parse_value
        read_token
        return Constant.new label.value, size, value
      when :label
        label = Label.new @token.value

        expect :colon
        read_token

        block = Block.new label

        while @token.type == :instruction
          block.instructions << parse_instruction
        end

        return block
      else
        raise error "unexpected token: #{@token}"
      end
    end

    # Parses a single instruction
    def parse_instruction
      mnemonic = @token
      instruction = Instruction.new mnemonic.value

      read_token

      instruction
    end

    # Parses a single size specifier
    def parse_size_specifier
      token = read_token

      case token.type
      when :size
        return SizeSpecifier.new token.value
      when :numeric_int
        return parse_numeric_i64(token.value).to_i32
      else
        raise error "unexpected token: #{token}, expected a size specifier or byte count"
      end
    end

    # Parses a single value
    def parse_value
      token = read_token

      case token.type
      when :numeric_int
        return IntegerValue.new parse_numeric_i64(token.value).to_u64
      else
        raise error "unexpected token: #{token}, expected a numeric or size specifier"
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

  end
end
