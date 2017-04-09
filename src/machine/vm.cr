require "../constants/constants.cr"

module VM
  include Constants

  MEMORY_SIZE = 2 ** 16 # default memory size

  class Machine
    property memory : Bytes
    property regs : Bytes
    property executable_size : Int64
    property running : Bool

    def initialize(memory_size = MEMORY_SIZE)
      @executable_size = 0_i64
      @memory = Bytes.new memory_size
      @regs = Bytes.new 64 * 8 # 64 registers of 8 bytes each
      @running = false
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
      when Opcode::PUSH
        op_push ip
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
      ptr = Pointer(T).new source.to_unsafe.address
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
      ptr = @memory[address, size].to_unsafe.as(T)
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
      raise Error.new(
        ErrorCode::ILLEGAL_MEMORY_ACCESS,
        "Illegal memory access at 0x#{address.to_s(16).rjust(8, '0')}"
      )
    end

    # :nodoc:
    private def invalid_register_access(register : Register)
      raise Error.new ErrorCode::INVALID_REGISTER, "Unknown register: #{register}"
    end

    # :nodoc:
    private def invalid_instruction(instruction)
      raise Error.new ErrorCode::INVALID_INSTRUCTION, "Unknown instruction: #{instruction}"
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
  end

end
