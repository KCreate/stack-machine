require "./syntax/parser.cr"
require "./instructions.cr"
require "./registers.cr"

module Assembler

  class Builder
    property output : IO::Memory
    property offset_table : Hash(String, Int64)
    property unresolved_symbols : Hash(Int64, String)

    def self.build(source)
      source = IO::Memory.new source
      mod = Parser.new(source).parse
      builder = Builder.new

      begin

        # Encodes all blocks
        mod.blocks.each do |block|
          builder.register_symbol block.label.name

          # Encode each instruction
          block.instructions.each do |instruction|
            builder.codegen_instruction instruction.mnemonic, instruction.arguments

          end
        end

        # Encode all constants
        mod.constants.each do |constant|
          builder.register_symbol constant.label.name
          builder.write_constant constant.size.bytecount, constant.value.bytes
        end

        # Resolve all unresolved symbols
        builder.resolve_symbols

        yield nil, builder.output
      rescue e : Exception
        yield e.message, builder.output
      end

      builder.output
    end

    def initialize
      @output = IO::Memory.new
      @offset_table = {} of String => Int64
      @unresolved_symbols = {} of Int64 => String
    end

    # Register a new symbol at this offset
    def register_symbol(name)

      # Check for duplicate symbols
      if @offset_table.has_key? name
        raise "duplicate symbol definition: #{name}"
      end

      @offset_table[name] = @output.pos.to_i64
    end

    # Register a symbol as needing to be resolved
    def register_unresolved_symbol(name)
      @unresolved_symbols[@output.pos.to_i64] = name
    end

    # Resolves all unresolved symbols
    def resolve_symbols
      @unresolved_symbols.each do |address, symbol|
        offset = @offset_table[symbol]?

        unless offset
          raise "undefined symbol: #{symbol}"
        end

        unresolved_address = @output.to_slice[address, 8]
        IO::ByteFormat::LittleEndian.encode(offset, unresolved_address)
      end
    end

    # Writes a constant into the output
    #
    # Trims *value* if *bytecount* is smaller than *value.size*
    # Appends zero value if *bytecount* is bigger
    def write_constant(bytecount, value : Bytes)
      bytes : Bytes

      if value.size < bytecount
        bytes = Bytes.new bytecount
        bytes.copy_from value
      else
        bytes = value[0, bytecount]
      end

      @output.write bytes
    end

    # :ditto:
    def write_constant(value)
      @output.write_bytes(value, IO::ByteFormat::LittleEndian)
    end

    # Writes *argument* to the output, limiting it to *bytecount*
    #
    # Also registers any symbols to the unresolved symbols table
    def write_argument(bytecount, argument)
      case argument
      when Label
        register_unresolved_symbol argument.name
        write_constant 8, Bytes.new(8)
      else
        write_constant bytecount, argument.bytes
      end
    end

    # :nodoc:
    private macro map_args(bytecounts = [] of Int32)
      assert_count mnemonic, arguments, {{bytecounts.size}}

      {% for size, i in bytecounts %}
        write_argument {{bytecounts[i]}}, arguments[{{i}}]
      {% end %}
    end

    # Encodes a given instruction
    def codegen_instruction(mnemonic, arguments)
      opcode = Opcode.from mnemonic
      write_constant opcode.value

      case mnemonic
      when "rpush", "rst" then map_args [1]
      when "rpop" then map_args [1, 4]
      when "mov", "cmp", "lt", "gt", "ult", "ugt", "not" then map_args [1, 1]
      when "loadi"
        puts "TOOD: Implement loadi instruction"
      when "add", "sub", "mul", "div", "idiv", "rem", "irem", "fadd", "fsub", "fmul", "fdiv", "frem", "fexp",
          "shr", "shl", "and", "xor", "nand", "or"
        map_args [1, 1, 1]
      when "load" then map_args [1, 4, 8]
      when "loadr" then map_args [1, 4, 1]
      when "pushs" then map_args [4, 8]
      when "loads" then map_args [4, 1]
      when "store" then map_args [8, 1]
      when "read" then map_args [1, 4, 1]
      when "readc" then map_args [1, 4, 8]
      when "reads" then map_args [4, 1]
      when "readcs" then map_args [4, 8]
      when "write" then map_args [1, 1]
      when "writec" then map_args [8, 1]
      when "writes" then map_args [1, 4]
      when "writecs" then map_args [8, 4]
      when "copy" then map_args [1, 4, 1]
      when "copyc" then map_args [8, 4, 8]
      when "jz" then map_args [8]
      when "jzr" then map_args [1]
      when "jmp" then map_args [8]
      when "jmpr" then map_args [1]
      when "call" then map_args [8]
      when "callr" then map_args [1]
      when "ret" then map_args
      when "nop" then map_args
      when "syscall" then map_args
      end
    end

    # Asserts that *arguments* has exactly *size* items in it
    private def assert_count(mnemonic, arguments, size)
      raise "#{mnemonic} expected #{size} arguments, got #{arguments.size}" if arguments.size != size
    end
  end

end
