# Verification plan and acceptance criteria

## Implemented verification collateral

- Python descriptor-admission reference model and 26 unit tests, including seeded randomized range cases.
- SystemVerilog DMA controller, shared arbiter, SRAM model and PicoRV32 fabric wrapper.
- Extended RTL testbench covering two-descriptor chaining, descriptor-limit enforcement, invalid destination rejection, abort during an outstanding source-read response, abort IRQ, recovery, invalid next-pointer rejection, overlap rejection, zero-length rejection and a DMA address-window monitor.
- Arbiter testbench covering target backpressure, grant retention and alternating CPU/DMA progress.
- Bare-metal C driver and PicoRV32 firmware example.
- CPU integration testbench that checks the firmware result block and final 256-byte destination.

## Python reference-model tests

Run:

```sh
python3 -m unittest discover -s tests -v
```

Expected current result: 26 tests pass. These tests validate the independent Python reference specification; they are not RTL simulation.

## RTL tests

Run:

```sh
make test-rtl
make test-arbiter
```

The extended DMA test writes `build/dma_extended.vcd` and should end with `ALL EXTENDED DMA TESTS PASSED`. The arbiter test should report backpressure retention and round-robin progress. Open the VCD in GTKWave using `make view-wave`.

## CPU + firmware integration

Fetch the upstream PicoRV32 core, then build and run:

```sh
bash scripts/get_picorv32.sh
make test-cpu
```

The firmware uses RV32I_Zicsr and the PicoRV32 cycle counter. It compares a CPU volatile C-loop copy against DMA setup + transfer + polling for 16, 64 and 256 bytes. It records cycle counts, completed descriptor counts and error fields at `0x00005000`. The testbench checks all records and the final 256-byte destination.

The CPU baseline is only the copy loop; the DMA measurement includes setup and polling. Report the difference honestly. Values are simulator cycles, not silicon throughput.

## Acceptance criteria before claiming full completion

- 100% of the directed RTL tests pass.
- DMA never issues an address outside `0x00001000..0x00007fff`.
- Rejected descriptors cause no payload writes.
- Descriptor count increments only after all words in a descriptor complete.
- Descriptor chains stop at the configured limit.
- Abort does not issue a new request after the outstanding request completes.
- Valid transfer succeeds after reset/recovery.
- Arbiter holds a grant through backpressure and both masters progress under sustained contention.
- PicoRV32 executes the C firmware, completes all three benchmark sizes and passes memory-integrity checks.
- Simulator versions, toolchain version, test output and waveform evidence are retained.

## Not claimed

- No physical FPGA/ASIC or silicon timing/power/throughput result.
- No full IOMMU or certified security/safety function.
- No rollback of descriptors completed before a later descriptor fault.
- No interrupt service routine in firmware version 1; IRQ status and enable behavior are verified at RTL level.
