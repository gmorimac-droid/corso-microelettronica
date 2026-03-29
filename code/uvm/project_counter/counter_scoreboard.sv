class counter_scoreboard extends uvm_scoreboard;
  `uvm_component_utils(counter_scoreboard)

  uvm_analysis_imp #(counter_mon_item, counter_scoreboard) analysis_export;
  bit [3:0] expected_q;

  function new(string name, uvm_component parent);
    super.new(name, parent);
    analysis_export = new("analysis_export", this);
    expected_q = 0;
  endfunction

  function void write(counter_mon_item item);
    if (item.reset)
      expected_q = 0;
    else if (item.enable)
      expected_q = expected_q + 1;

    if (item.q !== expected_q) begin
      `uvm_error("SB",
        $sformatf("Mismatch: atteso=%0d ricevuto=%0d", expected_q, item.q))
    end
    else begin
      `uvm_info("SB",
        $sformatf("OK: q=%0d", item.q), UVM_LOW)
    end
  endfunction
endclass
