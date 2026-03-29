# Timing-only SDC example

create_clock -name clk -period 10.000 [get_ports clk]
set_clock_uncertainty 0.20 [get_clocks clk]
