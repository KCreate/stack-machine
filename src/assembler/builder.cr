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
      parse_tree = Parser.parse source do |parser|
        parser.warnings.each { |warning| @warnings << warning }
        parser.errors.each { |error| @errors << error }
      end

      @output << parse_tree
      @output
    end

  end

end
