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
    end

    # Checks the module for duplicate constant definitions
    private def check_duplicate_constants
      constants = @mod.constants
      visited = [] of String

      constants.each do |constant|
        name = constant.name
        already_declared = visited.includes? name
        if already_declared
          @warnings << "Duplicate constant definition: #{name}"
        else
          visited << name
        end
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
          @errors << "Bug: unknown value type: #{value.class}"
        end
      end
    end

    # Checks the module for duplicate block definitions
    private def check_duplicate_blocks
      blocks = @mod.blocks
      visited = [] of String

      blocks.each do |block|
        name = block.label.name
        already_declared = visited.includes? name
        if already_declared
          @warnings << "Duplicate block definition: #{name}"
        else
          visited << name
        end
      end
    end

  end

end
