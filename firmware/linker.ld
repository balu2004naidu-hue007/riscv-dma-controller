OUTPUT_ARCH(riscv)
ENTRY(_start)
MEMORY {
  ROM  (rx)  : ORIGIN = 0x00000000, LENGTH = 4K
  SRAM (rwx) : ORIGIN = 0x00001000, LENGTH = 28K
}
SECTIONS {
  .text : { *(.init) *(.text*) *(.rodata*) } > ROM
  .data : { *(.data*) } > SRAM AT> ROM
  .bss : { *(.bss*) *(COMMON) } > SRAM
  . = ALIGN(16);
  _end = .;
  ASSERT(_end < 0x00002000, "firmware data overlaps reserved DMA test buffers")

  .dma_source 0x00002000 (NOLOAD) : { _dma_source = .; . += 0x100; } > SRAM
  .dma_destination 0x00003000 (NOLOAD) : { _dma_destination = .; . += 0x100; } > SRAM
  .dma_descriptors 0x00004000 (NOLOAD) : { _dma_descriptors = .; . += 0x100; } > SRAM
  .dma_results 0x00005000 (NOLOAD) : { _dma_results = .; . += 0x100; } > SRAM
  _stack_top = 0x00007ff0;
}
