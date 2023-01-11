`include "config.v"

`ifndef __ALU__
`define __ALU__

module ALU(
    input wire clk,
    input wire rst,
    input wire rdy,

    input wire jump_rst,

    input wire RS_valid,
    input wire [`OP_SIZE_LOG - 1:0] op,
    input wire [31:0] Vj,
    input wire [31:0] Vk,
    input wire [31:0] imm,
    input wire [`ROB_SIZE_LOG - 1:0] RS_reorder,
    input wire [31:0] curPC,

    output reg ROB_send,
    output reg [31:0] val,
    output reg [`ROB_SIZE_LOG - 1:0] reorder,
    output reg [31:0] targetPC
);

always @(*) begin
    ROB_send = 0;
    if(!rdy) begin
    end else begin
    if(RS_valid && op != `NOP) begin
        ROB_send = 1;
        reorder = RS_reorder;
        targetPC = -1;
        case(op)
            `LUI: val = imm;
            `AUIPC: val = curPC + imm;
            `JAL: begin
                val = curPC + 4;
                targetPC = curPC + imm;
            end
            `JALR: begin
                val = curPC + 4;
                targetPC = (Vj + imm) & (~32'b1);
            end
            `BEQ:
                if(Vj == Vk) begin
                    targetPC = curPC + imm;
                    val = 1; // 1 is jump, 0 is not jump, stored in val
                end else begin
                    targetPC = curPC + 4;
                    val = 0;
                end
            `BNE:
                if(Vj != Vk) begin
                    targetPC = curPC + imm;
                    val = 1; // 1 is jump, 0 is not jump, stored in val
                end else begin
                    targetPC = curPC + 4;
                    val = 0;
                end
            `BLT:
                if($signed(Vj) < $signed(Vk)) begin
                    targetPC = curPC + imm;
                    val = 1; // 1 is jump, 0 is not jump, stored in val
                end else begin
                    targetPC = curPC + 4;
                    val = 0;
                end
            `BLTU:
                if(Vj < Vk) begin
                    targetPC = curPC + imm;
                    val = 1; // 1 is jump, 0 is not jump, stored in val
                end else begin
                    targetPC = curPC + 4;
                    val = 0;
                end
            `BGE:
                if($signed(Vj) >= $signed(Vk)) begin
                    targetPC = curPC + imm;
                    val = 1; // 1 is jump, 0 is not jump, stored in val
                end else begin
                    targetPC = curPC + 4;
                    val = 0;
                end
            `BGEU:
                if(Vj >= Vk) begin
                    targetPC = curPC + imm;
                    val = 1; // 1 is jump, 0 is not jump, stored in val
                end else begin
                    targetPC = curPC + 4;
                    val = 0;
                end
            `ADDI: val = Vj + imm;
            `SLTI: val = $signed(Vj) < $signed(imm);
            `SLTIU: val = Vj < imm;
            `XORI: val = Vj ^ imm;
            `ORI: val = Vj | imm;
            `ANDI: val = Vj & imm;
            `SLLI: val = Vj << imm[4:0];
            `SRLI: val = Vj >> imm[4:0];
            `SRAI: val = $signed(Vj) >>> imm[4:0];
            `ADD: val = Vj + Vk;
            `SUB: val = Vj - Vk;
            `SLL: val = Vj << Vk[4:0];
            `SLT: val = $signed(Vj) < $signed(Vk);
            `SLTU: val = Vj < Vk;
            `XOR: val = Vj ^ Vk;
            `SRL: val = Vj >> Vk[4:0];
            `SRA: val = $signed(Vj) >>> Vk[4:0];
            `OR: val = Vj | Vk;
            `AND: val = Vj & Vk;
        endcase
    end
    end
end

endmodule

`endif