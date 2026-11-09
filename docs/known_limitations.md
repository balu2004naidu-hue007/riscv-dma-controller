# Known limitations — read before presenting this project

1. The reported Python, DMA RTL, arbiter RTL and PicoRV32 integration simulations passed in the project owner's Windows/MSYS2 UCRT64 environment. This is simulation evidence, not formal verification.
2. No synthesis, place-and-route, static timing analysis, FPGA board test, ASIC implementation or silicon validation has been performed.
3. The Python tests exercise a separate reference model; they complement but do not replace RTL simulation. The integrated firmware test is a simulation using PicoRV32 and the supplied SRAM/fabric model.
4. The simulation SRAM models the complete low memory window as writable RAM. DMA access is restricted by the controller, but the CPU program window is not physically read-only.
5. Icarus Verilog 13.0 emitted non-fatal constant-select sensitivity notices for several `always_*` blocks in `rtl/dma_controller.sv`. The observed builds and simulations completed successfully. Independent lint with another HDL tool is recommended.
6. The firmware uses polling for completion; DONE, FAULT and ABORT IRQ status/enable behavior is exercised in the RTL testbench. A firmware ISR is not part of version 1.
7. CPU-vs-DMA measurements are simulator-cycle counts and include different setup/polling costs. They are not physical throughput, latency, power or performance measurements.
8. Abort is transaction-boundary controlled and is not rollback. An outstanding write may have committed; an outstanding read is discarded. The controller suppresses subsequent requests after abort becomes pending.
9. The descriptor chain is bounded, but descriptors completed before a later descriptor fault remain completed.
10. This design is a learning prototype, not an IOMMU, certified safety mechanism or production security boundary.
11. The startup file is intentionally minimal and does not implement generic `.data` copy or `.bss` zeroing. The current firmware avoids relying on initialized writable globals; add standard startup initialization before extending it with such globals.
12. The reference design is a single-channel, word-aligned, memory-to-memory engine. AXI, bursts, caches, multiple channels and byte-granular transfers are out of scope.
