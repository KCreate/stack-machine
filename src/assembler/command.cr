require "colorize"
require "option_parser"

require "./builder.cr"

module Assembler

  # Command-line interface to the assembler
  class Command
    def initialize(arguments : Array(String))
      if arguments.size == 0
        help
        return
      end

      case command = arguments.shift
      when "build"
        return build arguments
      when "help"
        help
      when "version"
        version
      else
        error "unknown command: #{command}"
      end
    end

    # Runs the build command
    def build(arguments : Array(String))
      filename = ""
      output = "out.bc"

      should_run = true
      OptionParser.parse arguments do |parser|
        parser.banner = "Usage: build filename [switches]"
        parser.on "-o PATH", "--out=PATH", "set name of output file" { |name| output = name }
        parser.on "-h", "--help", "show help" { puts parser; should_run = false }
        parser.invalid_option { |opt| error("unknown option: #{opt}"); should_run = false }
        parser.unknown_args do |args|
          filename = args.shift? || ""
          if args.size > 0
            error "unknown arguments: #{args.join ", "}"
            should_run = false
          end
        end
      end

      unless should_run
        return
      end

      if filename == ""
        error "missing filename"
        return
      end

      unless File.readable?(filename) && File.file?(filename)
        error "could not open #{filename}"
        return
      end

      content = File.read filename

      Builder.build content do |err, result|
        if err
          error err
          return
        end

        success "Built", "#{filename} #{result.size} bytes"

        File.open output, "w" do |fd|
          fd.write result.to_slice
        end
      end
    end

    def help
      puts <<-HELP
        Usage: asm [command]

        Commands:
            build               assemble a file
            version             show version
            help                show this help
      HELP
    end

    def version
      puts "StackVM Assembler v0.1.0"
    end

    private def error(message)
      puts "#{"Error:".colorize(:red).bold} #{message}"
    end

    private def warning(message)
      puts "#{"Warning:".colorize(:yellow).bold} #{message}"
    end

    private def success(status, message)
      puts "#{"#{status}:".colorize(:green).bold} #{message}"
    end
  end

end
