PYTHON ?= python3
IVERILOG ?= iverilog
VVP ?= vvp
RISCV_CC ?= riscv-none-elf-gcc
RISCV_OBJCOPY ?= riscv-none-elf-objcopy
GTKWAVE ?= gtkwave
CLANG ?= clang
LLVM_OBJCOPY ?= llvm-objcopy
BUILD := build
RTL := rtl/dma_controller.sv rtl/dma_arbiter.sv rtl/simple_sram.sv rtl/dma_system_fabric.sv

.PHONY: help test-python test-rtl test-arbiter test-cpu test-cpu-clang test-all test-extended test-system test-system-clang firmware firmware-clang view-wave clean check-tools
help:
	@echo "Targets: test-python, test-rtl, test-arbiter, test-cpu, test-cpu-clang, test-system, test-system-clang, firmware, firmware-clang, view-wave, check-tools, clean"

check-tools:
	@$(PYTHON) --version
	@command -v $(IVERILOG) || true
	@command -v $(VVP) || true
	@command -v $(RISCV_CC) || true
	@command -v $(CLANG) || true
	@command -v $(LLVM_OBJCOPY) || true
	@command -v $(GTKWAVE) || true

test-python:
	$(PYTHON) -m unittest discover -s tests -v

test-rtl: test-extended

test-extended:
	@mkdir -p $(BUILD)
	$(IVERILOG) -g2012 -s dma_extended_tb -o $(BUILD)/dma_extended_tb $(RTL) tb/dma_extended_tb.sv
	$(VVP) $(BUILD)/dma_extended_tb

test-cpu: firmware
	@test -f third_party/picorv32/picorv32.v || (echo "Run scripts/get_picorv32.sh first"; exit 1)
	@mkdir -p $(BUILD)
	$(IVERILOG) -g2012 -s picorv32_dma_tb -o $(BUILD)/picorv32_dma_tb $(RTL) rtl/picorv32_dma_soc.sv third_party/picorv32/picorv32.v tb/picorv32_dma_tb.sv
	$(VVP) $(BUILD)/picorv32_dma_tb

test-cpu-clang: firmware-clang
	@test -f third_party/picorv32/picorv32.v || (echo "Run scripts/get_picorv32.sh first"; exit 1)
	@mkdir -p $(BUILD)
	$(IVERILOG) -g2012 -s picorv32_dma_tb -o $(BUILD)/picorv32_dma_tb $(RTL) rtl/picorv32_dma_soc.sv third_party/picorv32/picorv32.v tb/picorv32_dma_tb.sv
	$(VVP) $(BUILD)/picorv32_dma_tb

test-arbiter:
	@mkdir -p $(BUILD)
	$(IVERILOG) -g2012 -s dma_arbiter_tb -o $(BUILD)/dma_arbiter_tb rtl/dma_arbiter.sv tb/dma_arbiter_tb.sv
	$(VVP) $(BUILD)/dma_arbiter_tb

test-all: test-python test-rtl test-arbiter

test-system: test-all test-cpu

test-system-clang: test-all test-cpu-clang

firmware:
	@mkdir -p $(BUILD)
	$(RISCV_CC) -march=rv32i_zicsr -mabi=ilp32 -msmall-data-limit=0 -Os -ffreestanding -fno-builtin -nostdlib \
		-Wall -Wextra -Ifirmware -T firmware/linker.ld -Wl,--gc-sections \
		-o $(BUILD)/dma_firmware.elf firmware/start.S firmware/main.c firmware/dma_driver.c
	$(RISCV_OBJCOPY) -O binary $(BUILD)/dma_firmware.elf $(BUILD)/dma_firmware.bin
	$(PYTHON) scripts/bin_to_mem.py $(BUILD)/dma_firmware.bin $(BUILD)/dma_firmware.mem --words 8192

firmware-clang:
	@mkdir -p $(BUILD)
	$(CLANG) --target=riscv32-unknown-elf -march=rv32i_zicsr -mabi=ilp32 -msmall-data-limit=0 -Oz -ffreestanding -fno-builtin -nostdlib \
		-Wall -Wextra -Werror -Ifirmware -T firmware/linker.ld -Wl,--gc-sections -fuse-ld=lld \
		-o $(BUILD)/dma_firmware_clang.elf firmware/start.S firmware/main.c firmware/dma_driver.c
	$(LLVM_OBJCOPY) -O binary $(BUILD)/dma_firmware_clang.elf $(BUILD)/dma_firmware.bin
	$(PYTHON) scripts/bin_to_mem.py $(BUILD)/dma_firmware.bin $(BUILD)/dma_firmware.mem --words 8192

view-wave:
	$(GTKWAVE) $(BUILD)/dma_extended.vcd

clean:
	rm -rf $(BUILD) __pycache__ model/__pycache__ tests/__pycache__
