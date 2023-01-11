`include "config.v"

`ifndef __issue
`define __issue

module issue(
    input wire clk,
    input wire rst,
    input wire rdy,  

    input wire jump_rst,
    
    input wire ID_valid,
    input wire [5:0] op,
    input wire [4:0] rs1,
    input wire [4:0] rs2,
    input wire [4:0] rd,
    input wire [31:0] imm,
    input wire IF_pred_result,
    input wire [31:0] IF_curPC,

    input wire [31:0] issue_Vj,
    input wire [`ROB_SIZE_LOG - 1:0] issue_Qj,
    input wire issue_Pj,
    input wire [31:0] issue_Vk,
    input wire [`ROB_SIZE_LOG - 1:0] issue_Qk,
    input wire issue_Pk,

    input wire [`ROB_SIZE_LOG - 1:0] ROB_tail,

    output wire [31:0] Vj,
    output wire [`ROB_SIZE_LOG - 1:0] Qj,
    output wire Pj,
    output wire [31:0] Vk,
    output wire [`ROB_SIZE_LOG - 1:0] Qk,
    output wire Pk,
    output wire issue_pred,
    output wire [`OP_SIZE_LOG - 1:0] issue_op,
    output wire [4:0] issue_reg,
    output wire [31:0] issue_curPC,
    output wire [31:0] issue_imm,
    output wire [`ROB_SIZE_LOG - 1:0] issue_reorder,

    output reg rename_send,
    output wire [4:0] rename_reg,
    output wire [`ROB_SIZE_LOG - 1:0] rename_reorder,

    output reg SLB_send,
    output reg RS_send,
    output reg ROB_send
);

assign Vj = issue_Vj;
assign Qj = issue_Qj;
assign Pj = issue_Pj;
assign Vk = issue_Vk;
assign Qk = issue_Qk;
assign Pk = issue_Pk;
assign issue_op = op;
assign issue_pred = IF_pred_result;
assign issue_reg = rd;
assign issue_curPC = IF_curPC;
assign issue_imm = imm;
assign issue_reorder = ROB_tail;
assign rename_reg = rd;
assign rename_reorder = ROB_tail;

always @(*) begin
    SLB_send = 0;
    RS_send = 0;
    ROB_send = 0;
    rename_send = 0;
    if(rst || jump_rst || !ID_valid) begin
    end else if(!rdy) begin
    end else begin
        ROB_send = 1;
        rename_send = 1;
        if(op >= `LB && op <= `SW) begin
            SLB_send = 1;
        end else begin
            RS_send = 1;
        end
    end
end

endmodule

// fetch data from Regfile

`endif