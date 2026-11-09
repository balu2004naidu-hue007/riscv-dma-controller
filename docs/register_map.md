# DMA register and descriptor contract

Register base: `0x00008000`. All registers are 32-bit and word-aligned.

| Offset | Register | Access | Description |
|---:|---|---|---|
| `0x00` | `DESC_BASE` | RW | First descriptor address |
| `0x04` | `DESC_LIMIT` | RW | Maximum descriptors in a run (1..256) |
| `0x08` | `CONTROL` | WO | START bit 0, ABORT bit 1, software reset bit 2 |
| `0x0c` | `STATUS` | RO/W1C | BUSY bit 0, DONE bit 1, FAULT bit 2, ABORTED bit 3 |
| `0x10` | `ERROR_CODE` | RO | First fault code |
| `0x14` | `COMPLETED_COUNT` | RO | Fully completed descriptors |
| `0x18` | `IRQ_STATUS` | RO/W1C | DONE bit 0, FAULT bit 1, ABORT bit 2 |
| `0x1c` | `IRQ_ENABLE` | RW | Enables corresponding IRQ bits |

## Error codes

| Code | Name | Meaning |
|---:|---|---|
| 0 | `ERR_NONE` | No error |
| 1 | `ERR_DESC_ALIGN` | Descriptor pointer misaligned |
| 2 | `ERR_DESC_RANGE` | Complete 20-byte descriptor outside SRAM |
| 3 | `ERR_SRC_ALIGN` | Source address misaligned |
| 4 | `ERR_DST_ALIGN` | Destination address misaligned |
| 5 | `ERR_ZERO_LENGTH` | Zero transfer length |
| 6 | `ERR_LENGTH_ALIGN` | Length not divisible by four |
| 7 | `ERR_SRC_RANGE` | Source range outside SRAM or wraps |
| 8 | `ERR_DST_RANGE` | Destination range outside SRAM or wraps |
| 9 | `ERR_OVERLAP` | Source and destination ranges overlap |
| 10 | `ERR_DESC_LIMIT` | Descriptor limit invalid or chain exceeded it |
| 11 | `ERR_CONTROL` | Reserved descriptor control bits are non-zero |

## Descriptor layout

Five 32-bit words (20 bytes), aligned to four bytes:

1. `SRC_ADDR`
2. `DST_ADDR`
3. `LENGTH` — non-zero multiple of four bytes
4. `NEXT_DESC` — zero terminates the chain
5. `CONTROL` — must be zero in version 1

Descriptors and buffers must be in `0x00001000..0x00007fff`. The exclusive SRAM end is `0x00008000`. A transfer ending exactly at this boundary is valid.

## Control semantics

- START is accepted only while IDLE or in a terminal state. A start while BUSY is ignored.
- ABORT while active sets a pending abort. The controller keeps an already outstanding request stable until it is acknowledged, then aborts before issuing another request. If no request is outstanding, abort is immediate. An outstanding write may have committed; abort is not rollback.
- Software reset clears state, status, error, completed count and pending IRQs when the engine is idle or terminal.
- STATUS and IRQ_STATUS use write-one-to-clear for their sticky bits.
- DONE, FAULT and ABORT are independently enabled through IRQ_ENABLE bits 0, 1 and 2.

The descriptor limit bounds chain traversal. If descriptor N faults, earlier fully completed descriptors remain completed and are not rolled back.
