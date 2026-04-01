#include <stdio.h>
#include <stdint.h>
#include <string.h>

#include "xparameters.h"
#include "xaxidma.h"
#include "xil_cache.h"
#include "xil_printf.h"
#include "xstatus.h"

#include "fir_ref.h"

/*
 * main.c for Zynq + AXI DMA + custom AXI4-Stream FIR IP
 *
 * Important note about the provided RTL:
 * - fir8_core introduces a 1-sample pipeline latency.
 * - fir8_axi_stream forwards TLAST using the *current* S_AXIS beat when the
 *   previous FIR result is emitted.
 *
 * Practical software workaround:
 * - transmit N real samples + 1 trailing dummy sample (0)
 * - receive N+1 samples
 * - discard rx[0]
 * - compare rx[1..N] against the software FIR reference
 *
 * This keeps the last meaningful output aligned with TLAST on the dummy beat.
 */

#ifndef DMA_DEV_ID
#define DMA_DEV_ID XPAR_AXIDMA_0_DEVICE_ID
#endif

#define N_SAMPLES        64
#define TX_SAMPLES       (N_SAMPLES + 1)   /* +1 dummy sample to flush FIR */
#define RX_SAMPLES       (N_SAMPLES + 1)
#define DMA_TIMEOUT      10000000U

static XAxiDma AxiDma;

/* Cache-line friendly static buffers */
static int16_t TxBuffer[TX_SAMPLES] __attribute__((aligned(64)));
static int16_t RxBuffer[RX_SAMPLES] __attribute__((aligned(64)));
static int16_t SwRef[N_SAMPLES]     __attribute__((aligned(64)));

static int init_dma(u16 DeviceId)
{
    XAxiDma_Config *CfgPtr;
    int Status;

    CfgPtr = XAxiDma_LookupConfig(DeviceId);
    if (CfgPtr == NULL) {
        xil_printf("ERROR: XAxiDma_LookupConfig failed for DeviceId=%d\r\n", DeviceId);
        return XST_FAILURE;
    }

    Status = XAxiDma_CfgInitialize(&AxiDma, CfgPtr);
    if (Status != XST_SUCCESS) {
        xil_printf("ERROR: XAxiDma_CfgInitialize failed (%d)\r\n", Status);
        return XST_FAILURE;
    }

    if (XAxiDma_HasSg(&AxiDma)) {
        xil_printf("ERROR: design uses SG DMA, this example expects simple mode\r\n");
        return XST_FAILURE;
    }

    XAxiDma_Reset(&AxiDma);
    while (!XAxiDma_ResetIsDone(&AxiDma)) {
        /* wait */
    }

    return XST_SUCCESS;
}

static void prepare_test_vectors(void)
{
    int i;

    /*
     * Pattern chosen to exercise sign changes and non-trivial accumulation,
     * while staying comfortably inside int16_t dynamic range after filtering.
     */
    for (i = 0; i < N_SAMPLES; ++i) {
        int32_t base = ((i * 37) % 256) - 128;
        int32_t sign = (i & 1) ? -1 : 1;
        TxBuffer[i] = (int16_t)(sign * base * 16);
    }

    /* Dummy beat used only to flush the 1-cycle FIR pipeline. */
    TxBuffer[N_SAMPLES] = 0;

    memset(RxBuffer, 0, sizeof(RxBuffer));
    memset(SwRef, 0, sizeof(SwRef));

    fir8_reference(TxBuffer, SwRef, N_SAMPLES);
}

static int start_dma_transfer(void)
{
    int Status;

    /*
     * Always arm S2MM first, then start MM2S.
     * This avoids losing early output beats from the accelerator.
     */
    Status = XAxiDma_SimpleTransfer(&AxiDma,
                                    (UINTPTR)RxBuffer,
                                    RX_SAMPLES * sizeof(int16_t),
                                    XAXIDMA_DEVICE_TO_DMA);
    if (Status != XST_SUCCESS) {
        xil_printf("ERROR: S2MM transfer start failed (%d)\r\n", Status);
        return XST_FAILURE;
    }

    Status = XAxiDma_SimpleTransfer(&AxiDma,
                                    (UINTPTR)TxBuffer,
                                    TX_SAMPLES * sizeof(int16_t),
                                    XAXIDMA_DMA_TO_DEVICE);
    if (Status != XST_SUCCESS) {
        xil_printf("ERROR: MM2S transfer start failed (%d)\r\n", Status);
        return XST_FAILURE;
    }

    return XST_SUCCESS;
}

static int wait_dma_done(void)
{
    u32 Timeout = DMA_TIMEOUT;

    while (Timeout) {
        int tx_busy = XAxiDma_Busy(&AxiDma, XAXIDMA_DMA_TO_DEVICE);
        int rx_busy = XAxiDma_Busy(&AxiDma, XAXIDMA_DEVICE_TO_DMA);

        if (!tx_busy && !rx_busy) {
            return XST_SUCCESS;
        }
        --Timeout;
    }

    xil_printf("ERROR: DMA timeout\r\n");
    return XST_FAILURE;
}

static int check_results(void)
{
    int i;
    int errors = 0;

    /*
     * Due to the hardware pipeline latency:
     *   RxBuffer[0]     = invalid/flush output
     *   RxBuffer[i + 1] = SwRef[i]
     */
    for (i = 0; i < N_SAMPLES; ++i) {
        int16_t hw = RxBuffer[i + 1];
        int16_t sw = SwRef[i];

        if (hw != sw) {
            xil_printf("Mismatch @%02d : HW=%d SW=%d\r\n", i, hw, sw);
            ++errors;
        }
    }

    if (errors == 0) {
        xil_printf("PASS: all %d FIR samples matched reference\r\n", N_SAMPLES);
        return XST_SUCCESS;
    }

    xil_printf("FAIL: %d mismatches detected\r\n", errors);
    return XST_FAILURE;
}

static void dump_samples(int count)
{
    int i;
    xil_printf("\r\nIdx |      TX | SW_REF | RX_RAW\r\n");
    xil_printf("----+---------+--------+--------\r\n");
    for (i = 0; i < count; ++i) {
        int16_t tx = (i < TX_SAMPLES) ? TxBuffer[i] : 0;
        int16_t sw = (i < N_SAMPLES)  ? SwRef[i]    : 0;
        int16_t rx = (i < RX_SAMPLES) ? RxBuffer[i] : 0;
        xil_printf("%3d | %7d | %6d | %6d\r\n", i, tx, sw, rx);
    }
    xil_printf("\r\n");
}

int main(void)
{
    int Status;

    xil_printf("\r\n=== Zynq FIR DMA test ===\r\n");
    xil_printf("DMA Device ID : %d\r\n", DMA_DEV_ID);
    xil_printf("Real samples  : %d\r\n", N_SAMPLES);
    xil_printf("TX beats      : %d (includes 1 dummy flush beat)\r\n", TX_SAMPLES);
    xil_printf("RX beats      : %d\r\n", RX_SAMPLES);

    Status = init_dma(DMA_DEV_ID);
    if (Status != XST_SUCCESS) {
        xil_printf("DMA init failed\r\n");
        return XST_FAILURE;
    }

    prepare_test_vectors();

    /*
     * With caches enabled on Zynq:
     * - flush TX and RX buffers before DMA starts
     * - invalidate RX after DMA completes
     */
    Xil_DCacheFlushRange((UINTPTR)TxBuffer, sizeof(TxBuffer));
    Xil_DCacheFlushRange((UINTPTR)RxBuffer, sizeof(RxBuffer));

    Status = start_dma_transfer();
    if (Status != XST_SUCCESS) {
        return XST_FAILURE;
    }

    Status = wait_dma_done();
    if (Status != XST_SUCCESS) {
        return XST_FAILURE;
    }

    Xil_DCacheInvalidateRange((UINTPTR)RxBuffer, sizeof(RxBuffer));

    dump_samples(12);

    Status = check_results();
    if (Status == XST_SUCCESS) {
        xil_printf("Test completed successfully.\r\n");
    } else {
        xil_printf("Test failed.\r\n");
    }

    return Status;
}
