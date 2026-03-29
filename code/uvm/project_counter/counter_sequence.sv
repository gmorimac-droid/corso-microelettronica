class counter_sequence extends uvm_sequence #(counter_item);
  `uvm_object_utils(counter_sequence)

  function new(string name = "counter_sequence");
    super.new(name);
  endfunction

  task body();
    counter_item req;

    // reset iniziale
    req = counter_item::type_id::create("req");
    start_item(req);
    req.reset  = 1;
    req.enable = 0;
    finish_item(req);

    // alcune transazioni normali
    repeat (10) begin
      req = counter_item::type_id::create("req");
      start_item(req);
      req.reset  = 0;
      req.enable = 1;
      finish_item(req);
    end

    // pausa
    repeat (3) begin
      req = counter_item::type_id::create("req");
      start_item(req);
      req.reset  = 0;
      req.enable = 0;
      finish_item(req);
    end
  endtask
endclass
