# Understanding the project outputs

## 1. CPU-vs-DMA simulator-cycle chart

[Open the chart](evidence/cpu_vs_dma_simulator_cycles.svg). It compares the cycle counts reported by the integrated PicoRV32 firmware test.

- **CPU copy loop:** cycles spent by firmware copying the selected buffer using CPU load/store instructions.
- **DMA setup + transfer + polling:** cycles spent programming the DMA descriptor/registers, performing the transfer, and polling for completion.

Recorded results:

| Transfer size | CPU copy loop | DMA setup + transfer + polling |
|---|---:|---:|
| 16 bytes | 155 | 258 |
| 64 bytes | 551 | 342 |
| 256 bytes | 2,135 | 720 |

For 16 bytes, DMA is slower because setup and polling dominate. For 64 and 256 bytes, the DMA path takes fewer simulator cycles in this testbench. These are not physical hardware timing, throughput, power, or benchmark claims. The two measured paths include different work.

## 2. GTKWave waveform

The RTL testbenches generate `build/dma_extended.vcd` and `build/picorv32_dma.vcd`. These are signal-versus-time traces, not performance graphs. They can be opened with GTKWave:

```sh
gtkwave build/dma_extended.vcd
gtkwave build/picorv32_dma.vcd
```

Useful signals include clock/reset, register access, memory request/response, address/data, DMA state, completion count, error code, IRQ status, abort pending and fault/abort flags. The waveform helps inspect transaction timing and control-state progression; self-checking testbench assertions are the primary functional evidence.

## 3. Reproducing output

Run the documented test targets from the repository root. See [current validation](current_validation.md), [demo walkthrough](demo_walkthrough.md) and [known limitations](known_limitations.md).
