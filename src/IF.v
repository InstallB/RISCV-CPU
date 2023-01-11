`include "config.v"

`ifndef __IFetch
`define __IFetch

module IF(
    input wire clk,
    input wire rst,
    input wire rdy,

    input wire jump_rst,
    input wire [31:0] jump_pc,

    input wire RS_full,
    input wire SLB_full,
    input wire ROB_full,

    output reg ID_send,

    output reg [31:0] instruction,
    output reg pred_result, // directly connect to issue
    output reg [31:0] inst_pc, // directly connect to issue

    input wire mem_valid,
    input wire [31:0] mem_val,
    output reg mem_send,
    output reg [31:0] mem_addr,

    input wire pred,
    input wire pred_val
);

reg [1:0] pred_cnt;

integer i;
reg mem_fetch_flag;
reg valid[`ICACHE_SIZE - 1:0];
reg [7:0] tag[`ICACHE_SIZE - 1:0];
reg [31:0] val[`ICACHE_SIZE - 1:0];

reg [31:0] pc;
wire [7:0] pc_index = pc[9:2];
wire [7:0] pc_tag = pc[17:10];

wire hit = valid[pc_index] && (tag[pc_index] == pc_tag);
wire [31:0] inst = val[pc_index];

always @(posedge clk) begin
    ID_send <= 0;
    if(rst) begin
        ID_send <= 0;
        pred_cnt <= 2'b00;
        for(i = 0;i < `ICACHE_SIZE;i = i + 1) begin
            valid[i] <= 0;
            tag[i] <= 0;
            val[i] <= 0;
        end
    end else if(!rdy) begin
    end else begin
        if(!jump_rst) begin
            if(mem_fetch_flag) begin
                if(mem_valid) begin
                    valid[mem_addr[9:2]] <= 1;
                    tag[mem_addr[9:2]] <= mem_addr[17:10];
                    val[mem_addr[9:2]] <= mem_val;
                    mem_fetch_flag <= 0;
                    mem_send <= 0;
                end
            end else if(!hit) begin
                mem_fetch_flag <= 1;
                mem_send <= 1;
                mem_addr <= pc;
            end
            // get inst from memory
            if(pred) begin
                if(pred_cnt > 2'b00 && pred_val == 0) begin
                    pred_cnt <= pred_cnt - 2'b01;
                end
                if(pred_cnt < 2'b11 && pred_val == 1) begin
                    pred_cnt <= pred_cnt + 2'b01;
                end
            end
            // modify predictor
        end

        if(jump_rst) begin
            ID_send <= 0;
            pc <= jump_pc;
        end else if(RS_full || SLB_full || ROB_full) begin
            ID_send <= 0;
        end else begin
            ID_send <= 0;
            if(hit) begin
                if(inst[6:0] == 7'b1100011 && pred_cnt >= 2'b10) begin
                    pc <= pc + {{19{inst[31]}},inst[31],inst[7],inst[30:25],inst[11:8],1'b0};
                    pred_result <= 1;
                end else begin
                    pc <= pc + 4;
                    pred_result <= 0;
                end
                ID_send <= 1;
                instruction <= inst;
                inst_pc <= pc;
            end
        end
    end
end

endmodule

// if ROB or RS/SLB not valid (full), DON'T send instruction
// [IF-ID-issue]

`endif