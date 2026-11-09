// Optional full-CPU wrapper. Compile this file together with the upstream
// picorv32.v from YosysHQ/picorv32. The standalone DMA test does not require it.
module picorv32_dma_soc #(parameter MEM_FILE = "")(
    input logic clk,
    input logic resetn,
    output logic trap
);
    logic mem_valid, mem_instr, mem_ready;
    logic [31:0] mem_addr, mem_wdata, mem_rdata;
    logic [3:0] mem_wstrb;
    logic dma_irq;
    logic [31:0] irq_lines;
    assign irq_lines = {31'b0, dma_irq};

    picorv32 #(
        .ENABLE_COUNTERS(1),
        .ENABLE_REGS_16_31(1),
        .PROGADDR_RESET(32'h0000_0000),
        .STACKADDR(32'h0000_7ff0)
    ) cpu (
        .clk(clk), .resetn(resetn), .trap(trap),
        .mem_valid(mem_valid), .mem_instr(mem_instr), .mem_ready(mem_ready),
        .mem_addr(mem_addr), .mem_wdata(mem_wdata), .mem_wstrb(mem_wstrb), .mem_rdata(mem_rdata),
        .irq(irq_lines)
    );

    dma_system_fabric #(.MEM_FILE(MEM_FILE)) fabric(
        .clk(clk), .rst_n(resetn),
        .cpu_valid(mem_valid), .cpu_addr(mem_addr), .cpu_wdata(mem_wdata),
        .cpu_wstrb(mem_wstrb), .cpu_ready(mem_ready), .cpu_rdata(mem_rdata),
        .dma_irq(dma_irq)
    );
endmodule
