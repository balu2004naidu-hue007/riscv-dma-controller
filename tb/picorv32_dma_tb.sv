`timescale 1ns/1ps
module picorv32_dma_tb;
    logic clk=0, resetn=0;
    logic trap;
    always #5 clk=~clk;

    picorv32_dma_soc #(.MEM_FILE("build/dma_firmware.mem")) dut(
        .clk(clk), .resetn(resetn), .trap(trap)
    );


    integer cycles;
    integer i;
    initial begin
        $dumpfile("build/picorv32_dma.vcd");
        $dumpvars(0,picorv32_dma_tb);
        repeat(8) @(posedge clk);
        @(negedge clk); resetn=1;
        cycles=0;
        while (dut.fabric.memory.mem[5120] !== 32'hD00DCAFE && !trap && cycles<200000) begin
            @(posedge clk); cycles=cycles+1;
        end
        if (trap) $fatal(1,"PicoRV32 trapped before DMA benchmark completed");
        if (dut.fabric.memory.mem[5120] !== 32'hD00DCAFE)
            $fatal(1,"timeout waiting for firmware benchmark completion");

        for (i=0; i<3; i=i+1) begin
            if (dut.fabric.memory.mem[5121+i] !== (i==0 ? 16 : (i==1 ? 64 : 256)))
                $fatal(1,"benchmark byte-size record mismatch at index %0d",i);
            if (dut.fabric.memory.mem[5124+i] == 0)
                $fatal(1,"CPU cycle count missing at index %0d",i);
            if (dut.fabric.memory.mem[5127+i] == 0)
                $fatal(1,"DMA cycle count missing at index %0d",i);
            if (dut.fabric.memory.mem[5130+i] !== 1)
                $fatal(1,"DMA completed descriptor count incorrect at index %0d",i);
            if (dut.fabric.memory.mem[5133+i] !== 0)
                $fatal(1,"firmware recorded error at index %0d",i);
        end

        if (dut.fabric.memory.mem[3072] !== 32'hD00D0000)
            $fatal(1,"final 256-byte DMA destination word 0 mismatch");
        if (dut.fabric.memory.mem[3135] !== 32'hD00D003F)
            $fatal(1,"final 256-byte DMA destination word 63 mismatch");

        $display("PASS: PicoRV32 firmware completed 16/64/256-byte CPU-vs-DMA benchmarks in %0d cycles",cycles);
        $display("Cycles: 16B CPU=%0d DMA=%0d; 64B CPU=%0d DMA=%0d; 256B CPU=%0d DMA=%0d",
            dut.fabric.memory.mem[5124],dut.fabric.memory.mem[5127],
            dut.fabric.memory.mem[5125],dut.fabric.memory.mem[5128],
            dut.fabric.memory.mem[5126],dut.fabric.memory.mem[5129]);
        $finish;
    end
    initial begin #3000000; $fatal(1,"global CPU test timeout"); end
endmodule
