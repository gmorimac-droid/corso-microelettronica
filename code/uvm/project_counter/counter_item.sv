class counter_item extends uvm_sequence_item;
  rand bit reset;
  rand bit enable;

  `uvm_object_utils(counter_item)

  function new(string name = "counter_item");
    super.new(name);
  endfunction

  function string convert2string();
    return $sformatf("reset=%0b enable=%0b", reset, enable);
  endfunction
endclass
