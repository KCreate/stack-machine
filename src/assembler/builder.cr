require "./syntax/parser.cr"

module Assembler

  class Builder
    property warnings : Array(String)
    property errors : Array(String)
    property source : String

    property output : IO::Memory
    property offset_table : Hash(String, Int64)
    property unresolved_labels : Hash(Int64, String)

    # Assemble *io*
    def self.build(source)
      builder = new source
      result = builder.build
      yield builder.warnings, builder.errors, result
    end

    def initialize(@source)
      @errors = [] of String
      @warnings = [] of String
      @offset = 0
      @output = IO::Memory.new
      @offset_table = {} of String => Int64
      @unresolved_labels = {} of Int64 => String
    end

    def build
      source = IO::Memory.new @source
      mod = Parser.parse source do |parser|
        parser.warnings.each { |warning| @warnings << warning }
        parser.errors.each { |error| @errors << error }
      end

      codegen_module mod

      @output
    end

    def codegen_module(mod : Module)
      mod.blocks.each { |block|
        codegen_block block
      }

      mod.constants.each { |constant|
        codegen_constant constant
      }
    end

    def codegen_block(block : Block)
      puts block
    end

    def codegen_constant(constant : Constant)
      @offset_table[constant.label.name] = @output.pos.to_i64

      value_bytes = constant.value.bytes
      bytes : Bytes

      if value_bytes.size < constant.size.bytecount
        bytes = Bytes.new constant.size.bytecount
        bytes.copy_from value_bytes
      else
        bytes = value_bytes[0, constant.size.bytecount]
      end

      @output.write bytes
    end

    # Returns the opcode for a given instruction mnemonic
    def opcode_for_string(mnemonic : String)
      {% for mnemonic, opcode in Opcode.constants %}
        if mnemonic == {{mnemonic.downcase}}
          return {{opcode}}
        end
      {% end %}

      @errors << "bug: unknown instruction mnemonic: #{mnemonic}"
      -1
    end

  end

end
