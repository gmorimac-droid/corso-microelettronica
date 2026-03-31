#include "xparameters.h"
#include "xgpio.h"
#include "xil_printf.h"
#include "xstatus.h"

#define LED_CHANNEL 1

XGpio Gpio;

static void delay_loop(volatile unsigned int count)
{
    while (count--) {
        ;
    }
}

int main(void)
{
    int status;

    xil_printf("Init AXI GPIO...\r\n");

    status = XGpio_Initialize(&Gpio, XPAR_AXI_GPIO_0_DEVICE_ID);
    if (status != XST_SUCCESS) {
        xil_printf("ERROR: XGpio_Initialize failed\r\n");
        return XST_FAILURE;
    }

    /* Channel 1 -> output */
    XGpio_SetDataDirection(&Gpio, LED_CHANNEL, 0x0);

    xil_printf("Blink started\r\n");

    while (1) {
        XGpio_DiscreteWrite(&Gpio, LED_CHANNEL, 0x1);
        delay_loop(5000000);

        XGpio_DiscreteWrite(&Gpio, LED_CHANNEL, 0x0);
        delay_loop(5000000);
    }

    return 0;
}
