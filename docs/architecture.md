# Architecture and design contract

## Block-level topology

PicoRV32 is an external CPU core using its native `mem_valid/mem_ready` interface. The `picorv32_dma_soc` wrapper connects that interface to `dma_system_fabric`. The fabric decodes CPU accesses to the DMA register window and arbitrates CPU memory traffic against the DMA memory master. The single SRAM model is a simulation memory, not a physical memory macro.

```text
Bare-metal C firmware -> PicoRV32 native memory port
                              |
                      dma_system_fabric
                       /            \
             DMA register bank    round-robin arbiter
                                      /       \
                                CPU master   DMA master
                                      \       /
                                     shared SRAM
```

## Address map

| Region | Start | End exclusive | Purpose | DMA permission |
|---|---:|---:|---|---|
| CPU program window | `0x00000000` | `0x00001000` | Firmware image/load region | Denied |
| Shared SRAM | `0x00001000` | `0x00008000` | Descriptors and data | Read/write |
| DMA registers | `0x00008000` | `0x00008100` | CPU control/status | Denied |
| Reserved | `0x00008100` | `0x00008200` | Reserved | Denied |

The current simulation fabric uses one SRAM model for the full `0x00000000-0x00007fff` window. The DMA validator restricts the DMA master to `0x00001000-0x00007fff`; the low program window is **not implemented as physically read-only ROM**. CPU memory protection and a separate ROM macro are outside version 1.

## Descriptor format

Five 32-bit words, 20 bytes total, 4-byte aligned:

1. `SRC_ADDR`
2. `DST_ADDR`
3. `LENGTH` (non-zero multiple of four)
4. `NEXT_DESC` (zero terminates)
5. `CONTROL` (must be zero in v1)

All descriptors and transfer buffers must fit in the SRAM window. Source/destination ranges must not overlap. Validation uses 33-bit end-address arithmetic to detect wrap/range violations. The entire descriptor is fetched before validation and no data transfer starts until validation succeeds.

## Register map

Base `0x00008000`; offsets are 32-bit word offsets.

| Offset | Name | Access | Meaning |
|---:|---|---|---|
| `0x00` | DESC_BASE | RW | First descriptor pointer |
| `0x04` | DESC_LIMIT | RW | Maximum descriptors in a run, 1..256 |
| `0x08` | CONTROL | WO | bit 0 START, bit 1 ABORT, bit 2 software reset |
| `0x0c` | STATUS | RO/W1C | bit 0 BUSY, bit 1 DONE, bit 2 FAULT, bit 3 ABORTED |
| `0x10` | ERROR_CODE | RO | First fault code |
| `0x14` | COMPLETED_COUNT | RO | Fully completed descriptors |
| `0x18` | IRQ_STATUS | RO/W1C | bit 0 DONE, bit 1 FAULT, bit 2 ABORT |
| `0x1c` | IRQ_ENABLE | RW | Enables DONE, FAULT and ABORT IRQ status bits |

Error codes: 0 none; 1 descriptor alignment; 2 descriptor range; 3 source alignment; 4 destination alignment; 5 zero length; 6 non-word length; 7 source range; 8 destination range; 9 overlap; 10 descriptor limit; 11 reserved control bits.

## Bus and arbitration

The CPU adapter derives write from `|mem_wstrb`. The DMA and CPU masters share a single-outstanding valid/ready transaction path. If both request simultaneously, the arbiter uses round-robin selection. A selected owner is retained until the target acknowledges. Masters must hold request/address/data/strobes stable until `ready`.

`simple_sram` is a simulation memory with one-cycle request latency and byte write strobes. It is not intended to infer a production SRAM macro without adaptation.

## Abort, fault and recovery

Abort is honored at the next acknowledged bus-transaction boundary. The controller tracks an outstanding request and keeps it stable until its response. It suppresses the next request once abort is pending. An already outstanding write may commit; an outstanding read is discarded. No subsequent DMA request is issued. Abort is not rollback. The current descriptor is not counted as complete unless all its words have transferred. A fault stops further DMA requests. Previously completed descriptors are not rolled back. Software can reset the engine and submit a new valid descriptor chain.

## Protection scope

The validator prevents this DMA engine from issuing transactions outside the configured SRAM window. This is not a full IOMMU, not a complete SoC security boundary, and does not protect against malicious CPU code or unrelated bus masters.
