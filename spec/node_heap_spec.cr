require "spec"
require "../src/heap_process"

describe HeapLeak::NodeHeap do

  it "loads objects" do
    contents = <<-END
      {
        "snapshot": {
          "meta": {
            "node_fields":["type","name","id","self_size","edge_count","trace_node_id","detachedness"],
            "node_types":[["hidden","array","string","object","code","closure","regexp","number","native","synthetic","concatenated string","sliced string","symbol","bigint"],"string","number","number","number","number","number"],
            "edge_fields":["type","name_or_index","to_node"],
            "edge_types":[["context","element","property","internal","hidden","shortcut","weak"],"string_or_number","node"],
            "trace_function_info_fields":["function_id","name","script_name","script_id","line","column"],
            "trace_node_fields":["id","function_info_index","count","size","children"],
            "sample_fields":["timestamp_us","last_assigned_id"],
            "location_fields":["object_index","script_id","line","column"]
          },
          "node_count":42367,
          "edge_count":182197,
          "trace_function_count":0
        },
        "nodes": [
          9,1,1,0,11,0,0
          ,9,2,3,0,25,0,0
          ,9,3,5,0,7650,0,0
          ,9,4,7,0,42,0,0
        ],
        "edges": [],
        "trace_function_infos": [],
        "trace_tree": [],
        "samples": [],
        "locations": [],
        "strings": []
      }
    END
    heap = HeapLeak::NodeHeap.new(IO::Memory.new(contents))
  end
end
