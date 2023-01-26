require "json"

module HeapLeak
  alias HEAP_ADDRESS = Int64

  RUBY_TYPENAMES = {} of String => String

  MAX_DIST = 1000000

  class ShortHeapObject
    property distance : Int32 = MAX_DIST
    property seen_from : Set(HEAP_ADDRESS)?
    property refs : Array(HEAP_ADDRESS)
    property class_addr : HEAP_ADDRESS?
    property class_name : String
    property file : String?
    property line : Int32?
    def initialize(@class_name : String, @class_addr : (HEAP_ADDRESS | Nil), @refs : Array(HEAP_ADDRESS))
    end
  end

  class HeapObject
    include JSON::Serializable

    property address : String?
    property type : String?
    @[JSON::Field(key: "class")]
    property klass : String?
    property references : Array(String)?
    property name : String?
    property file : String?
    property line : Int32?
  end

  class Heap
    getter objects = {} of HEAP_ADDRESS => ShortHeapObject
    getter back_refs = {} of HEAP_ADDRESS => Array(HEAP_ADDRESS)
    getter types = {} of HEAP_ADDRESS => String

    def initialize(io : IO)
      load(io)
    end

    def initialize(other_heap : Heap)
      @objects = other_heap.objects.dup
      @types = other_heap.types.dup
    end

    def load(io)
      io.each_line do |line|
        begin
          obj = HeapObject.from_json(line)
        rescue
          next
        end
        next if obj.address.nil?

        if !(o_type = obj.type).nil?
          RUBY_TYPENAMES[o_type] = o_type unless RUBY_TYPENAMES.has_key?(o_type)
        end

        short_obj = ShortHeapObject.new(
          RUBY_TYPENAMES[obj.type],
          ((klass=obj.klass).nil? ? nil : klass.to_i64(prefix: true)),
          (obj.references || ([] of String)).map {|x| x.to_i64(prefix: true)}
        )
        addr = obj.address.as(String).to_i64(prefix: true)
        if (obj.type == "CLASS" || obj.type == "MODULE") && !(name=obj.name).nil?
          types[addr] = name
        end
        short_obj.file = obj.file unless obj.file.nil?
        short_obj.line = obj.line unless obj.line.nil?

        objects[addr] = short_obj
        fill_backref(addr, short_obj)
      end
    end

    def fill_backref(addr, short_obj)
      short_obj.refs.each do |ref|
        back_refs[ref] = back_refs.fetch(ref, [] of HEAP_ADDRESS).push(addr)
      end
    end

    def type_of(addr : HEAP_ADDRESS)
      obj = objects[addr]
      if obj.class_name == "CLASS"
        "CLASS:#{types.fetch(addr, "<unknown>")}"
      elsif obj.class_name == "MODULE"
        "MODULE:#{types.fetch(addr, "<unknown>")}"
      elsif obj.class_name == "OBJECT"
        types.fetch(obj.class_addr, "<unknown>")
      else
        obj.class_name
      end
    end

    def mark_distance_and_visibility(sample_addresses : Array(HEAP_ADDRESS), distance_limit = 10)
      sample_addresses.each do |x|
        objects[x].distance = 0
        objects[x].seen_from = Set{x}
      end

      to_process = sample_addresses.clone
      seen = Set(HEAP_ADDRESS).new

      lowest_common = MAX_DIST

      while !to_process.empty?
        current = to_process.pop
        next_distance = objects[current].distance + 1
        seen << current
        next if next_distance > distance_limit
        back_refs.fetch(current, [] of HEAP_ADDRESS).each { |x|
          objects[x].distance = next_distance if (objects[x].distance || MAX_DIST) > next_distance
          objects[x].seen_from = (objects[x].seen_from || Set(HEAP_ADDRESS).new) + objects[current].seen_from.as(Set(HEAP_ADDRESS))
          to_process.push(x) unless seen.includes?(x)
        }
      end

      seen
    end

    def remove_objects!(other_heap)
      other_heap.objects.each do |k, v|
        if objects.has_key?(k) && v.class_addr == objects[k].class_addr
          objects.delete(k)
        end
      end
    end

    def keep_common!(other_heap)
      objects.each do |k, v|
        if !other_heap.objects.has_key?(k) || v.class_addr != other_heap.objects[k].class_addr
          objects.delete(k)
        end
      end
    end

    def inspect
      "Heap (objects: #{objects.size} types: #{types.size} refs: #{back_refs.size})"
    end
  end

  class NodeHeap
    def initialize(io : IO)
      load(io)
    end

    def load(io)
      pull = JSON::PullParser.new(io)
      pull.read_object { |key|
        puts "top: #{key}"
        if key == "snapshot"
          load_top_snapshot(pull)
        elsif key == "nodes"
          load_top_nodes(pull)
        elsif key == "edges"
          load_top_edges(pull)
        else
          pull.read_raw
        end
      }
    end

    def load_top_edges(pull)
        pull.read_array { pull.read_int }
    end
    def load_top_nodes(pull)
      pull.read_array { pull.read_int }
    end
    def load_top_snapshot(pull)
      pull.read_raw
    end
  end
end
