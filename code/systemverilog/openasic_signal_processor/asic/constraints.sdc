create_clock [get_ports clk] -name core_clk -period 100.0
set_input_delay 5.0 -clock core_clk [get_ports {rst_n spi_sclk spi_cs_n spi_mosi}]
set_output_delay 5.0 -clock core_clk [get_ports {spi_miso data_out[*] data_valid busy irq}]
