Questo file va usato dentro una applicazione bare-metal Vitis.

Header richiesti:
- xparameters.h
- xgpio.h
- xil_printf.h (opzionale per debug)

Controlla in xparameters.h che il define corretto sia:
XPAR_AXI_GPIO_0_DEVICE_ID

Se il blocco AXI GPIO ha un nome diverso, aggiorna il codice.
