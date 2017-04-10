require "../constants/constants.cr"

module VM
  include Constants

  MEMORY_SIZE = 2 ** 16 # default memory size

  class Machine
    property memory : Bytes
    property regs : Bytes
    property executable_size : Int64
    property running : Bool
    property debugger_signal : Proc(UInt64, Void)?

    def initialize(memory_size = MEMORY_SIZE)
      @executable_size = 0_i64
      @memory = Bytes.new memory_size
      @regs = Bytes.new 64 * 8 # 64 registers of 8 bytes each
      @running = false
      @debugger_signal = nil
    end

    # Set the machines debugger signal handler
    def debugger_signal(&block : Proc(UInt64, Void))
      @debugger_signal = block
    end

    # Resets and copies *data* into the machine's memory
    #
    # Raises if *data* doesn't fit into the machine's memory
    def flash(data : Bytes)
      if data.bytesize > @memory.size
        raise Error.new(
          ErrorCode::OUT_OF_MEMORY,
          "Trying to write #{data.bytesize} into #{@memory.size} bytes of memory"
        )
      end

      reset_memory
      data.copy_to @memory

      @executable_size = data.bytesize.to_i64
      reg_write Register::SP, @executable_size
      reg_write Register::FP, @executable_size

      self
    end

    # Writes 0 to all memory locations
    def reset_memory
      0.upto(@memory.bytesize - 1) do |i|
        @memory[i] = 0_u8
      end

      self
    end

    # Grows the machine's memory capacity to a given size
    #
    # Does nothing if *size* is smaller than the machine's memory capacity
    def grow(size)
      return self if size <= @memory.size

      # Creates a new slice of size *size*
      # and writes the old memory into it
      @memory = Bytes.new(size, 0_u8).tap do |mem|
        @memory.move_to mem
      end

      self
    end

    # Starts the machine
    def start
      @running = true

      while @running
        cycle
      end

      self
    end

    # Runs a single cpu cycle
    def cycle
      instruction = fetch
      old_ip = reg_read UInt64, Register::IP
      execute instruction, old_ip

      # Only increment the IP if the last instruction didn't modify it
      if old_ip == reg_read UInt64, Register::IP
        instruction_length = decode_instruction_length instruction
        new_ip = old_ip + instruction_length
        reg_write Register::IP, new_ip
      end

      self
    end

    # Runs *amount* cpu cycles
    def cycle(amount)
      amount.times do
        cycle
      end

      self
    end

    # Fetches the current instruction
    def fetch
      address = reg_read UInt64, Register::IP
      byte = mem_read UInt8, address
      Opcode.new byte
    end

    # Executes a given instruction
    def execute(instruction : Opcode, ip)
      case instruction
      when Opcode::RPUSH
        op_rpush ip
      when Opcode::RPOP
        op_rpop ip
      when Opcode::MOV
        op_mov ip
      when Opcode::LOADI
        op_loadi ip
      when Opcode::RST
        op_rst ip
      when Opcode::LOAD
        op_load ip
      when Opcode::LOADR
        op_loadr ip
      when Opcode::LOADS
        op_loads ip
      when Opcode::LOADSR
        op_loadsr ip
      when Opcode::STORE
        op_store ip
      when Opcode::PUSH
        op_push ip
      when Opcode::READ
        op_read ip
      when Opcode::READC
        op_readc ip
      when Opcode::READS
        op_reads ip
      when Opcode::READCS
        op_readcs ip
      when Opcode::WRITE
        op_write ip
      when Opcode::WRITEC
        op_writec ip
      when Opcode::WRITES
        op_writes ip
      when Opcode::WRITECS
        op_writecs ip
      when Opcode::COPY
        op_copy ip
      when Opcode::COPYC
        op_copyc ip
      when Opcode::JZ
        op_jz ip
      when Opcode::JZR
        op_jzr ip
      when Opcode::JMP
        op_jmp ip
      when Opcode::JMPR
        op_jmpr ip
      when Opcode::CALL
        op_call ip
      when Opcode::CALLR
        op_callr ip
      when Opcode::RET
        op_ret ip
      when Opcode::NOP
        return
      when Opcode::SYSCALL
        op_syscall ip
      else
        invalid_instruction instruction
      end
    end

    # Decodes the length of *instruction*
    def decode_instruction_length(instruction : Opcode)
      case instruction
      when Opcode::LOADI
        address = reg_read UInt64, Register::IP
        size = mem_read UInt32, address + 2

        #      +- Opcode
        #      |   +- Target register
        #      |   |   +- Size specifier
        #      |   |   |   +- Value
        #      |   |   |   |
        #      v   v   v   v
        return 1 + 1 + 4 + size
      when Opcode::PUSH
        address = reg_read UInt64, Register::IP
        size = mem_read UInt32, address + 1

        #      +- Opcode
        #      |   +- Size specifier
        #      |   |   +- Value
        #      |   |   |
        #      v   v   v
        return 1 + 4 + size
      else
        return INSTRUCTION_LENGTH[instruction.value]
      end
    end

    # :nodoc:
    private def get_bytes(data : T) forall T
      slice = Slice(T).new 1, data
      pointer = Pointer(UInt8).new slice.to_unsafe.address
      size = sizeof(T)
      bytes = Bytes.new pointer, size
      bytes
    end

    # Sets the value of *reg* to *data*
    def reg_write(reg : Register, data : T) forall T
      bytes = get_bytes data
      reg_write reg, bytes
    end

    # :ditto:
    def reg_write(reg : Register, data : Bytes)
      invalid_register_access reg unless legal_reg reg
      target = @regs[reg.regcode.to_i64 * 8, reg.bytecount]
      target.to_unsafe.clear reg.bytecount
      data = data[0, target.size] if data.size > target.size
      target.copy_from data
      self
    end

    # Reads a *type* value from *register*
    def reg_read(x : T.class, reg : Register) forall T
      invalid_register_access reg unless legal_reg reg
      source = @regs[reg.regcode.to_i64 * 8, reg.bytecount]

      # Zero pad values smaller than 8 bytes
      bytes = Bytes.new 8
      bytes.copy_from source
      ptr = Pointer(T).new bytes.to_unsafe.address
      ptr[0]
    end

    # Reads all bytes from *reg*
    def reg_read(reg : Register)
      invalid_register_access reg unless legal_reg reg
      @regs[reg.regcode.to_i64 * 8, reg.bytecount]
    end

    # Writes *data* to *address*
    def mem_write(address, data : T) forall T
      bytes = get_bytes data
      mem_write address, bytes
    end

    # :ditto:
    def mem_write(address, data : Bytes)
      illegal_memory_access address unless legal_address address + data.size
      target = @memory + address
      target.copy_from data
      self
    end

    # Reads a *type* value from *address*
    def mem_read(x : T.class, address) forall T
      illegal_memory_access address unless legal_address address + sizeof(T)
      source = @memory + address
      ptr = Pointer(T).new source.to_unsafe.address
      ptr[0]
    end

    # Reads *count* bytes from *address*
    def mem_read(count, address)
      illegal_memory_access address unless legal_address address + count
      @memory[address, count]
    end

    # Pushes *value* onto the stack
    def stack_write(data : Bytes)
      sp = reg_read UInt64, Register::SP
      mem_write sp, data
      sp += data.size
      reg_write Register::SP, sp
    end

    # Pushes *value* onto the stack
    def stack_write(value : T) forall T
      value = Slice(T).new 1, value
      size = sizeof(T)
      ptr = Pointer(UInt8).new value.to_unsafe.address
      bytes = Bytes.new ptr, size
      stack_write bytes
    end

    # Reads *count* bytes from the stack
    def stack_peek(count)
      sp = reg_read UInt64, Register::SP
      address = sp - count
      mem_read count, address
    end

    # Reads a *T* value from the stack
    def stack_peek(x : T.class) forall T
      sp = reg_read UInt64, Register::SP
      size = sizeof(T)
      address = sp - size
      ptr = @memory[address, size].to_unsafe.as(T)
      ptr[0]
    end

    # Pops *count* bytes off the stack
    def stack_pop(count)
      sp = reg_read UInt64, Register::SP
      address = sp - count
      bytes = mem_read count, address
      reg_write Register::SP, sp - count
      bytes
    end

    # Pops a *T* value off the stack
    def stack_pop(x : T.class) forall T
      sp = reg_read UInt64, Register::SP
      size = sizeof(T)
      address = sp - size
      ptr = @memory[address, size].to_unsafe
      adr = ptr.address
      ptr = Pointer(T).new adr
      value = ptr[0]
      reg_write Register::SP, sp - size
      value
    end

    # Returns true if *reg* is legal
    def legal_reg(reg : Register)
      reg.regcode >= 0 && reg.regcode <= 63
    end

    # Returns true if *address* is legal
    def legal_address(address)
      address >= 0 && address < @memory.size
    end

    # :nodoc:
    private def illegal_memory_access(address)
      ip = reg_read UInt64, Register::IP
      ip = ("0x" + (ip.to_s(16).rjust(8, '0'))).colorize :red
      address = ("0x" + (address.to_s(16).rjust(8, '0'))).colorize :yellow

      raise Error.new(
        ErrorCode::ILLEGAL_MEMORY_ACCESS,
        "#{ip}: Illegal memory access at #{address} (memory size: #{@memory.size} bytes)"
      )
    end

    # :nodoc:
    private def bad_register_access(register : Register)
      raise Error.new ErrorCode::BAD_REGISTER_ACCESS, "Bad register access: #{register}"
    end

    # :nodoc:
    private def invalid_register_access(register : Register)
      raise Error.new ErrorCode::INVALID_REGISTER, "Unknown register: #{register}"
    end

    # :nodoc:
    private def invalid_instruction(instruction : Opcode)
      raise Error.new ErrorCode::INVALID_INSTRUCTION, "Unknown instruction: #{instruction}"
    end

    # :nodoc:
    private def invalid_syscall(syscall : Syscall)
      raise Error.new ErrorCode::INVALID_SYSCALL, "Unknown sycall: #{syscall}"
    end

    # Executes a rpush instruction
    #
    # ```
    # rpush r0
    # ```
    private def op_rpush(ip)
      reg = Register.new mem_read(UInt8, ip + 1)
      value = reg_read reg
      stack_write value
    end

    # Executes a rpop instruction
    #
    # ```
    # rpop r0, qword
    # ```
    private def op_rpop(ip)
      reg = Register.new mem_read(UInt8, ip + 1)
      size = mem_read(UInt32, ip + 2)
      value = stack_pop size
      reg_write reg, value
    end

    # Executes a mov instruction
    #
    # ```
    # mov r0, r1
    # ```
    private def op_mov(ip)
      target = Register.new mem_read(UInt8, ip + 1)
      source = Register.new mem_read(UInt8, ip + 2)
      value = reg_read source
      reg_write target, value
    end

    # Executes a loadi instruction
    #
    # ```
    # loadi r0, qword, 25
    # ```
    private def op_loadi(ip)
      target = Register.new mem_read(UInt8, ip + 1)
      size = mem_read UInt32, ip + 2
      value = mem_read size, ip + 6
      reg_write target, value
    end

    # Executes a rst instruction
    #
    # ```
    # rst r0
    # ```
    private def op_rst(ip)
      reg = Register.new mem_read(UInt8, ip + 1)
      reg_write reg, 0
    end

    # Executes a load instruction
    #
    # ```
    # load r0, qword, -20
    # ```
    private def op_load(ip)
      reg = Register.new mem_read(UInt8, ip + 1)
      size = mem_read UInt32, ip + 2
      offset = mem_read(Int64, ip + 6)
      frameptr = reg_read UInt64, Register::FP
      address = frameptr + offset
      value = mem_read size, address
      reg_write reg, value
    end

    # Executes a loadr instruction
    #
    # ```
    # loadr r0, qword, r1
    # ```
    private def op_loadr(ip)
      reg = Register.new mem_read(UInt8, ip + 1)
      size = mem_read UInt32, ip + 2
      offset = Register.new mem_read(UInt8, ip + 6)
      offset = reg_read Int64, offset
      frameptr = reg_read UInt64, Register::FP
      address = frameptr + offset
      value = mem_read size, address
      reg_write reg, value
    end

    # Executes a loads instruction
    #
    # ```
    # loads qword, -8
    # ```
    private def op_loads(ip)
      size = mem_read UInt32, ip + 1
      offset = mem_read Int64, ip + 5
      frameptr = reg_read UInt64, Register::FP
      address = frameptr + offset
      value = mem_read size, address
      stack_write value
    end

    # Executes a loadsr instruction
    #
    # ```
    # loadsr qword, r0
    # ```
    private def op_loadsr(ip)
      size = mem_read UInt32, ip + 1
      offset = Register.new mem_read UInt8, ip + 2
      offset = reg_read Int64, offset
      frameptr = reg_read UInt64, Register::FP
      address = frameptr + offset
      value = mem_read size, address
      stack_write value
    end

    # executes a store instruction
    #
    # ```
    # store -8, r0
    # ```
    private def op_store(ip)
      offset = mem_read Int64, ip + 1
      source = Register.new mem_read(UInt8, ip + 9)
      value = reg_read source
      frameptr = reg_read UInt64, Register::FP
      address = frameptr + offset
      mem_write address, value
    end

    # Executes a push instruction
    #
    # ```
    # push qword, 5
    # ```
    private def op_push(ip)
      size = mem_read UInt32, ip + 1
      value = mem_read size, ip + 5
      stack_write value
    end

    # Executes a read instruction
    #
    # ```
    # read r0, r1
    # ```
    private def op_read(ip)
      target = Register.new mem_read(UInt8, ip + 1)
      source = Register.new mem_read(UInt8, ip + 2)
      address = reg_read UInt64, source
      value = mem_read target.bytecount, address
      reg_write target, value
    end

    # Executes a readc instruction
    #
    # ```
    # readc r0, 0x500
    # ```
    private def op_readc(ip)
      target = Register.new mem_read(UInt8, ip + 1)
      address = mem_read UInt64, ip + 2
      value = mem_read target.bytecount,address
      reg_write target, value
    end

    # Executes a reads instruction
    #
    # ```
    # reads qword, r0
    # ```
    private def op_reads(ip)
      size = mem_read UInt32, ip + 1
      source = Register.new mem_read(UInt8, ip + 2)
      address = reg_read UInt64, source
      value = mem_read size, address
      stack_write value
    end

    # Executes a readcs instruction
    #
    # ```
    # readcs qword, 0x500
    # ```
    private def op_readcs(ip)
      size = mem_read UInt32, ip + 1
      address = mem_read UInt64, ip + 5
      value = mem_read size, address
      stack_write value
    end

    # Executes a write instruction
    #
    # ```
    # write r0, r1
    # ```
    private def op_write(ip)
      target = Register.new mem_read(UInt8, ip + 1)
      address = reg_read UInt64, target
      source = Register.new mem_read(UInt8, ip + 2)
      value = reg_read source
      mem_write address, value
    end

    # Executes a writec instruction
    #
    # ```
    # writec 0x500, r1
    # ```
    private def op_writec(ip)
      address = mem_read UInt64, ip + 1
      source = Register.new mem_read(UInt8, ip + 9)
      value = reg_read source
      mem_write address, value
    end

    # Executes a writes instruction
    #
    # ```
    # writes r0, qword
    # ```
    private def op_writes(ip)
      target = Register.new mem_read(UInt8, ip + 1)
      address = reg_read UInt64, target
      size = mem_read UInt32, ip + 2
      value = stack_pop size
      mem_write address, value
    end

    # Executes a writecs instruction
    #
    # ```
    # writecs 0x500, qword
    # ```
    private def op_writecs(ip)
      address = mem_read UInt64, ip + 1
      size = mem_read UInt32, ip + 9
      value = stack_pop size
      mem_write address, value
    end

    # Executes a copy instruction
    #
    # ```
    # copy r0, qword, r1
    #      ^          ^
    #      |          +- Source
    #      +- Target
    # ```
    private def op_copy(ip)
      target = Register.new mem_read(UInt8, ip + 1)
      size = mem_read UInt32, ip + 2
      source = Register.new mem_read(UInt8, ip + 6)
      target_adr = reg_read UInt64, target
      source_adr = reg_read UInt64, source
      value = mem_read size, source_adr
      mem_write target_adr, value
    end

    # Executes a copyc instruction
    #
    # ```
    # copyc target, qword, source
    # ```
    private def op_copyc(ip)
      target = mem_read(UInt64, ip + 1)
      size = mem_read UInt32, ip + 9
      source = mem_read(UInt64, ip + 13)
      value = mem_read size, source
      mem_write target, value
    end

    # Executes a jz instruction
    #
    # ```
    # jz myfunction
    # ```
    private def op_jz(ip)
      address = mem_read UInt64, ip + 1
      flags = reg_read UInt8, Register::FLAGS.byte
      zero = flags & Flag::ZERO.value
      reg_write Register::IP, address if zero != 0
    end

    # Executes a jzr instruction
    #
    # ```
    # jzr r0
    #     ^
    #     +- Contains the target address
    # ```
    private def op_jzr(ip)
      target = Register.new mem_read(UInt8, ip + 1)
      address = reg_read UInt64, target
      flags = reg_read UInt8, Register::FLAGS.byte
      zero = flags & Flag::ZERO.value
      reg_write Register::IP, address if zero != 0
    end

    # Executes a jmp instruction
    #
    # ```
    # jmp myfunction
    # ```
    private def op_jmp(ip)
      address = mem_read UInt64, ip + 1
      reg_write Register::IP, address
    end

    # Executes a jmpr instruction
    #
    # ```
    # jmpr r0
    #      ^
    #      +- Contains the target address
    # ```
    private def op_jmpr(ip)
      target = Register.new mem_read(UInt8, ip + 1)
      address = reg_read UInt64, target
      reg_write Register::IP, address
    end

    # Executes a call instruction
    #
    # ```
    # push qword, 0     ; allocate space for return value
    # push qword, 1     ; argument 1
    # push qword, 2     ; argument 2
    # push dword, 16    ; argument bytecount
    # call myfunction
    # ```
    private def op_call(ip)
      address = mem_read UInt64, ip + 1
      frameptr = reg_read UInt64, Register::FP
      return_address = ip + decode_instruction_length(fetch)

      # Base address of this stack frame
      # Is a pointer to a qword which will later
      # be populated with the old frame pointer
      stack_frame_baseadr = reg_read UInt64, Register::SP

      # Push the new stack frame
      stack_write frameptr
      stack_write return_address

      # Update FP and IP
      reg_write Register::FP, stack_frame_baseadr
      reg_write Register::IP, address
    end

    # Executes a callr instruction
    #
    # ```
    # push qword, 0     ; allocate space for return value
    # push qword, 1     ; argument 1
    # push qword, 2     ; argument 2
    # push dword, 16    ; argument bytecount
    #
    # loadi r0, qword, myfunction
    # call r0
    # ```
    private def op_callr(ip)
      target = Register.new mem_read(UInt8, ip + 1)
      address = reg_read UInt64, target
      frameptr = reg_read UInt64, Register::FP
      return_address = ip + decode_instruction_length(fetch)

      # Base address of this stack frame
      # Is a pointer to a qword which will later
      # be populated with the old frame pointer
      stack_frame_baseadr = reg_read UInt64, Register::SP

      # Push the new stack frame
      stack_write frameptr
      stack_write return_address

      # Update FP and IP
      reg_write Register::FP, stack_frame_baseadr
      reg_write Register::IP, address
    end

    # Executes a ret instruction
    #
    # ```
    # ret
    # ```
    private def op_ret(ip)

      # Read current stack frame
      stack_frame_baseadr = reg_read UInt64, Register::FP
      frame_pointer = mem_read UInt64, stack_frame_baseadr
      return_address = mem_read UInt64, stack_frame_baseadr + 8
      argument_count = mem_read UInt32, stack_frame_baseadr - 4
      stack_pointer = stack_frame_baseadr - (4 + argument_count)

      # Restore old state
      reg_write Register::SP, stack_pointer
      reg_write Register::FP, frame_pointer
      reg_write Register::IP, return_address
    end

    # Executes a syscall instruction
    #
    # ```
    # push byte, 0 ; exit code
    # push word, 0 ; syscall id
    # syscall
    # ```
    private def op_syscall(ip)
      id = Syscall.new stack_pop UInt16
      perform_syscall id, reg_read(UInt64, Register::SP)
    end

    # Syscall router
    private def perform_syscall(id : Syscall, stackptr : UInt64)
      case id
      when Syscall::EXIT
        exit_code = stack_pop UInt8
        reg_write Register::R0, exit_code
        @running = false
      when Syscall::DEBUGGER
        argument = stack_pop UInt64
        @debugger_signal.try &.call(argument)
      when Syscall::GROW
        grow @memory.size * 2
      else
        invalid_syscall id
      end
    end
  end

end
