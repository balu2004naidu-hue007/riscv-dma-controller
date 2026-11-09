# Design and Verification of a Fault-Contained RISC-V DMA Controller with Bare-Metal Firmware Driver

## Abstract

This project implements and simulates a single-channel, 32-bit, word-aligned memory-to-memory DMA subsystem around a PicoRV32 processor. The design includes descriptor validation, bounded descriptor chaining, a CPU/DMA shared-bus arbiter, memory-mapped control/status registers, interrupt and error reporting, abort/recovery behavior, a bare-metal C driver and automated verification collateral.

## Architecture

The SystemVerilog design is divided into a DMA controller, CPU/DMA arbiter, simulation SRAM, system fabric and PicoRV32 SoC wrapper. The firmware configures descriptors and starts DMA operations through memory-mapped registers. The DMA engine validates source/destination ranges, alignment, length, overlap and descriptor-chain limits before transferring payload words. The Python reference model provides an independently executable descriptor-validation specification.

## Verification results

The project owner executed the complete acceptance target `make test-system-clang` in Windows/MSYS2 UCRT64 on 2026-11-09.

- Python reference model: **26/26 tests passed**.
- Extended DMA RTL testbench: **8/8 scenarios passed**.
- CPU/DMA arbiter testbench: passed backpressure-retention and round-robin-progress checks.
- RV32 firmware: compiled successfully using Clang/LLD for `riscv32-unknown-elf`.
- PicoRV32 + DMA integration testbench: passed firmware-driven 16-, 64- and 256-byte copy checks.
- Combined acceptance target: completed successfully.

Icarus Verilog 13.0 printed non-fatal constant-select sensitivity notices for `always_*` blocks in the DMA controller. The reported builds and simulations nevertheless completed and emitted their PASS messages.

## Simulated CPU-vs-DMA measurements

| Transfer size | CPU copy loop | DMA setup, transfer and polling |
|---|---:|---:|
| 16 bytes | 155 cycles | 258 cycles |
| 64 bytes | 551 cycles | 342 cycles |
| 256 bytes | 2,135 cycles | 720 cycles |

The integration testbench reported 12,686 total simulation cycles. DMA is slower for the 16-byte case due to setup/polling overhead, but used fewer simulator cycles for the 64- and 256-byte cases. The 256-byte DMA path used approximately 66.3% fewer simulator cycles than the CPU copy loop. These are simulator-specific measurements, not hardware throughput results; the compared code windows are not identical because the DMA measurement includes setup and polling.

## Conclusion

The supplied design passed the reported Python, standalone DMA RTL, arbiter RTL and PicoRV32 firmware-integration simulation runs. The project demonstrates a complete educational design-and-verification workflow spanning SystemVerilog, bare-metal C, a RISC-V soft CPU, simulation infrastructure and a Python reference model.

## Limitations

This work has not been synthesized, placed and routed, timed on an FPGA, formally verified or tested on physical silicon. DMA protection is a restricted SRAM-window checker rather than a full IOMMU. Transfers are word-aligned, single-channel and memory-to-memory. Abort is transaction-boundary controlled and does not roll back an already committed write. Descriptor chains are not atomic. See `docs/known_limitations.md` for the full design boundary.
