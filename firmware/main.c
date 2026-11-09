#include "dma_driver.h"

#define TEST_SRC     ((volatile uint32_t *)0x00002000u)
#define TEST_DST     ((volatile uint32_t *)0x00003000u)
#define TEST_DESC    ((volatile dma_descriptor_t *)0x00004000u)
#define TEST_RESULTS ((volatile dma_bench_result_t *)0x00005000u)
#define RESULT_MAGIC 0xD00DCAFEu

typedef struct {
    uint32_t magic;
    uint32_t bytes[3];
    uint32_t cpu_cycles[3];
    uint32_t dma_cycles[3];
    uint32_t completed[3];
    uint32_t errors[3];
} dma_bench_result_t;

static uint32_t read_cycles(void)
{
#if defined(__riscv)
    uint32_t value;
    __asm__ volatile ("rdcycle %0" : "=r"(value) :: "memory");
    return value;
#else
    static uint32_t host_counter;
    return ++host_counter;
#endif
}

int main(void)
{
    static const uint32_t sizes[3] = {16u, 64u, 256u};
    unsigned i, j;

    TEST_RESULTS->magic = 0u;
    for (i = 0; i < 64; ++i) {
        TEST_SRC[i] = 0xD00D0000u + i;
        TEST_DST[i] = 0u;
    }

    if (dma_init() != 0) for (;;) { }

    for (i = 0; i < 3; ++i) {
        uint32_t words = sizes[i] / sizeof(uint32_t);
        uint32_t start, end;

        start = read_cycles();
        for (j = 0; j < words; ++j)
            TEST_DST[j] = TEST_SRC[j];
        end = read_cycles();
        TEST_RESULTS->bytes[i] = sizes[i];
        TEST_RESULTS->cpu_cycles[i] = end - start;
        TEST_RESULTS->dma_cycles[i] = 0u;
        TEST_RESULTS->completed[i] = 0u;
        TEST_RESULTS->errors[i] = 0u;

        for (j = 0; j < words; ++j)
            TEST_DST[j] = 0u;

        TEST_DESC->src_addr = (uint32_t)(uintptr_t)TEST_SRC;
        TEST_DESC->dst_addr = (uint32_t)(uintptr_t)TEST_DST;
        TEST_DESC->length_bytes = sizes[i];
        TEST_DESC->next_desc = 0u;
        TEST_DESC->control = 0u;

        start = read_cycles();
        if (dma_submit(TEST_DESC, 1u) != 0) {
            TEST_RESULTS->errors[i] = 1u;
            for (;;) { }
        }
        if (dma_wait(1000000u) != 0) {
            TEST_RESULTS->errors[i] = dma_error() ? dma_error() : 2u;
            for (;;) { }
        }
        end = read_cycles();
        TEST_RESULTS->dma_cycles[i] = end - start;
        TEST_RESULTS->completed[i] = dma_completed_count();

        for (j = 0; j < words; ++j) {
            if (TEST_DST[j] != TEST_SRC[j]) {
                TEST_RESULTS->errors[i] = 3u;
                for (;;) { }
            }
        }
    }

    __asm__ volatile ("" ::: "memory");
    TEST_RESULTS->magic = RESULT_MAGIC;
    for (;;) { }
}
