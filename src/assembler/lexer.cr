require "./reader.cr"
require "./ast.cr"
require "./token.cr"

module Assembler
  REGISTERS = [] of String

  # General purpose registers
  0.upto 59 do |i|
    ["", "d", "w", "b"].each do |mode|
      REGISTERS << "r#{i}#{mode}"
    end
  end

  ["ip", "sp", "fp", "flags"].each do |reg|
    ["", "d", "w", "b"].each do |mode|
      REGISTERS << "#{reg}#{mode}"
    end
  end

  class Lexer < Reader
    getter warnings : Array(String)
    getter errors : Array(String)
    getter token : Token

    def initialize(file)
      super file
      @warnings = [] of String
      @errors = [] of String
      @token = Token.new :EOF, "", 1, 1
    end

    private def reset_token
      @token.type = :undefined
      @token.value = ""
      @token.row = @row
      @token.column = @column
    end

    # Reads a single token
    def read_token
      reset_token

      case current_char
      when '\0'
        read :EOF
      when ':'
        read :colon
      when '.'
        read :dot
      when ';'
        consume_comment
      when '0'..'9'
        consume_numeric
      when '\r'
        case read
        when '\n'
          consume_whitespace
        else
          unexpected_char current_char
        end
      when '\n'
        read :newline
      when ' ', '\t'
        consume_whitespace
      else
        if label_start current_char
          consume_label
        else
          unexpected_char current_char
        end
      end

      @frame.clear
      @frame << current_char
      @token.dup
    end

    private def consume_numeric
      passed_underscore = false
      floating_point = false

      loop do
        case read
        when .number?
          # nothing to do
        when '_'
          passed_underscore = true
        else
          break
        end
      end

      if current_char == '.' && peek.number?
        read

        loop do
          case read
          when .number?
            # nothing to do
          when '_'
            passed_underscore = true
          else
            break
          end
        end
      end

      number_value = @frame.to_s[0..-2]

      if passed_underscore
        number_value = number_value.tr "_", ""
      end

      if floating_point
        @token.type = :numeric_float
      else
        @token.type = :numeric_int
      end

      @token.value = number_value
    end

    private def consume_whitespace
      while current_char.ascii_whitespace?
        read
      end

      @token.value = @frame.to_s[0..-2]
      @token.type = :whitespace
    end

    private def consume_comment
      loop do
        case read
        when '\n'
          break
        when '\r'
          case read
          when '\n'
            break
          else
            unexpected_char current_char
          end
        else
          # nothing to do
        end
      end

      @token.value = @frame.to_s[0..-2]
      @token.type = :comment
    end

    private def consume_label
      while label_part current_char
        read
      end

      @token.value = @frame.to_s[0..-2]

      case @token.value
      when "byte"
        @token.type = :size
      when "word"
        @token.type = :size
      when "dword"
        @token.type = :size
      when "qword"
        @token.type = :size
      when "string"
        @token.type = :size
      else
        @token.type = :label
      end

    end

    private def label_start(char)
      char.letter? || char == '_'
    end

    private def label_part(char)
      label_start(char) || char.number?
    end

    private def read(type)
      @token.type = type
      @token.value = "#{@frame}"
      super()
    end

    private def unexpected_char(char)
      raise error "unexpected char: #{char}, ascii: #{char.ord}"
    end

    private def warning(message)
      msg = "#{@row}:#{@column}: #{message}"
      @warnings << msg
      msg
    end

    private def error(message)
      msg = "#{@row}:#{@column}: #{message}"
      @errors << msg
      msg
    end
  end

end
