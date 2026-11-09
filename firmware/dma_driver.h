#ifndef DMA_DRIVER_H
#define DMA_DRIVER_H
#include <stdint.h>

#define DMA_BASE          0x00008000u
#define DMA_DESC_BASE     (*(volatile uint32_t *)(DMA_BASE + 0x00u))
#define DMA_DESC_LIMIT    (*(volatile uint32_t *)(DMA_BASE + 0x04u))
#define DMA_CONTROL       (*(volatile uint32_t *)(DMA_BASE + 0x08u))
#define DMA_STATUS        (*(volatile uint32_t *)(DMA_BASE + 0x0Cu))
#define DMA_ERROR_CODE    (*(volatile uint32_t *)(DMA_BASE + 0x10u))
#define DMA_COMPLETED     (*(volatile uint32_t *)(DMA_BASE + 0x14u))
#define DMA_IRQ_STATUS    (*(volatile uint32_t *)(DMA_BASE + 0x18u))
#define DMA_IRQ_ENABLE    (*(volatile uint32_t *)(DMA_BASE + 0x1Cu))

#define DMA_CTRL_START    (1u << 0)
#define DMA_CTRL_ABORT    (1u << 1)
#define DMA_CTRL_RESET    (1u << 2)
#define DMA_ST_BUSY       (1u << 0)
#define DMA_ST_DONE       (1u << 1)
#define DMA_ST_FAULT      (1u << 2)
#define DMA_ST_ABORTED    (1u << 3)
#define DMA_IRQ_DONE      (1u << 0)
#define DMA_IRQ_FAULT     (1u << 1)
#define DMA_IRQ_ABORT     (1u << 2)

typedef struct {
    uint32_t src_addr;
    uint32_t dst_addr;
    uint32_t length_bytes;
    uint32_t next_desc;
    uint32_t control;
} dma_descriptor_t;

int dma_init(void);
int dma_submit(volatile dma_descriptor_t *first, uint32_t descriptor_limit);
int dma_wait(uint32_t timeout_iterations);
void dma_abort(void);
uint32_t dma_error(void);
uint32_t dma_completed_count(void);

#endif
