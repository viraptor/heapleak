require "./app"
require "colorize"

action = ARGV.fetch(0, "help")

if action == "stats"
  if ARGV.size < 4
    puts("Error: 3 arguments with heap files required")
    exit
  end
  h1, h2, h3 = [load_heap(ARGV[1]), load_heap(ARGV[2]), load_heap(ARGV[3])]
  leaked_objects = leaked_objects(h1, h2, h3)

  count_class = {} of String => Int32
  samples = {} of String => Array(HeapLeak::HEAP_ADDRESS)
  leaked_objects.objects.each do |addr, obj|
    name = leaked_objects.type_of(addr)
    count_class[name] = count_class.fetch(name, 0) + 1
    samples[name] = [] of HeapLeak::HEAP_ADDRESS unless samples.has_key?(name)
    samples[name].push(addr) unless samples[name].size > 5
  end

  puts "Potentially leaked objects:".colorize(:light_gray)
  count_class.each do |k, v|
    puts "#{k.to_s.colorize(:default)}: #{v.to_s.colorize(:light_blue)}"
    puts "  #{samples[k].map{|x| "0x#{x.to_s(16)}"}.join(" ").colorize(:dark_gray)}"
  end
elsif action == "root"
  if ARGV.size < 4
    puts("Error: At least the heap and 2 sample addresses are required to find a common reference")
    exit
  end
  heap = load_heap(ARGV[1])
  sample_addresses = ARGV[2..].map {|x| x.to_i64(prefix: true)}

  visible_objects = heap.mark_distance_and_visibility(sample_addresses)
  print_dot_diagram(heap, visible_objects, sample_addresses, STDOUT)
else
  puts "#{"Usage:".colorize(:light_blue)} #{PROGRAM_NAME.colorize(:dark_gray)} ACTION [ARGUMENTS]"
  puts ""
  puts "Process Ruby heap dumps created with ObjectSpace.dump_all to get a debug"
  puts "memory leaks."
  puts "Both plain and gzipped heaps are supported."
  puts ""
  puts "#{"Actions:".colorize(:light_blue)}"
  puts ""
  puts "  #{"stats".colorize(:light_blue)} (initial_heap) (first_change_heap) (second_change_heap)"
  puts "    Get a list of objects allocated in the first change and not freed"
  puts "    in the second."
  puts ""
  puts "  #{"root".colorize(:light_blue)} (first_change_heap) (sample_address1) (sample_address2) ..."
  puts "    Find a common object which holds the reference to all the provided"
  puts "    sample addresses (direct or indirect). Print out a .dot diagram"
  puts "    showing the paths."
  puts ""
  puts "    Convert it to other formats with (for example):"
  puts "    dot -Tpng -o foo.png foo.dot"
end
