require "../constants/constants.cr"

module VM
  include Constants

  struct Header
    property valid : Bool
    property magic : StaticArray(UInt8, 4)
    property entry_addr : UInt32
    property load_table : Array(LoadTableEntry)
    property total_size : UInt32

    def initialize
      @valid = true
      @magic = StaticArray(UInt8, 4).new 0_u8
      @entry_addr = 0_u32
      @load_table = [] of LoadTableEntry
      @total_size = 0_u32
    end
  end

  struct LoadTableEntry
    property offset : UInt32
    property size : UInt32
    property address : UInt32

    def initialize
      @offset = 0_u32
      @size = 0_u32
      @address = 0_u32
    end
  end

  class Machine
    property memory : Bytes
    property regs : Bytes
    property running : Bool

    def initialize
      @memory = Machine.get_shared_memory_region "machine.memory", MEMORY_SIZE
      @regs = Bytes.new 64 * 8 # 64 registers of 8 bytes each
      @running = false
    end

    # Returns a new shared memory region for *filename* and *size*
    #
    # Tries to create the file
    protected def self.get_shared_memory_region(filename, size)
      file : File?

      if File.exists?(filename) && File.readable?(filename)
        file = File.open filename, "r+" rescue nil
      else
        file = File.open filename, "w+" rescue nil
      end

      unless file
        raise "could not open file: #{filename}"
      end

      file.write Bytes.new size
      file.flush

      # map the file into memory
      ptr = LibC.mmap(nil, size, LibC::PROT_READ | LibC::PROT_WRITE, LibC::MAP_SHARED, file.fd, 0)

      # check if the file could be mapped
      if ptr == Pointer(Void).new -1
        raise "could not map #{filename} into memory"
      end

      ptr = Pointer(UInt8).new ptr.address
      mapped_memory = Bytes.new ptr, size
      mapped_memory
    end

    # Clean all resources the machine created
    def clean
      ptr = Pointer(Void).new @memory.to_unsafe.address
      LibC.munmap(ptr, @memory.size)
    end

    # Extracts header information from *data*
    def read_header(data : Bytes)
      header = Header.new

      # Check data size
      if data.size < 12
        header.valid = false
        return header
      end

      # Read magic numbers
      header.magic[0] = data[0]
      header.magic[1] = data[1]
      header.magic[2] = data[2]
      header.magic[3] = data[3]

      # Check magic numbers for validity (NICE in ascii codes)
      unless header.magic[0] == 0x4e && header.magic[1] == 0x49 &&
             header.magic[2] == 0x43 && header.magic[3] == 0x45
        header.valid = false
        return header
      end

      # Read entry address
      header.entry_addr = (data + 4).to_unsafe.as(UInt32*)[0]

      # Read the size of the load table
      load_table_entry_count = (data + 8).to_unsafe.as(UInt32*)[0]
      load_table_bytesize = load_table_entry_count * 3 * 4

      # Check that there are enough bytes for all load table entries
      if data.size < 12 + load_table_bytesize
        header.valid = false
        return header
      end

      # Extract all entries from the load table
      load_table_bytes = (data + 12).to_unsafe.as(LoadTableEntry*)
      load_table_entry_count.times do |index|
        header.load_table << load_table_bytes[index]
      end

      header.total_size = (12 + load_table_bytesize).to_u32

      # Check that all segments point to valid memory segments
      header.load_table.each do |entry|
        offset, size, address = entry.offset, entry.size, entry.address
        offset_end = offset + size

        if offset_end >= data.size
          header.valid = false
          return header
        end
      end

      header
    end

    # Resets and copies *data* into the machine's memory
    #
    # Raises if *data* doesn't fit into the machine's memory
    def flash(data : Bytes)
      header = read_header data

      # Check invalid header
      unless header.valid
        raise Error.new(
          ErrorCode::INVALID_EXECUTABLE,
          "Malformed executable header"
        )
      end

      # Initialize registers
      @regs.to_unsafe.clear 64
      reg_write Register::SP.dword, STACK_BASE # starting address of the stack
      reg_write Register::FP.dword, MEMORY_SIZE # out-of-bounds, causes crash on access
      reg_write Register::IP.dword, header.entry_addr

      # Clear out memory
      @memory.to_unsafe.clear MEMORY_SIZE

      if header.load_table.size == 0
        segment = data + header.total_size
        mem_write 0, segment
      end

      # Copy all segments to their addresses in machine memory
      header.load_table.each do |entry|
        next if entry.size == 0 # skip empty segments

        segment = data[header.total_size + entry.offset, entry.size]
        mem_write entry.address, segment
      end

      self
    end

    # Writes 0 to all memory locations
    def reset_memory
      0.upto(@memory.bytesize - 1) do |i|
        @memory[i] = 0_u8
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

      # Check if an interrupt happened
      int_status = mem_read UInt8, INTERRUPT_STATUS

      if int_status != 0
        handle_interrupt
      end

      # Execute the current instruction
      instruction = fetch
      old_ip = reg_read UInt32, Register::IP.dword

      execute instruction, old_ip

      # Only increment the IP if the last instruction didn't modify it
      if old_ip == reg_read UInt32, Register::IP.dword
        instruction_length = decode_instruction_length instruction
        new_ip = old_ip + instruction_length
        reg_write Register::IP.dword, new_ip
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
      address = reg_read UInt32, Register::IP.dword
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
      when Opcode::ADD
        op_add ip
      when Opcode::SUB
        op_sub ip
      when Opcode::MUL
        op_mul ip
      when Opcode::DIV
        op_div ip
      when Opcode::IDIV
        op_idiv ip
      when Opcode::REM
        op_rem ip
      when Opcode::IREM
        op_irem ip
      when Opcode::FADD
        op_fadd ip
      when Opcode::FSUB
        op_fsub ip
      when Opcode::FMUL
        op_fmul ip
      when Opcode::FDIV
        op_fdiv ip
      when Opcode::FREM
        op_frem ip
      when Opcode::FEXP
        op_fexp ip
      when Opcode::FLT
        op_flt ip
      when Opcode::FGT
        op_fgt ip
      when Opcode::CMP
        op_cmp ip
      when Opcode::LT
        op_lt ip
      when Opcode::GT
        op_gt ip
      when Opcode::ULT
        op_ult ip
      when Opcode::UGT
        op_ugt ip
      when Opcode::SHR
        op_shr ip
      when Opcode::SHL
        op_shl ip
      when Opcode::AND
        op_and ip
      when Opcode::XOR
        op_xor ip
      when Opcode::OR
        op_or ip
      when Opcode::NOT
        op_not ip
      when Opcode::INTTOFP
        op_inttofp ip
      when Opcode::SINTTOFP
        op_sinttofp ip
      when Opcode::FPTOINT
        op_fptoint ip
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
        address = reg_read UInt32, Register::IP.dword
        reg = Register.new mem_read UInt8, address + 1

        #      +- Opcode
        #      |   +- Target register
        #      |   |   +- Value
        #      |   |   |
        #      v   v   v
        return 1 + 1 + reg.bytecount
      when Opcode::PUSH
        address = reg_read UInt32, Register::IP.dword
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
      target = @regs[reg.regcode.to_i32 * 8, reg.bytecount]
      target.to_unsafe.clear reg.bytecount
      data = data[0, target.size] if data.size > target.size
      target.copy_from data
      self
    end

    # Reads a *type* value from *register*
    def reg_read(x : T.class, reg : Register) forall T
      source = @regs[reg.regcode.to_i32 * 8, reg.bytecount]

      # Zero pad values smaller than 8 bytes
      bytes = Bytes.new 8
      bytes.copy_from source
      ptr = Pointer(T).new bytes.to_unsafe.address
      ptr[0]
    end

    # Reads all bytes from *reg*
    def reg_read(reg : Register)
      @regs[reg.regcode.to_i32 * 8, reg.bytecount]
    end

    # Writes *data* to *address*
    def mem_write(address, data : T) forall T
      bytes = get_bytes data
      mem_write address, bytes
    end

    # :ditto:
    def mem_write(address, data : Bytes)
      illegal_memory_access address unless legal_address address + data.size - 1
      target = @memory + address
      target.copy_from data
      self
    end

    # Reads a *type* value from *address*
    def mem_read(x : T.class, address) forall T
      illegal_memory_access address unless legal_address address + sizeof(T) - 1
      source = @memory + address
      ptr = Pointer(T).new source.to_unsafe.address
      ptr[0]
    end

    # Reads *count* bytes from *address*
    def mem_read(count, address)
      illegal_memory_access address unless legal_address address + count - 1
      @memory[address, count]
    end

    # Pushes *value* onto the stack
    def stack_write(data : Bytes)
      sp = reg_read UInt32, Register::SP.dword
      address = sp - data.size
      mem_write address, data
      sp -= data.size
      reg_write Register::SP.dword, sp
    end

    # Pushes *value* onto the stack
    def stack_write(value : T) forall T
      stack_write get_bytes value
    end

    # Reads *count* bytes from the stack
    def stack_peek(count)
      sp = reg_read UInt32, Register::SP.dword
      mem_read count, address
    end

    # Reads a *T* value from the stack
    def stack_peek(x : T.class) forall T
      sp = reg_read UInt32, Register::SP.dword
      mem_read T, sp
    end

    # Pops *count* bytes off the stack
    def stack_pop(count)
      sp = reg_read UInt32, Register::SP.dword
      bytes = mem_read count, sp
      reg_write Register::SP.dword, sp + count
      bytes
    end

    # Pops a *T* value off the stack
    def stack_pop(x : T.class) forall T
      sp = reg_read UInt32, Register::SP.dword
      value = mem_read T, sp
      reg_write Register::SP.dword, sp + sizeof(T)
      value
    end

    # Returns true if *address* is legal
    def legal_address(address)
      address >= 0 && address < @memory.size
    end

    # Set or unset the zero bit in the flags register
    def set_zero_flag(set : Bool)
      reg_write Register::FLAGS.byte, set ? 1 : 0
    end

    # Pushes a stack frame for the return address *retaddr*
    def push_stack_frame(retaddr : UInt32)
      frameptr = reg_read UInt32, Register::FP.dword

      # Base address of this stack frame. This is a pointer to a dword which will
      # later be populated with the old frame pointer
      stack_frame_baseadr = (reg_read UInt32, Register::SP.dword) - 8

      # Push the new stack frame
      stack_write retaddr
      stack_write frameptr

      # Update FP and IP
      reg_write Register::FP.dword, stack_frame_baseadr
    end

    # :nodoc:
    private def illegal_memory_access(address)
      ip = reg_read UInt32, Register::IP.dword
      ip = ("0x" + (ip.to_s(16).rjust(8, '0'))).colorize :red
      address = ("0x" + (address.to_s(16).rjust(8, '0'))).colorize :yellow

      raise Error.new(
        ErrorCode::ILLEGAL_MEMORY_ACCESS,
        "#{ip}: Illegal memory access at #{address}"
      )
    end

    # :nodoc:
    private def invalid_instruction(instruction : Opcode)
      raise Error.new ErrorCode::INVALID_INSTRUCTION, "Unknown instruction: #{instruction}"
    end

    # :nodoc:
    private def invalid_syscall(syscall : Syscall)
      raise Error.new ErrorCode::INVALID_SYSCALL, "Unknown sycall: #{syscall}"
    end

    # Handle an interrupt
    private def handle_interrupt

      # Reset the interrupt status flag
      mem_write INTERRUPT_STATUS, Bytes.new 1 { 0_u8 }

      # Read the address of the interrupt handler
      int_handler = mem_read UInt32, INTERRUPT_HANDLER_ADDRESS

      # Push a stack frame to the current instruction
      stack_write Bytes.new 4 { 0_u8 }
      push_stack_frame reg_read(UInt32, Register::IP.dword)
      reg_write Register::IP.dword, int_handler
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
    # rpop r0
    # ```
    private def op_rpop(ip)
      reg = Register.new mem_read(UInt8, ip + 1)
      value = stack_pop reg.bytecount
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
      value = mem_read target.bytecount, ip + 2
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

    # Macro to reduce duplicate code for arithmetic instructions
    private macro impl_arithmetic_instruction(name, type, operator)
      private def op_{{name}}(ip)
        left_reg = Register.new mem_read(UInt8, ip + 1)
        right_reg = Register.new mem_read(UInt8, ip + 2)
        left = reg_read {{type}}, left_reg
        right = reg_read {{type}}, right_reg
        result = left {{operator.id}} right
        reg_write left_reg, result
        set_zero_flag result == 0
      end
    end

    # Macro to reduce duplicate code for comparison instructions
    private macro impl_comparison_instruction(name, type, operator)
      private def op_{{name}}(ip)
        left = Register.new mem_read(UInt8, ip + 1)
        right = Register.new mem_read(UInt8, ip + 2)

        left = reg_read {{type}}, left
        right = reg_read {{type}}, right

        set_zero_flag left {{operator.id}} right
      end
    end

    # Integer arithmetic instructions
    impl_arithmetic_instruction add, UInt64, :+
    impl_arithmetic_instruction sub, UInt64, :-
    impl_arithmetic_instruction mul, UInt64, :*
    impl_arithmetic_instruction div, UInt64, :/
    impl_arithmetic_instruction idiv, Int64, :/
    impl_arithmetic_instruction rem, UInt64, :%
    impl_arithmetic_instruction irem, Int64, :%

    # Integer comparison instructions
    impl_comparison_instruction cmp, Int64, :==
    impl_comparison_instruction lt, Int64, :<
    impl_comparison_instruction gt, Int64, :>
    impl_comparison_instruction ult, UInt64, :<
    impl_comparison_instruction ugt, UInt64, :>

    # Floating-point arithmetic instructions
    impl_arithmetic_instruction fadd, Float64, :+
    impl_arithmetic_instruction fsub, Float64, :-
    impl_arithmetic_instruction fmul, Float64, :*
    impl_arithmetic_instruction fdiv, Float64, :/
    impl_arithmetic_instruction frem, Float64, :%
    impl_arithmetic_instruction fexp, Float64, :**

    # Floating-point comparison instructions
    impl_comparison_instruction flt, Float64, :<
    impl_comparison_instruction fgt, Float64, :>

    # Bitwise instructions
    impl_arithmetic_instruction shr, UInt64, :<<
    impl_arithmetic_instruction shl, UInt64, :>>
    impl_arithmetic_instruction and, UInt64, :&
    impl_arithmetic_instruction xor, UInt64, :^
    impl_arithmetic_instruction or, UInt64, :|

    # Executes a not instruction
    #
    # ```
    # not r0, r1
    # ```
    private def op_not(ip)
      num_reg = Register.new mem_read(UInt8, ip + 2)
      num = reg_read UInt64, num_reg
      result = ~num
      reg_write num_reg, result
      set_zero_flag result == 0
    end

    # Executes a inttofp instruction
    #
    # ```
    # inttofp r0, r1
    # ```
    private def op_inttofp(ip)
      source_reg = Register.new mem_read(UInt8, ip + 1)
      source = reg_read UInt64, source_reg
      reg_write source_reg, source.to_f64
    end

    # Executes a sinttofp instruction
    #
    # ```
    # sinttofp r0, r1
    # ```
    private def op_sinttofp(ip)
      source_reg = Register.new mem_read(UInt8, ip + 1)
      source = reg_read Int64, source_reg
      reg_write source_reg, source.to_f64
    end

    # Executes a fptoint instruction
    #
    # ```
    # fptoint r0, r1
    # ```
    private def op_fptoint(ip)
      source_reg = Register.new mem_read(UInt8, ip + 1)
      source = reg_read Float64, source_reg
      reg_write source_reg, source.to_i64
    end

    # Executes a load instruction
    #
    # ```
    # load r0, -20
    # ```
    private def op_load(ip)
      reg = Register.new mem_read(UInt8, ip + 1)
      offset = mem_read(UInt32, ip + 2)
      frameptr = reg_read UInt32, Register::FP.dword
      address = frameptr + offset
      value = mem_read reg.bytecount, address
      reg_write reg, value
    end

    # Executes a loadr instruction
    #
    # ```
    # loadr r0, r1
    # ```
    private def op_loadr(ip)
      reg = Register.new mem_read(UInt8, ip + 1)
      offset = Register.new mem_read(UInt8, ip + 2)
      offset = reg_read Int32, offset
      frameptr = reg_read UInt32, Register::FP.dword
      address = frameptr + offset
      value = mem_read reg.bytecount, address
      reg_write reg, value
    end

    # Executes a loads instruction
    #
    # ```
    # loads qword, -8
    # ```
    private def op_loads(ip)
      size = mem_read UInt32, ip + 1
      offset = mem_read Int32, ip + 5
      frameptr = reg_read UInt32, Register::FP.dword
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
      offset = Register.new mem_read UInt8, ip + 5
      offset = reg_read Int32, offset
      frameptr = reg_read UInt32, Register::FP.dword
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
      offset = mem_read Int32, ip + 1
      source = Register.new mem_read(UInt8, ip + 5)
      value = reg_read source
      frameptr = reg_read UInt32, Register::FP.dword
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
      address = reg_read UInt32, source
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
      address = mem_read UInt32, ip + 2
      value = mem_read target.bytecount, address
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
      address = reg_read UInt32, source
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
      address = mem_read UInt32, ip + 5
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
      address = reg_read UInt32, target
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
      address = mem_read UInt32, ip + 1
      source = Register.new mem_read(UInt8, ip + 5)
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
      address = reg_read UInt32, target
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
      address = mem_read UInt32, ip + 1
      size = mem_read UInt32, ip + 5
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
      target_adr = reg_read UInt32, target
      source_adr = reg_read UInt32, source
      value = mem_read size, source_adr
      mem_write target_adr, value
    end

    # Executes a copyc instruction
    #
    # ```
    # copyc target, qword, source
    # ```
    private def op_copyc(ip)
      target = mem_read(UInt32, ip + 1)
      size = mem_read UInt32, ip + 5
      source = mem_read(UInt32, ip + 9)
      value = mem_read size, source
      mem_write target, value
    end

    # Executes a jz instruction
    #
    # ```
    # jz myfunction
    # ```
    private def op_jz(ip)
      address = mem_read UInt32, ip + 1
      flags = reg_read UInt8, Register::FLAGS.byte
      zero = flags & Flag::ZERO.value
      reg_write Register::IP.dword, address if zero != 0
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
      address = reg_read UInt32, target
      flags = reg_read UInt8, Register::FLAGS.byte
      zero = flags & Flag::ZERO.value
      reg_write Register::IP.dword, address if zero != 0
    end

    # Executes a jmp instruction
    #
    # ```
    # jmp myfunction
    # ```
    private def op_jmp(ip)
      address = mem_read UInt32, ip + 1
      reg_write Register::IP.dword, address
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
      address = reg_read UInt32, target
      reg_write Register::IP.dword, address
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
      address = mem_read UInt32, ip + 1
      return_address = ip + decode_instruction_length(fetch)
      push_stack_frame return_address.to_u32
      reg_write Register::IP.dword, address
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
    # callr r0
    # ```
    private def op_callr(ip)
      target = Register.new mem_read(UInt8, ip + 1)
      address = reg_read UInt32, target
      return_address = ip + decode_instruction_length(fetch)
      push_stack_frame return_address.to_u32
      reg_write Register::IP.dword, address
    end

    # Executes a ret instruction
    #
    # ```
    # ret
    # ```
    private def op_ret(ip)

      # Read current stack frame
      stack_frame_baseadr = reg_read UInt32, Register::FP.dword
      frame_pointer = mem_read UInt32, stack_frame_baseadr
      return_address = mem_read UInt32, stack_frame_baseadr + 4
      argument_count = mem_read UInt32, stack_frame_baseadr + 8
      stack_pointer = stack_frame_baseadr + 12 + argument_count

      # Restore old state
      reg_write Register::SP.dword, stack_pointer
      reg_write Register::FP.dword, frame_pointer
      reg_write Register::IP.dword, return_address
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
      perform_syscall id, reg_read(UInt32, Register::SP.dword)
    end

    # Syscall router
    private def perform_syscall(id : Syscall, stackptr : UInt32)
      case id
      when Syscall::EXIT
        exit_code = stack_pop UInt8
        reg_write Register::R0.byte, exit_code
        @running = false
      when Syscall::SLEEP
        seconds = stack_pop Float64
        sleep seconds
      when Syscall::WRITE
        count = stack_pop UInt32
        address = stack_pop UInt32

        illegal_memory_access address + count unless legal_address address + count - 1
        bytes = @memory[address, count]

        STDOUT.write bytes
        STDOUT.flush
      when Syscall::PUTS
        reg = Register.new stack_pop UInt8
        value = reg_read Int32, reg
        STDOUT.puts "#{value}"
      when Syscall::READ
        reg = Register.new stack_pop UInt8
        char = STDIN.raw &.read_char
        if char.is_a?(Char)
          reg_write reg, char.ord
        end
      else
        invalid_syscall id
      end
    end
  end
end
