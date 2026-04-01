RTL=../rtl/defines.svh \
    ../rtl/fir8_core.sv \
    ../rtl/decimator.sv \
    ../rtl/fifo_sync.sv \
    ../rtl/reg_bank.sv \
    ../rtl/control_fsm.sv \
    ../rtl/output_stage.sv \
    ../rtl/status_flags.sv \
    ../rtl/spi_slave.sv \
    ../rtl/top.sv

TB_COMMON=../tb/tb_top.sv

all:
	@echo "Targets: fir_impulse decim smoke spi_reg bypass fir_decim"

fir_impulse:
	iverilog -g2012 -I../rtl -o simv_fir ../rtl/defines.svh ../rtl/fir8_core.sv ../tb/tests/fir_impulse_test.sv
	vvp simv_fir

decim:
	iverilog -g2012 -I../rtl -o simv_decim ../rtl/defines.svh ../rtl/decimator.sv ../tb/tests/decim_test.sv
	vvp simv_decim

smoke:
	iverilog -g2012 -I../rtl -o simv_smoke $(RTL) $(TB_COMMON) ../tb/tests/smoke_test.sv
	vvp simv_smoke

spi_reg:
	iverilog -g2012 -I../rtl -o simv_spi $(RTL) $(TB_COMMON) ../tb/tests/spi_reg_test.sv
	vvp simv_spi

bypass:
	iverilog -g2012 -I../rtl -o simv_bypass $(RTL) $(TB_COMMON) ../tb/tests/bypass_mode_test.sv
	vvp simv_bypass

fir_decim:
	iverilog -g2012 -I../rtl -o simv_fir_decim $(RTL) $(TB_COMMON) ../tb/tests/fir_decim_integration_test.sv
	vvp simv_fir_decim

clean:
	rm -f simv_* *.vcd
