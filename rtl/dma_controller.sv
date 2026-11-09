// Single-channel, 32-bit, memory-to-memory DMA controller.
// Register bus and memory master use independent valid/ready handshakes.
module dma_controller #(
    parameter logic [31:0] SRAM_BASE = 32'h0000_1000,
    parameter logic [31:0] SRAM_END  = 32'h0000_8000, // exclusive
    parameter int unsigned MAX_DESCRIPTORS = 256
)(
    input  logic        clk,
    input  logic        rst_n,
    // CPU register access
    input  logic        reg_valid,
    input  logic        reg_write,
    input  logic [7:0]  reg_addr,
    input  logic [31:0] reg_wdata,
    output logic        reg_ready,
    output logic [31:0] reg_rdata,
    // DMA memory master
    output logic        mem_valid,
    output logic        mem_write,
    output logic [31:0] mem_addr,
    output logic [31:0] mem_wdata,
    output logic [3:0]  mem_wstrb,
    input  logic        mem_ready,
    input  logic [31:0] mem_rdata,
    output logic        irq
);
    localparam logic [7:0] REG_DESC_BASE = 8'h00;
    localparam logic [7:0] REG_DESC_LIMIT= 8'h04;
    localparam logic [7:0] REG_CONTROL   = 8'h08;
    localparam logic [7:0] REG_STATUS    = 8'h0c;
    localparam logic [7:0] REG_ERROR     = 8'h10;
    localparam logic [7:0] REG_COMPLETED = 8'h14;
    localparam logic [7:0] REG_IRQ_STATUS= 8'h18;
    localparam logic [7:0] REG_IRQ_ENABLE= 8'h1c;

    localparam logic [3:0] E_NONE=0, E_DESC_ALIGN=1, E_DESC_RANGE=2,
        E_SRC_ALIGN=3, E_DST_ALIGN=4, E_ZERO_LEN=5, E_LEN_ALIGN=6,
        E_SRC_RANGE=7, E_DST_RANGE=8, E_OVERLAP=9, E_DESC_LIMIT=10,
        E_CONTROL=11;

    typedef enum logic [3:0] {IDLE, FETCH_DESC, VALIDATE_DESC, READ_SRC,
        WRITE_DST, NEXT_DESC, FINISH, FAULT, ABORTED} state_t;
    state_t state;

    logic [31:0] desc_base, desc_ptr, desc_limit, completed_count;
    logic [31:0] src_addr, dst_addr, length_bytes, next_desc, desc_control;
    logic [2:0] fetch_index;
    logic [31:0] remaining;
    logic [31:0] data_latch;
    logic [3:0] error_code;
    logic done_flag, fault_flag, aborted_flag;
    logic [2:0] irq_status, irq_enable;
    logic abort_pending;
    logic mem_inflight;

    logic [32:0] src_end_ext, dst_end_ext;
    logic src_range_ok, dst_range_ok, overlap;
    logic [3:0] validation_error;

    always_comb begin
        src_end_ext  = {1'b0,src_addr} + {1'b0,length_bytes};
        dst_end_ext  = {1'b0,dst_addr} + {1'b0,length_bytes};
        src_range_ok = (src_end_ext <= {1'b0,SRAM_END}) &&
                       (src_addr >= SRAM_BASE) && (src_addr < SRAM_END) &&
                       (src_end_ext > {1'b0,src_addr});
        dst_range_ok = (dst_end_ext <= {1'b0,SRAM_END}) &&
                       (dst_addr >= SRAM_BASE) && (dst_addr < SRAM_END) &&
                       (dst_end_ext > {1'b0,dst_addr});
        overlap = ({1'b0,src_addr} < dst_end_ext) &&
                  ({1'b0,dst_addr} < src_end_ext);
        validation_error = E_NONE;
        if (desc_control != 0) validation_error = E_CONTROL;
        else if (next_desc != 0 && next_desc[1:0] != 0) validation_error = E_DESC_ALIGN;
        else if (next_desc != 0 && (next_desc < SRAM_BASE ||
                 ({1'b0,next_desc} + 33'd20) > {1'b0,SRAM_END})) validation_error = E_DESC_RANGE;
        else if (src_addr[1:0] != 0) validation_error = E_SRC_ALIGN;
        else if (dst_addr[1:0] != 0) validation_error = E_DST_ALIGN;
        else if (length_bytes == 0) validation_error = E_ZERO_LEN;
        else if (length_bytes[1:0] != 0) validation_error = E_LEN_ALIGN;
        else if (!src_range_ok) validation_error = E_SRC_RANGE;
        else if (!dst_range_ok) validation_error = E_DST_RANGE;
        else if (overlap) validation_error = E_OVERLAP;
    end

    always_comb begin
        reg_ready = reg_valid;
        reg_rdata = 32'b0;
        case (reg_addr)
            REG_DESC_BASE:  reg_rdata = desc_base;
            REG_DESC_LIMIT: reg_rdata = desc_limit;
            REG_CONTROL:    reg_rdata = 32'b0;
            REG_STATUS:     reg_rdata = {28'b0,aborted_flag,fault_flag,done_flag,(state!=IDLE && state!=FAULT && state!=ABORTED)};
            REG_ERROR:      reg_rdata = {28'b0,error_code};
            REG_COMPLETED:  reg_rdata = completed_count;
            REG_IRQ_STATUS: reg_rdata = {29'b0,irq_status};
            REG_IRQ_ENABLE: reg_rdata = {29'b0,irq_enable};
            default:        reg_rdata = 32'b0;
        endcase
    end

    always_comb begin
        mem_valid = 1'b0;
        mem_write = 1'b0;
        mem_addr = 32'b0;
        mem_wdata = 32'b0;
        mem_wstrb = 4'b0000;
        case (state)
            FETCH_DESC: begin
                mem_valid = 1'b1;
                mem_addr = desc_ptr + {27'b0,fetch_index,2'b00};
            end
            READ_SRC: begin
                mem_valid = 1'b1;
                mem_addr = src_addr;
            end
            WRITE_DST: begin
                mem_valid = 1'b1;
                mem_write = 1'b1;
                mem_addr = dst_addr;
                mem_wdata = data_latch;
                mem_wstrb = 4'b1111;
            end
            default: begin end
        endcase
        // Do not launch a new bus transaction after abort has been requested.
        // An already outstanding request remains asserted until its response.
        if (abort_pending && !mem_inflight) mem_valid = 1'b0;
    end

    assign irq = |(irq_status & irq_enable);

    task automatic raise_fault(input logic [3:0] code);
        begin
            error_code <= code;
            fault_flag <= 1'b1;
            irq_status[1] <= 1'b1;
            state <= FAULT;
        end
    endtask

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            desc_base <= 0; desc_ptr <= 0; desc_limit <= 0;
            completed_count <= 0; src_addr <= 0; dst_addr <= 0;
            length_bytes <= 0; next_desc <= 0; desc_control <= 0;
            fetch_index <= 0; remaining <= 0; data_latch <= 0;
            error_code <= E_NONE; done_flag <= 0; fault_flag <= 0;
            aborted_flag <= 0; irq_status <= 0; irq_enable <= 0;
            abort_pending <= 0; mem_inflight <= 0;
        end else begin
            if (mem_valid && !mem_inflight && !mem_ready)
                mem_inflight <= 1'b1;
            else if (mem_inflight && mem_ready)
                mem_inflight <= 1'b0;
            if (reg_valid && reg_ready && reg_write) begin
                case (reg_addr)
                    REG_DESC_BASE: if (state == IDLE || state == FAULT || state == ABORTED) desc_base <= reg_wdata;
                    REG_DESC_LIMIT: if (state == IDLE || state == FAULT || state == ABORTED) desc_limit <= reg_wdata;
                    REG_CONTROL: begin
                        if (reg_wdata[2]) begin
                            if (state == IDLE || state == FAULT || state == ABORTED) begin
                                state <= IDLE; error_code <= E_NONE; done_flag <= 0;
                                fault_flag <= 0; aborted_flag <= 0; completed_count <= 0;
                                irq_status <= 0; abort_pending <= 0;
                            end
                        end else if (reg_wdata[1]) begin
                            if (state != IDLE && state != FINISH && state != FAULT && state != ABORTED) abort_pending <= 1'b1;
                        end else if (reg_wdata[0]) begin
                            if (state == IDLE || state == FAULT || state == ABORTED) begin
                                done_flag <= 0; fault_flag <= 0; aborted_flag <= 0;
                                error_code <= E_NONE; completed_count <= 0;
                                irq_status <= 0; abort_pending <= 0;
                                if ((desc_base[1:0] != 0)) raise_fault(E_DESC_ALIGN);
                                else if (desc_base < SRAM_BASE || ({1'b0,desc_base}+33'd20) > {1'b0,SRAM_END}) raise_fault(E_DESC_RANGE);
                                else if (desc_limit == 0 || desc_limit > MAX_DESCRIPTORS) raise_fault(E_DESC_LIMIT);
                                else begin desc_ptr <= desc_base; fetch_index <= 0; state <= FETCH_DESC; end
                            end
                        end
                    end
                    REG_STATUS: begin
                        if (reg_wdata[1]) done_flag <= 0;
                        if (reg_wdata[2]) fault_flag <= 0;
                        if (reg_wdata[3]) aborted_flag <= 0;
                    end
                    REG_IRQ_STATUS: irq_status <= irq_status & ~reg_wdata[2:0];
                    REG_IRQ_ENABLE: irq_enable <= reg_wdata[2:0];
                    default: begin end
                endcase
            end

            // Abort is honored at the next bus-transaction boundary. If a
            // memory request is already outstanding, allow that one request
            // to be acknowledged, then stop before issuing another request.
            // In NEXT_DESC / VALIDATE_DESC there is no outstanding bus request,
            // so abort immediately rather than fetching/starting another item.
            if (abort_pending) begin
                // If a request was already presented to the arbiter, keep it
                // stable through its response. Otherwise abort before issuing
                // the next descriptor/data request.
                if ((!mem_inflight && !mem_valid) || (mem_inflight && mem_ready)) begin
                    abort_pending <= 1'b0;
                    aborted_flag <= 1'b1;
                    irq_status[2] <= 1'b1;
                    state <= ABORTED;
                end
            end else begin
                case (state)
                    IDLE: begin end
                    FETCH_DESC: if (mem_valid && mem_ready) begin
                        case (fetch_index)
                            0: src_addr <= mem_rdata;
                            1: dst_addr <= mem_rdata;
                            2: length_bytes <= mem_rdata;
                            3: next_desc <= mem_rdata;
                            4: begin desc_control <= mem_rdata; state <= VALIDATE_DESC; end
                            default: raise_fault(E_DESC_RANGE);
                        endcase
                        if (fetch_index != 4) fetch_index <= fetch_index + 1'b1;
                    end
                    VALIDATE_DESC: begin
                        if (validation_error != E_NONE) raise_fault(validation_error);
                        else begin remaining <= length_bytes; state <= READ_SRC; end
                    end
                    READ_SRC: if (mem_valid && mem_ready) begin data_latch <= mem_rdata; state <= WRITE_DST; end
                    WRITE_DST: if (mem_valid && mem_ready) begin
                        src_addr <= src_addr + 4; dst_addr <= dst_addr + 4;
                        remaining <= remaining - 4;
                        if (remaining == 4) begin completed_count <= completed_count + 1; state <= NEXT_DESC; end
                        else state <= READ_SRC;
                    end
                    NEXT_DESC: begin
                        if (next_desc == 0) state <= FINISH;
                        else if (completed_count >= desc_limit) raise_fault(E_DESC_LIMIT);
                        else if (next_desc[1:0] != 0) raise_fault(E_DESC_ALIGN);
                        else if (next_desc < SRAM_BASE || ({1'b0,next_desc}+33'd20) > {1'b0,SRAM_END}) raise_fault(E_DESC_RANGE);
                        else begin desc_ptr <= next_desc; fetch_index <= 0; state <= FETCH_DESC; end
                    end
                    FINISH: begin done_flag <= 1; irq_status[0] <= 1; state <= IDLE; end
                    FAULT: begin end
                    ABORTED: begin end
                    default: raise_fault(E_DESC_RANGE);
                endcase
            end
        end
    end
endmodule
