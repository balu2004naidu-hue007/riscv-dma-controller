# RISC-V DMA Controller

Design and simulation verification of a fault-contained 32-bit memory-to-memory DMA controller integrated with a PicoRV32 RISC-V processor and bare-metal C firmware.

This repository contains the project source, SystemVerilog RTL, C firmware, Python reference model, self-checking testbenches, validation notes, and evidence.

## Highlights

- Single-channel, 32-bit memory-to-memory DMA
- Memory-mapped control and status registers
- Descriptor-based transfers and bounded descriptor chaining
- Descriptor/address validation and transfer error reporting
- CPU/DMA round-robin bus arbitration
- Abort and recovery handling
- Bare-metal C firmware driver
- Python reference model and SystemVerilog testbenches
- PicoRV32 CPU integration simulation

## Repository layout

- `rtl/` — DMA controller, arbiter, fabric, SRAM and PicoRV32 integration
- `firmware/` — bare-metal C driver, firmware entry point and linker/startup files
- `tb/` — SystemVerilog testbenches
- `model/` — Python reference model
- `tests/` — Python unit tests
- `scripts/` — build/test helpers and PicoRV32 fetch script
- `docs/` — architecture, register map, setup, validation, walkthrough and limitations
- `docs/evidence/` — waveform and CPU-vs-DMA simulator-cycle chart
- `artifacts/` — recorded firmware build outputs and checksums

## Validation record

The recorded Windows acceptance run reported:

- Python reference-model tests: 26 passed
- Extended DMA RTL scenarios: 8 passed
- Arbiter testbench: passed
- Clang RV32 firmware build: passed
- PicoRV32 + DMA integration simulation: passed
- Combined acceptance suite: passed

See [docs/current_validation.md](docs/current_validation.md) and [docs/windows_setup.md](docs/windows_setup.md) for details and reproduction instructions.

## CPU vs DMA simulator-cycle results

![CPU vs DMA simulator cycles](docs/evidence/cpu_vs_dma_simulator_cycles.png)

| Transfer size | CPU copy loop | DMA setup + transfer + polling |
|---|---:|---:|
| 16 bytes | 155 cycles | 258 cycles |
| 64 bytes | 551 cycles | 342 cycles |
| 256 bytes | 2,135 cycles | 720 cycles |

These values are from the PicoRV32 simulation testbench. The CPU metric measures the copy loop; the DMA metric includes setup, transfer and polling. They are simulator-cycle comparisons, not physical hardware timing or throughput measurements. Small transfers can be slower through DMA because setup overhead dominates. See [docs/graph_and_output_guide.md](docs/graph_and_output_guide.md).

## GTKWave evidence

[Waveform review screenshot](docs/evidence/dma_extended_waveform_review.png) shows a time-domain trace of clock/reset, register accesses, memory handshake activity, controller state and completion/fault/abort-related signals. A waveform is a signal-versus-time debugging view, not a performance graph.

To inspect generated VCD traces after running the simulations:

```sh
gtkwave build/dma_extended.vcd
gtkwave build/picorv32_dma.vcd
```

## Build and test

Use the commands documented in the Makefile and setup guide. The PicoRV32 upstream source is fetched separately using:

```sh
bash scripts/get_picorv32.sh
```

The recorded validation used PicoRV32 commit `ef203c2b0a3fb793280f5114941416c425c5b461`.

## Scope and limitations

This is a simulation-verified educational RTL/firmware project. It has not been FPGA-synthesized, physically tested on hardware, formally verified, or timing-closed.

The design is intentionally scoped to one 32-bit memory-to-memory DMA channel. It does not implement AXI, burst transfers, multiple channels, cache coherence, byte-granular transfers, or a full IOMMU/MPU. Abort is handled at bus transaction boundaries; already committed writes are not rolled back. Descriptor chains are not atomic.

See [docs/known_limitations.md](docs/known_limitations.md) and [docs/architecture.md](docs/architecture.md).

## License and third-party dependency

See [third_party/PICORV32_COPYING.txt](third_party/PICORV32_COPYING.txt) for upstream PicoRV32 licensing and attribution information. The upstream source itself is fetched separately rather than vendored in this repository.
