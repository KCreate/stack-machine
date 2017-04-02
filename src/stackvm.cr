module StackVM
  filename = ARGV[0]?

  unless filename
    puts "Missing filename"
    exit 1
  end

  size = File.size filename
  content = Bytes.new size
  File.open filename do |file|
    file.read content
  end

  puts content.hexdump
end
