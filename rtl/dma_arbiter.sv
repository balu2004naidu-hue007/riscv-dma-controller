// Single-outstanding round-robin arbiter for CPU and DMA memory masters.
module dma_arbiter(
    input logic clk, rst_n,
    input logic c_valid, c_write, input logic [31:0] c_addr, c_wdata, input logic [3:0] c_wstrb,
    output logic c_ready, output logic [31:0] c_rdata,
    input logic d_valid, d_write, input logic [31:0] d_addr, d_wdata, input logic [3:0] d_wstrb,
    output logic d_ready, output logic [31:0] d_rdata,
    output logic m_valid, m_write, output logic [31:0] m_addr, m_wdata, output logic [3:0] m_wstrb,
    input logic m_ready, input logic [31:0] m_rdata
);
    logic owner_valid, owner_dma, last_grant_dma;
    logic choose_dma;
    always_comb begin
        choose_dma = d_valid && (!c_valid || !last_grant_dma);
        m_valid = owner_valid ? (owner_dma ? d_valid : c_valid) : (c_valid || d_valid);
        m_write = 0; m_addr = 0; m_wdata = 0; m_wstrb = 0;
        if (owner_valid ? owner_dma : choose_dma) begin
            m_write=d_write; m_addr=d_addr; m_wdata=d_wdata; m_wstrb=d_wstrb;
        end else begin
            m_write=c_write; m_addr=c_addr; m_wdata=c_wdata; m_wstrb=c_wstrb;
        end
        c_ready = 0; d_ready = 0; c_rdata = m_rdata; d_rdata = m_rdata;
        if (m_ready && m_valid) begin
            if (owner_valid ? owner_dma : choose_dma) d_ready=1;
            else c_ready=1;
        end
    end
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin owner_valid<=0; owner_dma<=0; last_grant_dma<=1; end
        else begin
            if (!owner_valid && m_valid && !m_ready) begin owner_valid<=1; owner_dma<=choose_dma; end
            if (m_valid && m_ready) begin
                last_grant_dma <= owner_valid ? owner_dma : choose_dma;
                owner_valid <= 0;
            end
        end
    end
endmodule
