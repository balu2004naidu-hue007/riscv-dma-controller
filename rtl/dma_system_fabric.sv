// System fabric shell around an external CPU native memory port.
// Connect PicoRV32 mem_* signals to cpu_* ports. This module deliberately
// does not embed/modify the upstream CPU source.
module dma_system_fabric #(parameter MEM_FILE = "")(
    input logic clk, rst_n,
    // PicoRV32 native memory interface
    input logic cpu_valid,
    input logic [31:0] cpu_addr, cpu_wdata,
    input logic [3:0] cpu_wstrb,
    output logic cpu_ready,
    output logic [31:0] cpu_rdata,
    // DMA interrupt
    output logic dma_irq
);
    logic reg_sel, cpu_mem_valid, cpu_mem_ready, cpu_write;
    logic [31:0] cpu_mem_rdata;
    logic dma_reg_ready;
    logic [31:0] dma_reg_rdata;

    logic d_valid, d_write, d_ready;
    logic [31:0] d_addr, d_wdata, d_rdata;
    logic [3:0] d_wstrb;

    logic m_valid, m_write, m_ready;
    logic [31:0] m_addr, m_wdata, m_rdata;
    logic [3:0] m_wstrb;

    assign cpu_write = |cpu_wstrb;
    assign reg_sel = (cpu_addr >= 32'h0000_8000) && (cpu_addr < 32'h0000_8100);
    assign cpu_mem_valid = cpu_valid && !reg_sel;
    assign cpu_ready = reg_sel ? dma_reg_ready : cpu_mem_ready;
    assign cpu_rdata = reg_sel ? dma_reg_rdata : cpu_mem_rdata;

    dma_controller dma(
        .clk(clk), .rst_n(rst_n),
        .reg_valid(cpu_valid && reg_sel), .reg_write(cpu_write),
        .reg_addr(cpu_addr[7:0]), .reg_wdata(cpu_wdata),
        .reg_ready(dma_reg_ready), .reg_rdata(dma_reg_rdata),
        .mem_valid(d_valid), .mem_write(d_write), .mem_addr(d_addr),
        .mem_wdata(d_wdata), .mem_wstrb(d_wstrb),
        .mem_ready(d_ready), .mem_rdata(d_rdata), .irq(dma_irq)
    );

    dma_arbiter arb(
        .clk(clk), .rst_n(rst_n),
        .c_valid(cpu_mem_valid), .c_write(cpu_write), .c_addr(cpu_addr),
        .c_wdata(cpu_wdata), .c_wstrb(cpu_wstrb), .c_ready(cpu_mem_ready), .c_rdata(cpu_mem_rdata),
        .d_valid(d_valid), .d_write(d_write), .d_addr(d_addr), .d_wdata(d_wdata),
        .d_wstrb(d_wstrb), .d_ready(d_ready), .d_rdata(d_rdata),
        .m_valid(m_valid), .m_write(m_write), .m_addr(m_addr), .m_wdata(m_wdata),
        .m_wstrb(m_wstrb), .m_ready(m_ready), .m_rdata(m_rdata)
    );

    // Simulation SRAM maps 0x00000000-0x00007fff. DMA itself only generates
    // legal requests in 0x00001000-0x00007fff. ROM protection is intentionally
    // not modeled in this compact teaching SoC; CPU can access the full RAM.
    simple_sram #(.WORDS(8192), .BASE(32'h0000_0000), .MEM_FILE(MEM_FILE)) memory(
        .clk(clk), .rst_n(rst_n), .req(m_valid), .write(m_write),
        .addr(m_addr), .wdata(m_wdata), .wstrb(m_wstrb),
        .ready(m_ready), .rdata(m_rdata)
    );
endmodule
