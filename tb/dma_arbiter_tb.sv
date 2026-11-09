`timescale 1ns/1ps
module dma_arbiter_tb;
    logic clk=0, rst_n=0;
    always #5 clk=~clk;
    logic c_valid=0, c_write=0, d_valid=0, d_write=0;
    logic [31:0] c_addr=0, c_wdata=0, d_addr=0, d_wdata=0;
    logic [3:0] c_wstrb=0, d_wstrb=0;
    logic c_ready, d_ready, m_valid, m_write;
    logic [31:0] c_rdata, d_rdata, m_addr, m_wdata;
    logic [3:0] m_wstrb;
    logic m_ready=0;
    logic [31:0] m_rdata=32'h12345678;

    dma_arbiter dut(.*);
    integer n;
    initial begin
        repeat(3) @(posedge clk);
        @(negedge clk); rst_n=1;
        @(negedge clk);
        c_valid=1; d_valid=1;
        c_addr=32'h1111_0000; d_addr=32'h2222_0000;
        #1;
        // Reset initializes last_grant_dma=1, so CPU wins first. Hold the
        // target not-ready and prove the grant is retained under backpressure.
        if (!m_valid || m_addr!=c_addr || c_ready || d_ready)
            $fatal(1,"expected CPU selection while target is stalled");
        repeat(2) begin
            @(posedge clk); #1;
            if (!m_valid || m_addr!=c_addr || c_ready || d_ready)
                $fatal(1,"arbiter did not retain CPU ownership under backpressure");
        end
        @(negedge clk); m_ready=1;
        #1;
        if (!c_ready || d_ready || m_addr!=c_addr)
            $fatal(1,"expected CPU response first");
        @(posedge clk); #1;
        if (!d_ready || c_ready || m_addr!=d_addr)
            $fatal(1,"expected DMA response second");
        @(posedge clk); #1;
        if (!c_ready || d_ready || m_addr!=c_addr)
            $fatal(1,"expected CPU response third");
        @(posedge clk); #1;
        if (!d_ready || c_ready || m_addr!=d_addr)
            $fatal(1,"expected DMA response fourth");
        $display("PASS: backpressure retention and round-robin progress for both masters");
        $finish;
    end
    initial begin #1000; $fatal(1,"arbiter test timeout"); end
endmodule
