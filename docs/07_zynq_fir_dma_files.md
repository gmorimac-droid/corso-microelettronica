# 📁 Zynq FIR DMA Project — File Completi & Debug

Questa pagina contiene:

- tutti i file del progetto
- struttura organizzata
- codice completo
- errori tipici e soluzioni

---

# 📂 Struttura completa progetto

```text
zynq_fir_dma_project/
├── vivado/
│   ├── hdl/
│   │   ├── axis_loopback.sv
│   │   ├── fir8_core.sv
│   │   └── fir8_axi_stream.sv
│   └── constraints/
│       └── optional_debug.xdc
│
└── vitis_workspace/
    └── fir_dma_app/
        └── src/
            ├── main.c
            ├── fir_ref.c
            └── fir_ref.h
```

---

# 🔧 HDL FILES

---

## 📄 axis_loopback.sv

```systemverilog
module axis_loopback #(
    parameter int DATA_W = 16
)(
    input  logic aclk,
    input  logic aresetn,

    input  logic [DATA_W-1:0] s_axis_tdata,
    input  logic s_axis_tvalid,
    output logic s_axis_tready,
    input  logic s_axis_tlast,

    output logic [DATA_W-1:0] m_axis_tdata,
    output logic m_axis_tvalid,
    input  logic m_axis_tready,
    output logic m_axis_tlast
);

    always_ff @(posedge aclk) begin
        if (!aresetn) begin
            m_axis_tvalid <= 0;
        end else begin
            if (m_axis_tvalid && m_axis_tready)
                m_axis_tvalid <= 0;

            if (s_axis_tvalid && (!m_axis_tvalid || m_axis_tready)) begin
                m_axis_tdata  <= s_axis_tdata;
                m_axis_tvalid <= 1;
                m_axis_tlast  <= s_axis_tlast;
            end
        end
    end

    assign s_axis_tready = !m_axis_tvalid || m_axis_tready;

endmodule
```

---

## 📄 fir8_core.sv

```systemverilog
module fir8_core #(parameter int DATA_W=16)(
    input  logic clk,
    input  logic rstn,
    input  logic sample_valid,
    input  logic signed [DATA_W-1:0] sample_in,
    output logic signed [DATA_W-1:0] sample_out,
    output logic sample_out_valid
);

    logic signed [DATA_W-1:0] x[0:7];
    logic signed [15:0] h[0:7];
    integer i;
    logic signed [39:0] acc;

    initial begin
        h = '{-8,0,40,96,96,40,0,-8};
    end

    always_ff @(posedge clk) begin
        if (!rstn) begin
            for(i=0;i<8;i++) x[i]<=0;
        end else if(sample_valid) begin
            for(i=7;i>0;i--) x[i]<=x[i-1];
            x[0] <= sample_in;

            acc = 0;
            for(i=0;i<8;i++) acc += x[i]*h[i];

            sample_out <= acc >>> 8;
            sample_out_valid <= 1;
        end else begin
            sample_out_valid <= 0;
        end
    end
endmodule
```

---

## 📄 fir8_axi_stream.sv

```systemverilog
module fir8_axi_stream #(parameter int DATA_W=16)(
    input  logic aclk,
    input  logic aresetn,

    input  logic [DATA_W-1:0] s_axis_tdata,
    input  logic s_axis_tvalid,
    output logic s_axis_tready,
    input  logic s_axis_tlast,

    output logic [DATA_W-1:0] m_axis_tdata,
    output logic m_axis_tvalid,
    input  logic m_axis_tready,
    output logic m_axis_tlast
);

    logic [DATA_W-1:0] data;
    logic valid;
    logic last_reg;

    fir8_core u_core(
        .clk(aclk),
        .rstn(aresetn),
        .sample_valid(s_axis_tvalid && s_axis_tready),
        .sample_in(s_axis_tdata),
        .sample_out(data),
        .sample_out_valid(valid)
    );

    assign s_axis_tready = m_axis_tready || !m_axis_tvalid;

    always_ff @(posedge aclk) begin
        if (!aresetn) begin
            m_axis_tvalid <= 0;
        end else begin
            if (valid && (m_axis_tready || !m_axis_tvalid)) begin
                m_axis_tdata  <= data;
                m_axis_tvalid <= 1;
                m_axis_tlast  <= s_axis_tlast;
            end else if (m_axis_tvalid && m_axis_tready) begin
                m_axis_tvalid <= 0;
            end
        end
    end

endmodule
```

---

# 💻 SOFTWARE FILES

---

## 📄 fir_ref.h

```c
#ifndef FIR_REF_H
#define FIR_REF_H
#include <stdint.h>
void fir8_reference(const int16_t *in, int16_t *out, int n);
#endif
```

---

## 📄 fir_ref.c

```c
#include "fir_ref.h"

void fir8_reference(const int16_t *in, int16_t *out, int n)
{
    int16_t h[8] = {-8,0,40,96,96,40,0,-8};

    for(int i=0;i<n;i++){
        int32_t acc=0;
        for(int k=0;k<8;k++){
            int idx=i-k;
            int16_t x = (idx>=0)?in[idx]:0;
            acc += x*h[k];
        }
        out[i]=acc>>8;
    }
}
```

---

## 📄 main.c (estratto essenziale)

```c
// solo core per chiarezza
XAxiDma_SimpleTransfer(&AxiDma, rx_buffer, SIZE, XAXIDMA_DEVICE_TO_DMA);
XAxiDma_SimpleTransfer(&AxiDma, tx_buffer, SIZE, XAXIDMA_DMA_TO_DEVICE);

while(XAxiDma_Busy(&AxiDma, XAXIDMA_DMA_TO_DEVICE));
while(XAxiDma_Busy(&AxiDma, XAXIDMA_DEVICE_TO_DMA));
```

---

# 🧪 ERRORI TIPICI E SOLUZIONI

---

## ❌ DMA bloccato

### Sintomo
Programma fermo su `XAxiDma_Busy`

### Cause
- `tvalid/tready` non corretti
- FIR non produce output
- `tlast` mancante

---

## ❌ Output tutto zero

### Cause
- reset sempre attivo
- FIR non riceve dati
- cache non invalidata

### Soluzione
```c
Xil_DCacheInvalidateRange(...)
```

---

## ❌ Dati errati

### Cause
- mismatch endianess / width
- FIR shift sbagliato
- errore nei coefficienti

---

## ❌ Loopback OK ma FIR NO

👉 Problema nel FIR, NON nel DMA

---

## ❌ DMA error SG mode

### Cause
DMA configurato male

### Soluzione
- disabilita Scatter Gather

---

## ❌ Nessun trasferimento

### Cause
- indirizzo buffer errato
- DDR non collegata

---

# 🧠 CONSIGLI IMPORTANTI

---

## ✔️ Sempre fare prima il loopback

👉 salva ore di debug

---

## ✔️ Cache SEMPRE gestita

```c
Flush → prima
Invalidate → dopo
```

---

## ✔️ Debug step-by-step

1. DMA loopback
2. FIR semplice
3. FIR completo

---

# 🚀 Prossimi upgrade

- interrupt DMA
- FIR parametrico
- streaming continuo
- acceleratore DSP

---

# 🎯 Conclusione

Questa pagina contiene tutto il necessario per:

- costruire il progetto
- capire i file
- debuggarlo

👉 Questo è già un progetto di livello **semi-professionale su Zynq**