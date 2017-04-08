require "../constants/constants.cr"

module VM
  include Constants

  MEMORY_SIZE = 2 ** 16 # default memory size

  class Machine
    property memory : Bytes
    property regs : Bytes
    property executable_size : Int64

    def initialize(memory_size = MEMORY_SIZE)
      @executable_size = 0_i64
      @memory = Bytes.new memory_size
      @regs = Bytes.new 64 * 8 # 64 registers of 8 bytes each
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
      reg_set Register::SP, @executable_size
      reg_set Register::FP, @executable_size

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

    # :nodoc:
    private def get_bytes(data : T) forall T
      slice = Slice(T).new 1, data
      pointer = Pointer(UInt8).new slice.to_unsafe.address
      size = sizeof(T)
      bytes = Bytes.new pointer, size
      bytes
    end

    # Sets the value of *reg* to *data*
    def reg_set(reg : Register, data : T) forall T
      bytes = get_bytes data
      reg_set reg, bytes
    end

    # :ditto:
    def reg_set(reg : Register, data : Bytes)
      target = @regs[reg.regcode, reg.bytecount]
      target.copy_from data

      self
    end
  end

end
