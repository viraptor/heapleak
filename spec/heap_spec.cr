require "spec"
require "../src/heap_process"

describe HeapLeak::Heap do
  it "loads objects" do
    contents = <<-END
      {"address":"0x560a5a537888", "type":"MODULE", "class":"0x560a5a6c3738", "name":"Gem", "references":[]}
      {"address":"0x560a5a6c3738", "type":"CLASS", "class":"0x560a5a5c76e0", "name":"Module", "references":[]}
    END
    heap = HeapLeak::Heap.new(IO::Memory.new(contents))
    heap.objects.size.should eq(2)
    heap.types.size.should eq(2)
    heap.type_of(0x560a5a537888).should eq("MODULE:Gem")
  end

  it "loads refs" do
    contents = <<-END
      {"address":"0x560a5a537888", "type":"MODULE", "class":"0x560a5a6c3738", "name":"Gem", "references":["0x560a5a5378b0"]}
      {"address":"0x560a5a5378b0", "type":"STRING", "class":"0x560a5a5bf5a8"}
    END
    heap = HeapLeak::Heap.new(IO::Memory.new(contents))
    heap.back_refs.size.should eq(1)
    heap.back_refs[0x560a5a5378b0].should contain(0x560a5a537888)
  end

  it "calculates visibility" do
    contents = <<-END
      {"address":"0x560a5a537888", "type":"MODULE", "class":"0x560a5a6c3738", "name":"Gem", "references":["0x560a5a5378b0"]}
      {"address":"0x560a5a5378b0", "type":"STRING", "class":"0x560a5a5bf5a8"}
      {"address":"0x560a5a5378b1", "type":"STRING", "class":"0x560a5a5bf5a8"}
    END
    heap = HeapLeak::Heap.new(IO::Memory.new(contents))
    heap.mark_distance_and_visibility([0x560a5a5378b0])
    heap.objects[0x560a5a5378b0].distance.should eq(0)
    heap.objects[0x560a5a537888].distance.should eq(1)
    heap.objects[0x560a5a537888].seen_from.should eq(Set{0x560a5a5378b0})
  end
end
