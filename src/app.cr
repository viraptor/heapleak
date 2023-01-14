require "compress/gzip"
require "compress/gzip/reader"
require "./heap_process"

def load_heap(filename)
  io = if filename.ends_with?(".gz")
    Compress::Gzip::Reader.new(filename)
  else
    File.open(filename)
  end

  HeapLeak::Heap.new(io)
ensure
  io.close unless io.nil?
end

def leaked_objects(heap_A : HeapLeak::Heap, heap_B : HeapLeak::Heap, heap_C : HeapLeak::Heap)
  new_heap = HeapLeak::Heap.new(heap_B)
  new_heap.remove_objects!(heap_A)
  new_heap.keep_common!(heap_C)
  new_heap
end

def print_dot_diagram(heap, visible_objects, sample_addresses, max_distance)
  puts("# using a heap with #{heap.objects.size} objects")
  puts("# a pool of #{visible_objects.size} interesting objects")
  puts("# and #{sample_addresses.size} initial leaked objects")
  puts("digraph leak {")
  puts("rankdir=RL")

  puts("# sample addresses")
  puts("subgraph sources {")
  puts("style=filled; color=lightgrey;")
  sample_addresses.each { |sample_addr|
    current = heap.objects[sample_addr]
    puts("\"0x#{sample_addr.to_s(16)}\" [color=blue, label=\"0x#{sample_addr.to_s(16)}\\n#{heap.type_of(sample_addr)}\\n#{current.file}:#{current.line}\"] ;")
  }
  puts("}")

  puts("# other reachable entries")
  visible_objects.each { |current_addr|
    current = heap.objects[current_addr]
    next if sample_addresses.includes? current_addr
    next if current.distance > max_distance
    puts("\"0x#{current_addr.to_s(16)}\" [label=\"0x#{current_addr.to_s(16)}\\n#{current.class_name}\\n#{current.file}:#{current.line}\"] ;")
  }

  puts("# links")
  visible_objects.each { |current_addr|
    next if heap.objects[current_addr].distance > max_distance
    heap.back_refs.fetch(current_addr, [] of HeapLeak::HEAP_ADDRESS).each {|ref|
      next if heap.objects[ref].distance > max_distance
      next unless visible_objects.includes? ref
      puts("\"0x#{ref.to_s(16)}\" -> \"0x#{current_addr.to_s(16)}\" ;")
    }
  }

  puts("}")
end
