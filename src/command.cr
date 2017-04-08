require "colorize"
require "option_parser"

require "./assembler/builder.cr"
require "./machine/vm.cr"

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
      filename = ""
      memory_size = 2 ** 16 # 65'536 bytes

      should_run = true
      OptionParser.parse arguments do |parser|
        parser.banner = "Usage: run filename [switches]"
        parser.on "-h", "--help", "show help" { puts parser; should_run = false }
        parser.on "-m SIZE", "--memory=SIZE", "set memory size" do |arg|
          arg = arg.to_i32?

          unless arg.is_a? Int32
            error "could not parse: #{arg}"
            should_run = false
            next
          end

          if arg <= 0
            error "memory size can't be smaller than 0"
            should_run = false
          end

          memory_size = arg
        end
        parser.invalid_option { |opt| error "unknown option: #{opt}"; should_run = false }
        parser.unknown_args do |args|
          filename = args.shift? || ""
          if args.size > 0
            error "unknown arguments: #{args.join ", "}"
            should_run = false
          end
        end
      end

      return unless should_run

      # Make sure we were given a file
      if filename == ""
        return error "missing filename"
      end

      # Check that the file exists and is readable
      unless File.readable?(filename) && File.file?(filename)
        return error "could not open #{filename}"
      end

      size = File.size filename
      bytes = Bytes.new size
      File.open filename do |io|
        io.read_fully bytes
      end

      machine = VM::Machine.new memory_size
      machine.flash bytes
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
