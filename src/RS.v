`include "config.v"

`ifndef ReservationStation
`define ReservationStation

module RS(
    input wire clk,
    input wire rst,
    input wire rdy,

    input wire jump_rst,

    input wire issue_send,
    input wire [`OP_SIZE_LOG - 1:0] issue_op,
    input wire [31:0] issue_Vj,
    input wire issue_Pj,
    input wire [`ROB_SIZE_LOG - 1:0] issue_Qj,
    input wire [31:0] issue_Vk,
    input wire issue_Pk,
    input wire [`ROB_SIZE_LOG - 1:0] issue_Qk,
    input wire [31:0] issue_imm,
    input wire [31:0] issue_curPC,
    input wire [`ROB_SIZE_LOG - 1:0] issue_reorder,

    output reg RS_send_ALU,
    output reg [`OP_SIZE_LOG - 1:0] ALU_op,
    output reg [31:0] ALU_Vj,
    output reg [31:0] ALU_Vk,
    output reg [31:0] ALU_imm,
    output reg [`ROB_SIZE_LOG - 1:0] ALU_reorder,
    output reg [31:0] ALU_curPC,

    input wire commit_send,
    input wire [31:0] commit_value,
    input wire [`ROB_SIZE_LOG - 1:0] commit_reorder,

    output wire RS_full
);

integer i;

reg [`RS_SIZE_LOG:0] sz; // size

reg busy[`RS_SIZE - 1:0];
reg [`OP_SIZE_LOG - 1:0] op[`RS_SIZE - 1:0];
reg [31:0] Vj[`RS_SIZE - 1:0];
reg Pj[`RS_SIZE - 1:0];
reg [`ROB_SIZE_LOG - 1:0] Qj[`RS_SIZE - 1:0];
reg [31:0] Vk[`RS_SIZE - 1:0];
reg Pk[`RS_SIZE - 1:0];
reg [`ROB_SIZE_LOG - 1:0] Qk[`RS_SIZE - 1:0];
reg [31:0] imm[`RS_SIZE - 1:0];
reg [31:0] curPC[`RS_SIZE - 1:0];
reg [31:0] reorder[`RS_SIZE - 1:0];

assign RS_full = (sz == `RS_SIZE);

reg [`RS_SIZE_LOG:0] pos;

always @(posedge clk) begin
    RS_send_ALU <= 0;
    if(rst || jump_rst) begin
        sz <= 0;
        for(i = 0;i < `RS_SIZE;i = i + 1) begin
            busy[i] <= 0;
            Pj[i] <= 0;
            Pk[i] <= 0;
        end
    end else if(!rdy) begin
    end else begin
        pos = `RS_SIZE;
        for(i = 0;i < `RS_SIZE;i = i + 1) begin
            if(!busy[i]) begin
                pos = i;
                i = `RS_SIZE; // break
            end
        end
        if(pos < `RS_SIZE) begin
            if(issue_send) begin
                busy[pos] <= 1;
                sz <= sz + 1;
                op[pos] <= issue_op;
                Vj[pos] <= issue_Vj;
                Pj[pos] <= issue_Pj;
                Qj[pos] <= issue_Qj;
                Vk[pos] <= issue_Vk;
                Pk[pos] <= issue_Pk;
                Qk[pos] <= issue_Qk;
                imm[pos] <= issue_imm;
                curPC[pos] <= issue_curPC;
                reorder[pos] <= issue_reorder;
            end
        end

        RS_send_ALU <= 0;
        for(i = 0;i < `RS_SIZE;i = i + 1) begin
            if(busy[i] && !Pj[i] && !Pk[i]) begin
                RS_send_ALU <= 1;
                ALU_Vj <= Vj[i];
                ALU_Vk <= Vk[i];
                ALU_op <= op[i];
                ALU_imm <= imm[i];
                ALU_reorder <= reorder[i];
                ALU_curPC <= curPC[i];
                busy[i] <= 0;
                sz <= sz - 1;
                i = `RS_SIZE; // break
            end
        end

        if(commit_send) begin
            for(i = 0;i < `RS_SIZE;i = i + 1) begin
                if(busy[i]) begin
                    if(Pj[i] && Qj[i] == commit_reorder) begin
                        Pj[i] <= 0;
                        Vj[i] <= commit_value;
                    end
                    if(Pk[i] && Qk[i] == commit_reorder) begin
                        Pk[i] <= 0;
                        Vk[i] <= commit_value;
                    end
                end
            end
        end
    end
end

endmodule

`endif