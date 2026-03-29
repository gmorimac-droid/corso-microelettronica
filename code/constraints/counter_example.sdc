# =========================================
# Counter example - SDC
# =========================================

# Clock principale: 100 MHz
create_clock -name clk -period 10.000 [get_ports clk]

# Incertezza di clock
set_clock_uncertainty 0.20 [get_clocks clk]

# Ritardi di input rispetto al clock
set_input_delay  2.0 -clock [get_clocks clk] [get_ports reset]
set_input_delay  2.0 -clock [get_clocks clk] [get_ports enable]

# Ritardi di output rispetto al clock
set_output_delay 2.5 -clock [get_clocks clk] [get_ports {q[*]}]

# Carico fittizio sulle uscite
set_load 0.05 [get_ports {q[*]}]

# Transizione di ingresso stimata
set_input_transition 0.10 [get_ports reset]
set_input_transition 0.10 [get_ports enable]
