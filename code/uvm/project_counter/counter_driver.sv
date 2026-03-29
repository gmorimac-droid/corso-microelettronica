class counter_driver extends uvm_driver #(counter_item);
  `uvm_component_utils(counter_driver)

  virtual counter_if vif;

  function new(string name, uvm_component parent);
    super.new(name, parent);
  endfunction

  function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    if (!uvm_config_db#(virtual counter_if)::get(this, "", "vif", vif))
      `uvm_fatal("NOVIF", "virtual interface non trovata")
  endfunction

  task run_phase(uvm_phase phase);
    counter_item tr;

    forever begin
      seq_item_port.get_next_item(tr);

      @(posedge vif.clk);
      vif.reset  <= tr.reset;
      vif.enable <= tr.enable;

      `uvm_info("DRV", $sformatf("Drive: %s", tr.convert2string()), UVM_MEDIUM)

      seq_item_port.item_done();
    end
  endtask
endclass
