require "./parser.cr"
require "./semantic.cr"

module Assembler

  class Builder
    property warnings : Array(String)
    property errors : Array(String)
    property source : String

    # Assemble *io*
    def self.build(source)
      builder = new source
      result = builder.build
      yield builder.warnings, builder.errors, result
    end

    def initialize(@source)
      @errors = [] of String
      @warnings = [] of String
    end

    def build
      source = IO::Memory.new @source
      parse_tree = Parser.parse source do |parser|
        parser.warnings.each { |warning| @warnings << warning }
        parser.errors.each { |error| @errors << error }
      end

      Semantic.analyse parse_tree do |warnings, errors|
        warnings.each { |warning| @warnings << warning }
        errors.each { |error| @errors << error }
      end

      parse_tree
    end

  end

end
