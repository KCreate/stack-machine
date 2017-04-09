require "readline"

require "../constants/constants.cr"
require "./vm.cr"

module VM

  class Debugger
    property machine : Machine

    def initialize(@machine)
    end

    # Start the debugger
    def start
      args = [] of String

      loop do
        input = Readline.readline prompt, true
        args = (input || "help").split

        if args.size == 0
          next command "help", [] of String
        end

        if args[0] == "quit" || args[0] == "q"
          break
        end

        command args.shift, args
      end
    end

    # Runs *name* with *args*
    def command(name : String, args : Array(String))
      case name
      when "h", "help"
        print_help
      when "s", "stack"
        print_stack
      when "c", "cycle"
        n = args.shift? || "1"
        n = n.to_i32?
        n = 1 unless n
        @machine.cycle n
      else
        error "unknown command: #{name}"
      end
    end

    # Prints the stack
    private def print_stack
      base = @machine.executable_size
      sp = @machine.reg_read UInt64, Register::SP
      size = sp - base
      memory = @machine.memory[base, size]
      puts memory.hexdump
    end

    # Prints the help message
    private def print_help
      puts <<-HELP
      Debugger help page

      | name     | args | description                    |
      |----------|------|--------------------------------|
      | h, help  |      | show this page                 |
      | q, quit  |      | quit the debugger              |
      | s, stack |      | print a hexdump of the stack   |
      | c, cycle | n    | run *n* cpu cycles (default 1) |
      HELP
    end

    # Returns the prompt
    private def prompt
      address = render_hex @machine.reg_read(UInt64, Register::IP), 8, :red
      frameptr = render_hex @machine.reg_read(UInt64, Register::FP), 8, :green
      "[#{frameptr}:#{address}]> "
    end

    # Pretty print a number in hexadecimal
    private def render_hex(num, length, color)
      num = num.to_s(16).rjust(length, '0')
      num = ("0x" + num).colorize(color)
    end

    # Prints an error message
    private def error(message)
      STDERR.puts "#{"Error:".colorize(:red).bold} #{message}"
    end
  end

end
