`timescale 1ns/1ps
module dma_extended_tb;
    localparam logic [7:0] REG_DESC_BASE=8'h00, REG_DESC_LIMIT=8'h04,
        REG_CONTROL=8'h08, REG_STATUS=8'h0c, REG_ERROR=8'h10,
        REG_COMPLETED=8'h14, REG_IRQ_STATUS=8'h18, REG_IRQ_ENABLE=8'h1c;
    localparam logic [31:0] SRAM_BASE=32'h0000_1000;

    logic clk=0, rst_n=0;
    always #5 clk=~clk;
    logic reg_valid=0, reg_write=0;
    logic [7:0] reg_addr=0;
    logic [31:0] reg_wdata=0, reg_rdata;
    logic reg_ready;
    logic mem_valid, mem_write;
    logic [31:0] mem_addr, mem_wdata, mem_rdata;
    logic [3:0] mem_wstrb;
    logic mem_ready, irq;

    dma_controller dut(
        .clk(clk), .rst_n(rst_n),
        .reg_valid(reg_valid), .reg_write(reg_write), .reg_addr(reg_addr),
        .reg_wdata(reg_wdata), .reg_ready(reg_ready), .reg_rdata(reg_rdata),
        .mem_valid(mem_valid), .mem_write(mem_write), .mem_addr(mem_addr),
        .mem_wdata(mem_wdata), .mem_wstrb(mem_wstrb),
        .mem_ready(mem_ready), .mem_rdata(mem_rdata), .irq(irq)
    );

    simple_sram #(.WORDS(8192), .BASE(32'h0)) ram(
        .clk(clk), .rst_n(rst_n), .req(mem_valid), .write(mem_write),
        .addr(mem_addr), .wdata(mem_wdata), .wstrb(mem_wstrb),
        .ready(mem_ready), .rdata(mem_rdata)
    );

    // Global DMA master boundary monitor: the engine must never issue an
    // address outside the configured shared SRAM window.
    always @(posedge clk) begin
        if (rst_n && mem_valid && (mem_addr < 32'h0000_1000 || mem_addr >= 32'h0000_8000))
            $fatal(1,"DMA issued out-of-range memory request at %08x",mem_addr);
    end

    task automatic reg_wr(input logic [7:0] a, input logic [31:0] d);
        begin
            @(negedge clk);
            reg_valid=1; reg_write=1; reg_addr=a; reg_wdata=d;
            @(posedge clk); #1;
            reg_valid=0; reg_write=0;
        end
    endtask

    task automatic reset_engine;
        begin
            reg_wr(REG_CONTROL, 32'd4);
            reg_wr(REG_IRQ_STATUS, 32'h7);
        end
    endtask

    task automatic load_desc(input logic [31:0] address,
                             input logic [31:0] src,
                             input logic [31:0] dst,
                             input logic [31:0] length,
                             input logic [31:0] next_address,
                             input logic [31:0] control_word);
        integer base_word;
        begin
            base_word = address >> 2;
            ram.mem[base_word+0] = src;
            ram.mem[base_word+1] = dst;
            ram.mem[base_word+2] = length;
            ram.mem[base_word+3] = next_address;
            ram.mem[base_word+4] = control_word;
        end
    endtask

    task automatic wait_done(input integer max_cycles);
        integer n;
        begin
            n=0;
            while (!dut.done_flag && !dut.fault_flag && !dut.aborted_flag && n<max_cycles) begin
                @(posedge clk); n=n+1;
            end
            if (n>=max_cycles) $fatal(1,"timeout waiting for terminal state");
        end
    endtask

    integer k;
    initial begin
        $dumpfile("build/dma_extended.vcd");
        $dumpvars(0,dma_extended_tb);
        repeat (4) @(posedge clk);
        @(negedge clk); rst_n=1;

        // T01: two chained descriptors; both copies must complete.
        load_desc(32'h1000,32'h2000,32'h3000,32'd16,32'h1020,0);
        load_desc(32'h1020,32'h2100,32'h3100,32'd16,0,0);
        for (k=0;k<4;k=k+1) begin
            ram.mem[2048+k]=32'hA100_0000+k;
            ram.mem[2112+k]=32'hB200_0000+k;
        end
        reg_wr(REG_DESC_BASE,32'h1000);
        reg_wr(REG_DESC_LIMIT,32'd2);
        reg_wr(REG_IRQ_ENABLE,32'd7);
        reg_wr(REG_CONTROL,32'd1);
        wait_done(600);
        if (!dut.done_flag || dut.completed_count!=2) $fatal(1,"chain completion/count failure");
        for (k=0;k<4;k=k+1) begin
            if (ram.mem[3072+k] !== (32'hA100_0000+k)) $fatal(1,"chain descriptor 1 mismatch");
            if (ram.mem[3136+k] !== (32'hB200_0000+k)) $fatal(1,"chain descriptor 2 mismatch");
        end
        if (!dut.irq_status[0] || !irq) $fatal(1,"DONE IRQ not asserted");
        $display("PASS T01: chained descriptors, data integrity, count and DONE IRQ");

        // T02: chain limit is enforced after one completed descriptor.
        reset_engine();
        load_desc(32'h1000,32'h2000,32'h3000,32'd16,32'h1020,0);
        load_desc(32'h1020,32'h2100,32'h3100,32'd16,0,0);
        reg_wr(REG_DESC_BASE,32'h1000);
        reg_wr(REG_DESC_LIMIT,32'd1);
        reg_wr(REG_CONTROL,32'd1);
        wait_done(600);
        if (!dut.fault_flag || dut.error_code!=4'd10 || dut.completed_count!=1)
            $fatal(1,"descriptor limit fault/count incorrect");
        $display("PASS T02: descriptor-chain limit enforced; completed descriptor retained");

        // T03: invalid destination is rejected before any data write.
        reset_engine();
        load_desc(32'h1000,32'h2000,32'h8000,32'd4,0,0);
        reg_wr(REG_DESC_BASE,32'h1000);
        reg_wr(REG_DESC_LIMIT,32'd4);
        reg_wr(REG_CONTROL,32'd1);
        wait_done(300);
        if (!dut.fault_flag || dut.error_code!=4'd8) $fatal(1,"expected destination range fault");
        if (dut.completed_count!=0) $fatal(1,"faulted descriptor counted as complete");
        if (ram.mem[3072] !== 32'hA100_0000) $fatal(1,"invalid descriptor modified destination");
        if (!dut.irq_status[1]) $fatal(1,"FAULT IRQ status not set");
        $display("PASS T03: invalid destination rejected before data write");

        // T04: abort while a source read is outstanding must suppress the next write.
        reset_engine();
        load_desc(32'h1000,32'h2000,32'h3200,32'd64,0,0);
        reg_wr(REG_DESC_BASE,32'h1000);
        reg_wr(REG_DESC_LIMIT,32'd4);
        reg_wr(REG_CONTROL,32'd1);
        wait (dut.state==4'd3 && dut.mem_inflight && mem_ready);
        #1;
        reg_valid=1; reg_write=1; reg_addr=REG_CONTROL; reg_wdata=32'd2;
        @(posedge clk); #1; reg_valid=0; reg_write=0;
        wait_done(100);
        if (!dut.aborted_flag || dut.completed_count!=0) $fatal(1,"abort state/count incorrect");
        if (ram.mem[3200] !== 32'h0000_0000) $fatal(1,"abort after read issued an unwanted destination write");
        if (!dut.irq_status[2]) $fatal(1,"ABORT IRQ status not set");
        $display("PASS T04: abort at read response suppresses following write and raises ABORT IRQ");

        // T05: recovery after abort.
        reset_engine();
        load_desc(32'h1000,32'h2000,32'h3200,32'd4,0,0);
        reg_wr(REG_DESC_BASE,32'h1000);
        reg_wr(REG_DESC_LIMIT,32'd1);
        reg_wr(REG_CONTROL,32'd1);
        wait_done(300);
        if (!dut.done_flag || ram.mem[3200] !== 32'hA100_0000)
            $fatal(1,"valid transfer after abort recovery failed");
        $display("PASS T05: valid transfer after abort recovery");

        // T06: a malformed next-descriptor pointer is rejected before the
        // current descriptor is allowed to move any payload data.
        reset_engine();
        load_desc(32'h1000,32'h2000,32'h3300,32'd4,32'h1001,0);
        reg_wr(REG_DESC_BASE,32'h1000);
        reg_wr(REG_DESC_LIMIT,32'd4);
        reg_wr(REG_CONTROL,32'd1);
        wait_done(300);
        if (!dut.fault_flag || dut.error_code!=4'd1 || dut.completed_count!=0)
            $fatal(1,"invalid next descriptor pointer not rejected during validation");
        if (ram.mem[3264] !== 32'h0000_0000)
            $fatal(1,"payload write occurred despite invalid next descriptor pointer");
        $display("PASS T06: invalid next descriptor rejected before payload transfer");

        // T07: overlapping buffers are rejected before a write is issued.
        reset_engine();
        load_desc(32'h1000,32'h2000,32'h2004,32'd16,0,0);
        reg_wr(REG_DESC_BASE,32'h1000);
        reg_wr(REG_DESC_LIMIT,32'd1);
        reg_wr(REG_CONTROL,32'd1);
        wait_done(300);
        if (!dut.fault_flag || dut.error_code!=4'd9 || dut.completed_count!=0)
            $fatal(1,"overlap validation failed");
        $display("PASS T07: overlapping source/destination rejected");

        // T08: zero-length descriptor is rejected.
        reset_engine();
        load_desc(32'h1000,32'h2000,32'h3300,32'd0,0,0);
        reg_wr(REG_DESC_BASE,32'h1000);
        reg_wr(REG_DESC_LIMIT,32'd1);
        reg_wr(REG_CONTROL,32'd1);
        wait_done(300);
        if (!dut.fault_flag || dut.error_code!=4'd5)
            $fatal(1,"zero-length descriptor not rejected");
        $display("PASS T08: zero-length descriptor rejected");

        $display("ALL EXTENDED DMA TESTS PASSED");
        $finish;
    end
    initial begin
        #200000;
        $fatal(1,"global extended DMA test timeout");
    end
endmodule
