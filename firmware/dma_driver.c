#include "dma_driver.h"

#define SRAM_START 0x00001000u
#define SRAM_END   0x00008000u

int dma_init(void)
{
    DMA_CONTROL = DMA_CTRL_RESET;
    DMA_IRQ_STATUS = 7u;
    DMA_IRQ_ENABLE = 0u; /* polling example; IRQ path is tested separately in RTL */
    return (DMA_STATUS & DMA_ST_BUSY) ? -1 : 0;
}

int dma_submit(volatile dma_descriptor_t *first, uint32_t descriptor_limit)
{
    uintptr_t p = (uintptr_t)first;
    uint64_t end = (uint64_t)p + (uint64_t)sizeof(*first);
    if ((p & 3u) != 0u || p < SRAM_START || end > SRAM_END)
        return -1;
    if (DMA_STATUS & DMA_ST_BUSY)
        return -3;
    if (descriptor_limit == 0u || descriptor_limit > 256u)
        return -2;
    DMA_CONTROL = DMA_CTRL_RESET;
    DMA_DESC_BASE = (uint32_t)p;
    DMA_DESC_LIMIT = descriptor_limit;
#if defined(__riscv)
    __asm__ volatile ("fence iorw, iorw" ::: "memory");
#endif
    DMA_CONTROL = DMA_CTRL_START;
    return 0;
}

int dma_wait(uint32_t timeout_iterations)
{
    while (timeout_iterations-- != 0u) {
        uint32_t status = DMA_STATUS;
        if (status & DMA_ST_FAULT) return -(int)DMA_ERROR_CODE;
        if (status & DMA_ST_ABORTED) return -100;
        if (status & DMA_ST_DONE) {
#if defined(__riscv)
            __asm__ volatile ("fence iorw, iorw" ::: "memory");
#endif
            return 0;
        }
    }
    return -101; /* polling timeout */
}

void dma_abort(void) { DMA_CONTROL = DMA_CTRL_ABORT; }
uint32_t dma_error(void) { return DMA_ERROR_CODE; }
uint32_t dma_completed_count(void) { return DMA_COMPLETED; }
