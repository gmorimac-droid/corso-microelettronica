## =========================================
## Counter example - XDC
## Target: esempio generico Vivado / FPGA Xilinx
## =========================================

## Clock principale: 100 MHz
create_clock -name clk -period 10.000 [get_ports clk]

## Reset ed enable
set_property PACKAGE_PIN U18 [get_ports reset]
set_property IOSTANDARD LVCMOS33 [get_ports reset]

set_property PACKAGE_PIN T18 [get_ports enable]
set_property IOSTANDARD LVCMOS33 [get_ports enable]

## Clock pin
set_property PACKAGE_PIN W5 [get_ports clk]
set_property IOSTANDARD LVCMOS33 [get_ports clk]

## Uscite q[3:0]
set_property PACKAGE_PIN U16 [get_ports {q[0]}]
set_property IOSTANDARD LVCMOS33 [get_ports {q[0]}]

set_property PACKAGE_PIN E19 [get_ports {q[1]}]
set_property IOSTANDARD LVCMOS33 [get_ports {q[1]}]

set_property PACKAGE_PIN U19 [get_ports {q[2]}]
set_property IOSTANDARD LVCMOS33 [get_ports {q[2]}]

set_property PACKAGE_PIN V19 [get_ports {q[3]}]
set_property IOSTANDARD LVCMOS33 [get_ports {q[3]}]

## Opzionale: slew / drive
#set_property SLEW SLOW [get_ports {q[*]}]
#set_property DRIVE 8 [get_ports {q[*]}]
