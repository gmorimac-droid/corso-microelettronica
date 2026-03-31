## Cambia T22 con il pin LED corretto della tua board.
## Se nel wrapper/top la porta viene rinominata in 'led', aggiorna anche il nome del port.

set_property PACKAGE_PIN T22 [get_ports gpio_rtl_0_tri_o]
set_property IOSTANDARD LVCMOS33 [get_ports gpio_rtl_0_tri_o]
