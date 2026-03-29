read_vhdl ../vhdl/counter.vhd
synth_design -top counter -part xc7a35tcpg236-1
write_checkpoint -force post_synth.dcp
report_timing_summary -file timing_summary.rpt
report_utilization -file utilization.rpt
