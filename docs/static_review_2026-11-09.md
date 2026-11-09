# Static RTL and firmware review — 2026-11-09

## Scope

Reviewed the DMA controller, round-robin arbiter, SRAM model, system fabric, PicoRV32 wrapper, bare-metal driver, benchmark firmware, and supplied testbenches. This was a source-level review; it is not a substitute for HDL compilation or simulation.

## Source-level checks

- The DMA controller uses widened 33-bit end-address calculations for source, destination, and descriptor boundary checks.
- Source and destination must be word-aligned, the transfer length must be non-zero and word-aligned, both ranges must fit in the exclusive SRAM window `0x00001000..0x00008000`, and source/destination overlap is rejected.
- A non-zero next-descriptor pointer is checked for alignment and room for all 20 descriptor bytes before payload transfer begins.
- Descriptor traversal is bounded by `DESC_LIMIT` and the configured maximum of 256 descriptors.
- The arbiter retains ownership when the selected transaction is stalled and updates its round-robin history after a response.
- The SRAM model captures request fields and returns a one-cycle-later response. The DMA and CPU share the same arbiter and SRAM instance in the system fabric.
- The firmware register offsets, status bits, IRQ bits, and descriptor layout match `docs/register_map.md` on inspection.
- The firmware places code in ROM and its source, destination, descriptor, and result buffers at the documented SRAM addresses. The current firmware has no writable global data or BSS dependency requiring startup initialization.

## Items requiring simulation evidence

1. Compile all SystemVerilog sources with Icarus Verilog and resolve any elaboration or language-compatibility errors.
2. Run `make test-rtl` and `make test-arbiter`; inspect all test outcomes rather than treating testbench presence as proof.
3. Fetch the upstream PicoRV32 source, record its exact commit, and run `make test-cpu-clang`.
4. Inspect VCD waveforms for request stability, acknowledgement timing, abort boundaries, and CPU/DMA handoff.
5. Add or run tests for controller-level backpressure while the CPU owns the shared bus, reset/start sequencing, simultaneous status clear and terminal events, and destination writes near descriptor-chain memory.

## Review cautions

- `mem_inflight` is derived from a DMA request remaining unacknowledged at the controller interface. In the integrated fabric, this can include a request queued behind a CPU-owned arbiter transaction. The documented abort contract treats a request already presented to the arbiter as outstanding; simulation should verify that this behaviour is intentional and clearly demonstrated.
- The controller and arbiter have no separate request-accept signal; `mem_ready` represents the completed transaction response. This is valid for the supplied single-outstanding fabric, but must remain explicit in any future bus adaptation.
- The standalone extended testbench uses the simple SRAM model, while the CPU testbench is needed to verify the integrated arbitration and firmware path. Neither is considered passed until executed.

## Results in this review session

- Python reference-model tests: 26 passed, 0 failed.
- `make firmware-clang`: passed in this session using Clang/LLD and generated ELF, binary, and memory image.
- Host C compilation of `dma_driver.c` and `main.c` with `-Wall -Wextra -Werror`: passed.
- ELF inspection: confirmed ELF32, little-endian, RISC-V executable with entry point `0x00000000`; reported text size 1,864 bytes, data 0 bytes, BSS 0 bytes.
- Icarus Verilog/VVP were not available in this execution environment. An attempt to install Icarus via the system package manager timed out. No RTL simulation result is claimed.
