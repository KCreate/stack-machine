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
        @running = false
      end

      self
    end

    # Runs a single cpu cycle
    def cycle
      instruction = fetch
      old_ip = reg_read UInt64, Register::IP
      execute instruction

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
    def execute(instruction : Opcode)
      puts "executing #{instruction}"
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
      target = @regs[reg.regcode * 8, reg.bytecount]
      target.copy_from data
      self
    end

    # Reads a *type* value from *register*
    def reg_read(type, reg : Register)
      invalid_register_access reg unless legal_reg reg
      source = @regs[reg.regcode * 8, reg.bytecount]
      IO::ByteFormat::LittleEndian.decode(type, source)
    end

    # Writes *data* to *address*
    def mem_write(address, data : T) forall T
      bytes = get_bytes data
      mem_write address, bytes
    end

    # :ditto:
    def mem_write(address, data : Bytes)
      illegal_memory_access address unless legal_address address
      target = @memory + address
      target.copy_from data
      self
    end

    # Reads a *type* value from *address*
    def mem_read(type, address)
      illegal_memory_access address unless legal_address address
      source = @memory + address
      IO::ByteFormat::LittleEndian.decode(type, source)
    end

    # Returns true if *reg* is legal
    def legal_reg(reg : Register)
      reg.regcode >= 0 && reg.regcode <= 64
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
  end

end
