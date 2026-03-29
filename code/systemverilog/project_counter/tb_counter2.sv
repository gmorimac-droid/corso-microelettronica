timeunit 1ns;
timeprecision 1ps;

module tb_counter;

  localparam int N = 4;

  logic         clk;
  logic         reset;
  logic         enable;
  logic [N-1:0] q;

  // DUT
  counter #(.N(N)) dut (
    .clk   (clk),
    .reset (reset),
    .enable(enable),
    .q     (q)
  );

  // Clock generator: periodo 10 ns
  always #5ns clk = ~clk;

  // -----------------------------
  // Task di utilità
  // -----------------------------

  task automatic apply_reset();
    begin
      reset  = 1'b1;
      enable = 1'b0;
      #12ns;
      reset  = 1'b0;
    end
  endtask

  task automatic run_cycles(input int num_cycles, input bit en);
    begin
      enable = en;
      repeat (num_cycles) @(posedge clk);
    end
  endtask

  task automatic check_equal(input logic [N-1:0] expected, input string msg);
    begin
      assert (q === expected)
        else $error("[%0t] %s -- atteso=%0d, ottenuto=%0d", $time, msg, expected, q);
    end
  endtask

  // -----------------------------
  // Stimoli principali
  // -----------------------------
  initial begin
    clk    = 1'b0;
    reset  = 1'b0;
    enable = 1'b0;

    // waveform dump
    $dumpfile("wave_counter_sv.vcd");
    $dumpvars(0, tb_counter);

    $display("[%0t] Inizio simulazione", $time);

    // 1) reset iniziale
    apply_reset();
    check_equal('0, "Dopo reset il contatore deve valere 0");

    // 2) conta per 5 cicli
    run_cycles(5, 1'b1);
    check_equal(4'd5, "Dopo 5 cicli con enable=1 il contatore deve valere 5");

    // 3) pausa per 3 cicli
    run_cycles(3, 1'b0);
    check_equal(4'd5, "Con enable=0 il contatore deve mantenere il valore");

    // 4) riprende per 4 cicli
    run_cycles(4, 1'b1);
    check_equal(4'd9, "Dopo altri 4 cicli il contatore deve valere 9");

    // 5) nuovo reset
    apply_reset();
    check_equal('0, "Dopo il secondo reset il contatore deve tornare a 0");

    $display("[%0t] Test completato con successo", $time);
    #10ns;
    $finish;
  end

  // -----------------------------
  // Monitor
  // -----------------------------
  initial begin
    $monitor("[%0t] reset=%0b enable=%0b q=%0d",
             $time, reset, enable, q);
  end

endmodule
