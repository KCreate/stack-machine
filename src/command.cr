require "colorize"
require "option_parser"

require "./assembler/builder.cr"

module StackVM
  include Assembler

  # Command-line interface to the assembler
  class Command
    def initialize(arguments : Array(String))
      if arguments.size == 0
        help
        return
      end

      case command = arguments.shift
      when "run"
        run arguments
      when "build"
        build arguments
      when "help"
        help
      when "version"
        version
      else
        error "unknown command: #{command}"
      end
    end

    # Runs an executable
    def run(arguments : Array(String))
      puts arguments
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

        success "Built", "#{output} #{result.size} bytes"
        bytes = result.to_slice

        if output == "-"
          STDOUT.write bytes
          STDOUT.flush
        else
          File.open output, "w" do |fd|
            fd.write bytes
          end
        end
      end
    end

    def help
      puts <<-HELP
        Usage: asm [command]

        Commands:
            run                 run a file
            build               assemble a file
            version             show version
            help                show this help
      HELP
    end

    def version
      puts "StackVM Assembler v0.1.0"
    end

    private def error(message)
      STDERR.puts "#{"Error:".colorize(:red).bold} #{message}"
    end

    private def warning(message)
      STDERR.puts "#{"Warning:".colorize(:yellow).bold} #{message}"
    end

    private def success(status, message)
      STDERR.puts "#{"#{status}:".colorize(:green).bold} #{message}"
    end
  end

end
