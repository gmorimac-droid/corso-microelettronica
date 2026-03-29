class counter_mon_item extends uvm_sequence_item;
  bit reset;
  bit enable;
  bit [3:0] q;

  `uvm_object_utils(counter_mon_item)

  function new(string name = "counter_mon_item");
    super.new(name);
  endfunction

  function string convert2string();
    return $sformatf("reset=%0b enable=%0b q=%0d", reset, enable, q);
  endfunction
endclass
