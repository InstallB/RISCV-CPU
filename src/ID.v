`include "config.v"

`ifndef __IDecode
`define __IDecode

module ID(
    input wire clk,
    input wire rst,
    input wire rdy,

    input wire IF_valid,
    input wire [31:0] instruction,

    output reg issue_send,
    output reg [5:0] op,
    output reg [4:0] rs1,
    output reg [4:0] rs2,
    output reg [4:0] rd,
    output reg [31:0] imm
);

wire [6:0] opcode;
wire [2:0] funct3;
wire [6:0] funct7;

assign opcode = instruction[6:0];
assign funct3 = instruction[14:12];
assign funct7 = instruction[31:25];

always @(*) begin
    op = `NOP;
    issue_send = 0;
    
    if(!rdy) begin
    end else begin
    if(!rst && IF_valid) begin
        issue_send = 1;
        op = `NOP;
        rs1 = 0;
        rs2 = 0;
        imm = 0;
        rd = 0; 
        case(opcode)
            
            7'b0110111: begin
                op = `LUI;
                rd = instruction[11:7];
                imm = instruction[31:12] << 12;
            end
            7'b0010111: begin
                op = `AUIPC;
                rd = instruction[11:7];
                imm = instruction[31:12] << 12;
            end
            7'b1101111: begin
                op = `JAL;
                rd = instruction[11:7];
                imm = {{11{instruction[31]}},instruction[31],instruction[19:12],instruction[20],instruction[30:21],1'b0};
            end
            7'b1100111: if(funct3 == 0) begin
                op = `JALR;
                rd = instruction[11:7];
                rs1 = instruction[19:15];
                imm = {{20{instruction[31]}},instruction[31:20]};
            end
            7'b1100011: begin // Branch
                rs1 = instruction[19:15];
                rs2 = instruction[24:20];
                imm = {{19{instruction[31]}},instruction[31],instruction[7],instruction[30:25],instruction[11:8],1'b0};
                case(funct3)
                    3'b000: op = `BEQ;
                    3'b001: op = `BNE;
                    3'b100: op = `BLT;
                    3'b101: op = `BGE;
                    3'b110: op = `BLTU;
                    3'b111: op = `BGEU;
                endcase
            end
            
            7'b0000011: begin // Load
                rd = instruction[11:7];
                rs1 = instruction[19:15];
                imm = {{20{instruction[31]}},instruction[31:20]};
                case(funct3)
                    3'b000: op = `LB;
                    3'b001: op = `LH;
                    3'b010: op = `LW;
                    3'b100: op = `LBU;
                    3'b101: op = `LHU;
                endcase
            end
            7'b0100011: begin // Store
                rs1 = instruction[19:15];
                rs2 = instruction[24:20];
                imm = {{20{instruction[31]}},instruction[31:25],instruction[11:7]};
                case(funct3)
                    3'b000: op = `SB;
                    3'b001: op = `SH;
                    3'b010: op = `SW;
                endcase
            end
            7'b0010011: begin // Calc_I
                rd = instruction[11:7];
                rs1 = instruction[19:15];
                imm = {{20{instruction[31]}},instruction[31:20]};
                case(funct3)
                    3'b000: op = `ADDI;
                    3'b010: op = `SLTI;
                    3'b011: begin
                        imm = instruction[31:20];
                        op = `SLTIU;
                    end
                    3'b100: op = `XORI;
                    3'b110: op = `ORI;
                    3'b111: op = `ANDI;
                    3'b001: if(funct7 == 7'b0000000) begin
                        imm = instruction[25:20];
                        op = `SLLI;
                    end
                    3'b101: if(funct7 == 7'b0000000) begin
                        op = `SRLI;
                        imm = instruction[25:20];
                    end else if(funct7 == 7'b0100000) begin
                        op = `SRAI;
                        imm = instruction[25:20];
                    end
                endcase
            end
            7'b0110011: begin // Calc
                rd = instruction[11:7];
                rs1 = instruction[19:15];
                rs2 = instruction[24:20];
                case(funct3)
                    3'b000: begin
                        case(funct7)
                            7'b0000000: op = `ADD;
                            7'b0100000: op = `SUB;
                        endcase
                    end
                    3'b001: if(funct7 == 7'b0000000) begin
                        op = `SLL;
                    end
                    3'b010: if(funct7 == 7'b0000000) begin
                        op = `SLT;
                    end
                    3'b011: if(funct7 == 7'b0000000) begin
                        op = `SLTU;
                    end
                    3'b100: if(funct7 == 7'b0000000) begin
                        op = `XOR;
                    end
                    3'b101: begin
                        case(funct7)
                            7'b0000000: op = `SRL;
                            7'b0100000: op = `SRA;
                        endcase
                    end
                    3'b110: if(funct7 == 7'b0000000) begin
                        op = `OR;
                    end
                    3'b111: if(funct7 == 7'b0000000) begin
                        op = `AND;
                    end
                endcase
            end
        endcase
    end
    end
end

endmodule

`endif