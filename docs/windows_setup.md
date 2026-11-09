# Windows setup and run guide

Use a separate project directory. Do not place this folder inside MICROKERNEL-X, AIBARS or AutoCore.

## Recommended terminal

MSYS2 UCRT64. Install the standard build utilities with:

```bash
pacman -S --needed make git python
```

## Required RTL tools

Install an Icarus Verilog Windows build that provides both `iverilog.exe` and `vvp.exe`. Add their `bin` directory to PATH. Install GTKWave separately and add `gtkwave.exe` to PATH if it is not bundled with your simulator distribution.

Check availability:

```bash
iverilog -V
vvp -V
make --version
gtkwave --version
```

## RISC-V firmware compiler

Either install xPack RISC-V GCC so `riscv-none-elf-gcc` and `riscv-none-elf-objcopy` are on PATH, or use a Clang/LLVM toolchain with RISC-V target support. The Makefile has `firmware` (GCC) and `firmware-clang` targets.

Check compiler availability:

```bash
riscv-none-elf-gcc --version
```

or

```bash
clang --version
llvm-objcopy --version
```

## Download the upstream CPU

From the project root:

```bash
bash scripts/get_picorv32.sh
```

The script clones `https://github.com/YosysHQ/picorv32` into `third_party/picorv32` and prints the exact commit SHA. Keep that SHA with your test report and retain the upstream LICENSE file.

## Run in this order

```bash
make test-python
make test-rtl
make test-arbiter
make firmware-clang
make test-cpu-clang
```

If using RISC-V GCC instead of Clang:

```bash
make firmware
make test-cpu
```

## Waveforms

The extended RTL test writes `build/dma_extended.vcd`. The CPU integration test writes `build/picorv32_dma.vcd`.

```bash
gtkwave build/dma_extended.vcd
```

or

```bash
gtkwave build/picorv32_dma.vcd
```

The CPU integration waveform can only exist after `make test-cpu-clang` or `make test-cpu` completes successfully.
