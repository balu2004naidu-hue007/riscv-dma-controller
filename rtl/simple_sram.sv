// Simulation SRAM: 32-bit words, byte write strobes, one-cycle request latency.
// ready is held high for the response cycle; requesters must deassert/change
// request only after sampling ready at a rising clock edge.
module simple_sram #(
    parameter int WORDS = 8192,
    parameter logic [31:0] BASE = 32'h0000_0000,
    parameter MEM_FILE = ""
)(
    input logic clk, rst_n,
    input logic req, write,
    input logic [31:0] addr, wdata,
    input logic [3:0] wstrb,
    output logic ready,
    output logic [31:0] rdata
);
    logic [31:0] mem [0:WORDS-1];
    logic pending;
    logic [31:0] saved_addr, saved_wdata;
    logic [3:0] saved_wstrb;
    logic saved_write;
    integer i;
    initial begin
        for (i=0;i<WORDS;i=i+1) mem[i]=0;
        if (MEM_FILE != "") $readmemh(MEM_FILE, mem);
    end
    assign ready = pending;
    always_comb begin
        rdata = 32'hBAD0_BAD0;
        if (pending && saved_addr >= BASE && (((saved_addr-BASE)>>2) < WORDS) && !saved_write)
            rdata = mem[(saved_addr-BASE)>>2];
    end
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            pending<=0; saved_addr<=0; saved_wdata<=0; saved_wstrb<=0; saved_write<=0;
        end else begin
            if (pending) begin
                if (saved_write && saved_addr >= BASE && (((saved_addr-BASE)>>2) < WORDS)) begin
                    if (saved_wstrb[0]) mem[(saved_addr-BASE)>>2][7:0] <= saved_wdata[7:0];
                    if (saved_wstrb[1]) mem[(saved_addr-BASE)>>2][15:8] <= saved_wdata[15:8];
                    if (saved_wstrb[2]) mem[(saved_addr-BASE)>>2][23:16] <= saved_wdata[23:16];
                    if (saved_wstrb[3]) mem[(saved_addr-BASE)>>2][31:24] <= saved_wdata[31:24];
                end
                pending <= 0;
            end else if (req) begin
                pending<=1; saved_addr<=addr; saved_wdata<=wdata;
                saved_wstrb<=wstrb; saved_write<=write;
            end
        end
    end
endmodule
