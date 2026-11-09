# Interview demonstration walkthrough

## Demo A — RTL transfer and fault containment

1. Run `make test-rtl`.
2. The extended testbench checks chained transfers, descriptor-limit enforcement, invalid destination rejection, abort, recovery, invalid next-pointer rejection, overlap and zero length.
3. A monitor fails if the DMA master requests an address outside `0x1000..0x7fff`.
4. Open `build/dma_extended.vcd` in GTKWave.
5. Inspect `clk`, `rst_n`, `dut.state`, `dut.fetch_index`, `dut.src_addr`, `dut.dst_addr`, `dut.remaining`, `mem_valid`, `mem_write`, `mem_addr`, `mem_wdata`, `mem_ready`, `dut.mem_inflight`, `dut.abort_pending`, `dut.done_flag`, `dut.fault_flag`, `dut.error_code`, `dut.completed_count`, `dut.irq_status` and `irq`.

## Demo B — arbitration

1. Run `make test-arbiter`.
2. Show CPU and DMA requesting together while the target is stalled.
3. Show that the CPU grant is retained until acknowledgement, then grants alternate CPU/DMA.
4. Explain the single-outstanding transaction and round-robin fairness policy.

## Demo C — CPU-driven firmware

1. Run `bash scripts/get_picorv32.sh` once.
2. Run `make test-cpu`.
3. The target builds RV32I_Zicsr firmware, converts the binary to a `$readmemh` image, runs PicoRV32 and checks the result block.
4. Firmware performs CPU-loop and DMA copies at 16, 64 and 256 bytes. It records `cycle` counter values for the CPU copy loop and for DMA setup + transfer + polling.
5. The testbench validates result records, descriptor counts, error fields and the final 256-byte destination.
6. Open `build/picorv32_dma.vcd` in GTKWave and inspect CPU bus traffic, DMA state, memory requests and completion.

## What to explain

- CPU configures DMA through memory-mapped registers.
- DMA fetches and validates a complete descriptor before payload movement.
- Source/destination and next-descriptor ranges are checked with widened arithmetic.
- The DMA master can only access the configured SRAM window.
- The arbiter retains ownership through backpressure and alternates grants under contention.
- Invalid descriptors do not issue payload writes.
- Abort waits for an outstanding transaction response, then suppresses subsequent requests; it is not rollback.
- A later descriptor fault does not undo earlier completed descriptors.
- DMA setup/polling overhead can make small transfers slower than CPU copying.
- Cycle figures are simulator cycles, not physical silicon performance.
