require "readline"

require "../constants/constants.cr"
require "./vm.cr"

module VM

  class Debugger
    property machine : Machine

    # Wether the machine is running freely
    # or if the cycles are controlled by the debugger
    property draining : Bool

    def initialize(@machine)
      @machine.debugger_signal do |arg|
        handle_debugger_signal arg
      end
      @draining = false
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
      when "e", "exdump"
        print_executable
      when "status"
        print_status
      when "c", "cycle"
        n = args.shift? || "1"
        n = n.to_i32?
        n = 1 unless n
        @machine.cycle n
      when "r", "registers"
        print_registers
      when "drain"
        @draining = true
        @machine.start
      when "m", "memory"
        start = args.shift?
        count = args.shift?

        unless start && count
          return error "no start or count argument passed"
        end

        start = start.to_i32?(prefix: true)
        count = count.to_i32?(prefix: true)

        return error "bad start addresss" unless start
        return error "bad count argument" unless count

        print_memory start, count
      when "j", "jump"
        if args.size == 0
          return error "jump needs an address"
        end

        adr = args.shift
        adr = adr.to_i32?(prefix: true)

        unless adr
          return error "bad address: #{adr}"
        end

        if adr < 0
          return error "address can't be smaller than 0"
        end

        if adr >= @machine.memory.size
          memsize = render_hex @machine.memory.size, 8, :yellow
          return error "address is out of bounds (memorysize: #{memsize})"
        end

        @machine.reg_write Register::IP, adr.to_u64
      else
        error "unknown command: #{name}"
      end
    end

    # Handles a signal sent by the machine
    private def handle_debugger_signal(arg)
      puts "received #{arg} from machine"
      if @draining
        @draining = false
        @machine.running = false
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

    # Prints *count* bytes starting at *start*
    private def print_memory(start, count)

      # check enough memory
      if start + count > @machine.memory.size - 1
        address = render_hex start, 16, :yellow
        return error "could not read #{count} bytes at #{address}"
      end

      bytes = @machine.memory[start, count]
      puts bytes.hexdump
    end

    # Prints the executable
    private def print_executable
      puts @machine.memory[0, @machine.executable_size].hexdump
    end

    # Prints all registers
    private def print_registers
      0.upto 19 do |i|
        i = i * 3
        reg1 = Register.new i.to_u8
        reg2 = Register.new (i + 1).to_u8
        reg3 = Register.new (i + 2).to_u8

        hex1 = render_hex @machine.reg_read(UInt64, reg1), 16, :yellow
        hex2 = render_hex @machine.reg_read(UInt64, reg2), 16, :yellow
        hex3 = render_hex @machine.reg_read(UInt64, reg3), 16, :yellow

        r1 = "#{reg1}: ".ljust 7, ' '
        r2 = "#{reg2}: ".ljust 7, ' '
        r3 = "#{reg3}: ".ljust 7, ' '

        STDOUT << r1 << hex1 << " "
        STDOUT << r2 << hex2 << " "
        STDOUT << r3 << hex3 << " "
        STDOUT << "\n"
        STDOUT.flush
      end

      hex_ip = render_hex @machine.reg_read(UInt64, Register::IP), 16, :yellow
      hex_sp = render_hex @machine.reg_read(UInt64, Register::SP), 16, :yellow
      hex_fp = render_hex @machine.reg_read(UInt64, Register::FP), 16, :yellow
      hex_flags = render_hex @machine.reg_read(UInt64, Register::FLAGS), 16, :yellow

      ip = "#{Register::IP}: ".ljust 7, ' '
      sp = "#{Register::SP}: ".ljust 7, ' '
      fp = "#{Register::FP}: ".ljust 7, ' '
      flags = "#{Register::FLAGS}: ".ljust 7, ' '

      STDOUT << "\n"
      STDOUT << ip << hex_ip << " "
      STDOUT << sp << hex_sp << " "
      STDOUT << fp << hex_fp << " "
      STDOUT << "\n"
      STDOUT << flags << hex_flags << " "
      STDOUT << "\n"
      STDOUT.flush
    end

    # Prints machine status information
    private def print_status
      ip = @machine.reg_read UInt64, Register::IP
      ip = render_hex ip, 16, :yellow
      sp = @machine.reg_read UInt64, Register::SP
      sp = render_hex sp, 16, :yellow
      fp = @machine.reg_read UInt64, Register::FP
      fp = render_hex fp, 16, :yellow
      memory_size = @machine.memory.size
      memory_size = render_hex memory_size, 16, :yellow

      puts <<-STATUS
        instruction pointer: #{ip}
        stack pointer:       #{sp}
        frame pointer:       #{fp}
        memory_size:         #{memory_size}
        running:             #{@machine.running}
      STATUS
    end

    # Prints the help message
    private def print_help
      puts <<-HELP
      Debugger help page

      h, help                            show this page
      q, quit                            quit the debugger
      s, stack                           print a hexdump of the stack
      r, registers                       print the contents of all registers
      c, cycle        n                  run *n* cpu cycles (default 1)
      j, jump         adr                jumps to *adr*
      e, exdump                          dump the executable
      m, memory       start, count       print *count* bytes starting at *start*
      status                             print machine status information
      drain                              run the machine in normal mode
                                           breaks when the debugger receives a signal or
                                           the machine terminates (syscall exit)
      HELP
    end

    # Returns the prompt
    private def prompt
      address = render_hex @machine.reg_read(UInt64, Register::IP), 8, :red
      frameptr = render_hex @machine.reg_read(UInt64, Register::FP), 8, :green
      running = render_hex((@machine.running ? 1 : 0), 1, :magenta)

      "[#{running}:#{frameptr}:#{address}]> "
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
