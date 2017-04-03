require "./ast.cr"

module Assembler

  class Semantic
    getter warnings : Array(String)
    getter errors : Array(String)
    getter mod : Module

    def self.analyse(mod)
      semantic = Semantic.new mod
      result = semantic.analyse
      yield semantic.warnings, semantic.errors
      result
    end

    def initialize(@mod)
      @warnings = [] of String
      @errors = [] of String
    end

    # Analyse the current module
    def analyse
      check_duplicate_constants
      check_constant_size
      check_duplicate_blocks
      check_duplicate_labels
      check_instruction_arguments
      check_undefined_labels
    end

    # Checks the module for duplicate constant definitions
    private def check_duplicate_constants
      constants = @mod.constants
      visited = [] of String

      @mod.constants = constants.reverse.reject do |constant|
        name = constant.name
        already_declared = visited.includes? name

        if already_declared
          @errors << "duplicate constant definition: #{name}"
          next true
        end

        visited << name
        false
      end
    end

    # Checks that a constants value fits into the specified size
    private def check_constant_size
      constants = @mod.constants

      constants.each do |constant|
        byte_count = constant.type

        if byte_count.is_a? SizeSpecifier
          byte_count = case byte_count.value
                       when "qword" then 8
                       when "dword" then 4
                       when "word" then 2
                       when "byte" then 1
                       else
                         1
                       end
        end

        case value = constant.value
        when .is_a? IntegerValue
          if byte_count < value.required_bytes
            @errors << "#{value} doesn't fit into #{byte_count} bytes"
          end
        when .is_a? ByteArray
          if byte_count < value.value.size
            @errors << "#{value} doesn't fit into #{byte_count} bytes"
          end
        else
          @errors << "bug: unknown value type: #{value.class}"
        end
      end
    end

    # Checks the module for duplicate block definitions
    private def check_duplicate_blocks
      blocks = @mod.blocks
      visited = [] of String

      @mod.blocks = blocks.reverse.reject do |block|
        name = block.label.name
        already_declared = visited.includes? name

        if already_declared
          @errors << "duplicate block definition: #{name}"
          next true
        end

        visited << name
        false
      end
    end

    # Checks the module for duplicate label definitions
    private def check_duplicate_labels
      blocks = @mod.blocks
      constants = @mod.constants
      visited = [] of String

      blocks.each do |block|
        visited << block.label.name
      end

      constants.each do |constant|
        if visited.includes? constant.name
          @errors << "duplicate label definition: #{constant.name}"
        end

        visited << constant.name
      end
    end

    # Check the arguments of instructions
    private def check_instruction_arguments
      @mod.blocks.each do |block|
        block.instructions.each do |instruction|
          args = instruction.arguments

          case instruction.mnemonic
          when "rpush"
            assert_arg instruction, [Register]
          when "rpop"
            assert_arg instruction, [Register, IntegerValue]
          when "mov"
            assert_arg instruction, [Register, Register]
          when "loadi"
            assert_arg instruction, [Register, IntegerValue, [IntegerValue, ByteArray]]
          when "rst"
            assert_arg instruction, [Register]
          when "add", "sub", "mul", "div", "idiv", "rem", "irem",
               "fadd", "fsub", "fmul", "fdiv", "frem", "fexp"
            assert_arg instruction, [Register, Register, Register]
          when "cmp", "lt", "gt", "ult", "ugt"
            assert_arg instruction, [Register, Register, Register]
          when "shr", "shl", "and", "xor", "nand", "or"
            assert_arg instruction, [Register, Register, Register]
          when "not"
            assert_arg instruction, [Register, Register]
          when "load", "loadr"
            assert_arg instruction, [Register, IntegerValue, [IntegerValue, Label]]
          when "pushs"
            assert_arg instruction, [IntegerValue, IntegerValue]
          when "loads"
            assert_arg instruction, [IntegerValue, Register]
          when "store"
            assert_arg instruction, [IntegerValue, Register]
          when "read"
            assert_arg instruction, [Register, IntegerValue, IntegerValue]
          when "readc"
            assert_arg instruction, [Register, IntegerValue, IntegerValue]
          when "reads"
            assert_arg instruction, [Register, IntegerValue, IntegerValue]
          when "readcs"
            assert_arg instruction, [Register, IntegerValue, IntegerValue]
          when "write"
            assert_arg instruction, [Register, Register]
          when "writec"
            assert_arg instruction, [[IntegerValue, Label], Register]
          when "writes"
            assert_arg instruction, [Register, IntegerValue]
          when "writecs"
            assert_arg instruction, [[IntegerValue, Label], IntegerValue]
          when "copy"
            assert_arg instruction, [Register, IntegerValue, Register]
          when "copyc"
            assert_arg instruction, [[IntegerValue, Label], IntegerValue, [IntegerValue, Label]]
          when "jz"
            assert_arg instruction, [[IntegerValue, Label]]
          when "jzr"
            assert_arg instruction, [Register]
          when "jmp"
            assert_arg instruction, [[IntegerValue, Label]]
          when "jmpr"
            assert_arg instruction, [Register]
          when "call"
            assert_arg instruction, [[IntegerValue, Label]]
          when "callr"
            assert_arg instruction, [Register]
          when "ret"
            assert_arg instruction, [] of ASTNode.class
          when "nop"
            assert_arg instruction, [] of ASTNode.class
          when "syscall"
            assert_arg instruction, [] of ASTNode.class
          else
            @errors << "Bug: unknown instruction mnemonic: #{instruction.mnemonic}"
          end
        end
      end
    end

    # Check an instruction for a specific amount of arguments and types
    private def assert_arg(instruction, types)
      args = instruction.arguments

      # Check argument count
      unless args.size == types.size
        @errors << "#{instruction.mnemonic} expects #{types.size} arguments, got #{args.size}"
        return false
      end

      # Check each argument type
      args.each_with_index do |arg, index|
        type = types[index]
        next if type == Argument

        if type.is_a?(Array(ASTNode.class)) || type.is_a?(Array(Value.class))
          unless type.includes? arg.class
            @errors << "#{instruction.mnemonic}: expected arg #{index + 1} to be one of #{type}"
          end
        else
          unless arg.class == types[index]
            @errors << "#{instruction.mnemonic}: expected arg #{index + 1} to be a #{type}"
          end
        end
      end
    end

  end

end
