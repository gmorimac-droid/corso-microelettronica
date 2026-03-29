class counter_monitor extends uvm_monitor;
  `uvm_component_utils(counter_monitor)

  virtual counter_if vif;
  uvm_analysis_port #(counter_mon_item) ap;

  function new(string name, uvm_component parent);
    super.new(name, parent);
    ap = new("ap", this);
  endfunction

  function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    if (!uvm_config_db#(virtual counter_if)::get(this, "", "vif", vif))
      `uvm_fatal("NOVIF", "virtual interface non trovata")
  endfunction

  task run_phase(uvm_phase phase);
    counter_mon_item item;

    forever begin
      @(posedge vif.clk);

      item = counter_mon_item::type_id::create("item");
      item.reset  = vif.reset;
      item.enable = vif.enable;
      item.q      = vif.q;

      ap.write(item);

      `uvm_info("MON", $sformatf("Monitor: %s", item.convert2string()), UVM_MEDIUM)
    end
  endtask
endclass
