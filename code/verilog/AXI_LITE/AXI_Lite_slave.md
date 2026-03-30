## Scehma a blocchi AXI Lite Slave

```mermaid

flowchart LR
    A[AXI-Lite Bus] --> B[AXI Slave]
    B --> C[Control Registers]
    C --> D[User Logic]
    D --> E[Status/Data]
    E --> B

```