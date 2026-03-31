# ============================================================
# Zynq PS + AXI + LED
# Vivado Tcl scaffold
# ============================================================
# ADATTA QUESTE VARIABILI ALLA TUA BOARD / DEVICE
# Esempi:
#   set board_part "digilentinc.com:zybo-z7-20:part0:1.2"
# oppure:
#   set part_name "xc7z020clg400-1"
# ============================================================

set proj_name "zynq_ps_axi_led"
set proj_dir  [file normalize "../build"]
set bd_name   "design_1"

# Scegli UNA delle due opzioni:
set use_board_part 0
set board_part ""
set part_name "xc7z020clg400-1"

file mkdir $proj_dir

create_project $proj_name $proj_dir -force

if {$use_board_part} {
    if {$board_part eq ""} {
        error "use_board_part=1 ma board_part e' vuoto"
    }
    set_property board_part $board_part [current_project]
} else {
    if {$part_name eq ""} {
        error "part_name vuoto"
    }
    set_property part $part_name [current_project]
}

set_property target_language Verilog [current_project]
set_property simulator_language Mixed [current_project]

# Aggiungi constraints
read_xdc ../constraints/led.xdc

# Crea block design
create_bd_design $bd_name

# Zynq PS
create_bd_cell -type ip -vlnv xilinx.com:ip:processing_system7:* processing_system7_0

# Block automation
apply_bd_automation -rule xilinx.com:bd_rule:processing_system7 \
    -config {make_external "FIXED_IO, DDR" apply_board_preset "1" Master "Disable" Slave "Disable"} \
    [get_bd_cells processing_system7_0]

# AXI GPIO
create_bd_cell -type ip -vlnv xilinx.com:ip:axi_gpio:* axi_gpio_0

# Configura AXI GPIO
set_property -dict [list \
    CONFIG.C_GPIO_WIDTH {1} \
    CONFIG.C_ALL_OUTPUTS {1} \
    CONFIG.C_IS_DUAL {0}] [get_bd_cells axi_gpio_0]

# Connection automation per AXI GPIO
apply_bd_automation -rule xilinx.com:bd_rule:axi4 \
    -config { \
        Clk_master {/processing_system7_0/FCLK_CLK0} \
        Clk_slave {/processing_system7_0/FCLK_CLK0} \
        Clk_xbar {/processing_system7_0/FCLK_CLK0} \
        Master {/processing_system7_0/M_AXI_GP0} \
        Slave {/axi_gpio_0/S_AXI} \
        ddr_seg {Auto} \
        intc_ip {New AXI Interconnect} \
        master_apm {0} \
        slave_apm {0} \
    } \
    [get_bd_intf_pins axi_gpio_0/S_AXI]

# Rendi esterno il GPIO
make_bd_pins_external [get_bd_pins axi_gpio_0/gpio_io_o]

# Rinomina porta esterna per coerenza con XDC
set gpio_port [get_bd_ports gpio_io_o_0]
set_property name gpio_rtl_0_tri_o $gpio_port

# Address assignment
assign_bd_address

# Validate
validate_bd_design
save_bd_design

# Crea wrapper HDL
make_wrapper -files [get_files ${proj_dir}/${proj_name}.srcs/sources_1/bd/${bd_name}/${bd_name}.bd] -top
add_files -norecurse ${proj_dir}/${proj_name}.srcs/sources_1/bd/${bd_name}/hdl/${bd_name}_wrapper.v

# Imposta top
set_property top ${bd_name}_wrapper [current_fileset]

# Run
launch_runs synth_1 -jobs 4
wait_on_run synth_1

launch_runs impl_1 -to_step write_bitstream -jobs 4
wait_on_run impl_1

puts "===================================================="
puts "Project created and bitstream generated."
puts "Project dir: $proj_dir"
puts "Top        : ${bd_name}_wrapper"
puts "Next step  : Export hardware (.xsa) including bitstream"
puts "===================================================="
