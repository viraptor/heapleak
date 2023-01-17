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

def print_dot_diagram(heap, visible_objects, sample_addresses, output)
  closest_common = visible_objects.select { |o| (heap.objects[o].seen_from || "").size > 1 }.min_by { |o| heap.objects[o].distance }
  max_distance = heap.objects[closest_common].distance

  output.puts("# using a heap with #{heap.objects.size} objects")
  output.puts("# a pool of #{visible_objects.size} interesting objects")
  output.puts("# and #{sample_addresses.size} initial leaked objects")
  output.puts("digraph leak {")
  output.puts("rankdir=RL")

  output.puts("# sample addresses")
  output.puts("subgraph sources {")
  output.puts("style=filled; color=lightgrey;")
  sample_addresses.each { |sample_addr|
    current = heap.objects[sample_addr]
    output.puts("\"0x#{sample_addr.to_s(16)}\" [color=blue, label=\"0x#{sample_addr.to_s(16)}\\n#{heap.type_of(sample_addr)}\\n#{current.file}:#{current.line}\"] ;")
  }
  output.puts("}")

  output.puts("# other reachable entries")
  visible_objects.each { |current_addr|
    current = heap.objects[current_addr]
    next if sample_addresses.includes? current_addr
    next if current.distance > max_distance
    output.puts("\"0x#{current_addr.to_s(16)}\" [label=\"0x#{current_addr.to_s(16)}\\n#{heap.type_of(current_addr)}\\n#{current.file}:#{current.line}\"] ;")
  }

  output.puts("# links")
  visible_objects.each { |current_addr|
    next if heap.objects[current_addr].distance > max_distance
    heap.back_refs.fetch(current_addr, [] of HeapLeak::HEAP_ADDRESS).each {|ref|
      next if heap.objects[ref].distance > max_distance
      next unless visible_objects.includes? ref
      output.puts("\"0x#{ref.to_s(16)}\" -> \"0x#{current_addr.to_s(16)}\" ;")
    }
  }

  output.puts("}")
end
