`include "config.v"
`include "ALU.v"
`include "ID.v"
`include "IF.v"
`include "issue.v"
`include "Memctrl.v"
`include "Regfile.v"
`include "ROB.v"
`include "RS.v"
`include "SLB.v"

`ifndef __CPU__
`define __CPU__
// RISCV32I CPU top module
// port modification allowed for debugging purposes

module cpu(
  input  wire                 clk_in,			// system clock signal
  input  wire                 rst_in,			// reset signal
	input  wire					        rdy_in,			// ready signal, pause cpu when low

  input  wire [ 7:0]          mem_din,		// data input bus
  output  wire [ 7:0]          mem_dout,		// data output bus
  output  wire [31:0]          mem_a,			// address bus (only 17:0 is used)
  output  wire                 mem_wr,			// write/read signal (1 for write)
	
	input  wire                 io_buffer_full, // 1 if uart buffer is full
	
	output  wire [31:0]			dbgreg_dout		// cpu register output (debugging demo)
);

// implementation goes here

// Specifications:
// - Pause cpu(freeze pc, registers, etc.) when rdy_in is low
// - Memory read result will be returned in the next cycle. Write takes 1 cycle(no need to wait)
// - Memory is of size 128KB, with valid address ranging from 0x0 to 0x20000
// - I/O port is mapped to address higher than 0x30000 (mem_a[17:16]==2'b11)
// - 0x30000 read: read a byte from input
// - 0x30000 write: write a byte to output (write 0x00 is ignored)
// - 0x30004 read: read clocks passed since cpu starts (in dword, 4 bytes)
// - 0x30004 write: indicates program stop (will output '\0' through uart tx)

wire jump_rst;
wire RS_full;
wire SLB_full;
wire ROB_full;

wire        IF_send_ID;
wire [31:0] IF_ID_instruction;
wire        IF_issue_pred_result;
wire [31:0] IF_issue_pc;
wire        IF_send_mem;
wire [31:0] IF_mem_mem_addr;

wire        ID_send_issue;
wire [5:0]  ID_issue_op;
wire [4:0]  ID_issue_rs1;
wire [4:0]  ID_issue_rs2;
wire [4:0]  ID_issue_rd;
wire [31:0] ID_issue_imm;

wire                       issue_send_SLB;
wire                       issue_send_RS;
wire                       issue_send_ROB;
wire [31:0]                issue_broadcast_Vj;
wire [31:0]                issue_broadcast_Vk;
wire [`ROB_SIZE_LOG - 1:0] issue_broadcast_Qj;
wire [`ROB_SIZE_LOG - 1:0] issue_broadcast_Qk;
wire                       issue_broadcast_Pj;
wire                       issue_broadcast_Pk;
wire [`OP_SIZE_LOG - 1:0]  issue_broadcast_op;
wire [4:0]                 issue_broadcast_reg;
wire [31:0]                issue_broadcast_curPC;
wire [31:0]                issue_broadcast_imm;
wire [`ROB_SIZE_LOG - 1:0] issue_broadcast_reorder;
wire                       issue_send_regfile;
wire [4:0]                 issue_regfile_reg;
wire [`ROB_SIZE_LOG - 1:0] issue_regfile_reorder;

wire [31:0]                regfile_issue_Vj;
wire [31:0]                regfile_issue_Vk;
wire [`ROB_SIZE_LOG - 1:0] regfile_issue_Qj;
wire [`ROB_SIZE_LOG - 1:0] regfile_issue_Qk;
wire                       regfile_issue_Pj;
wire                       regfile_issue_Pk;

wire                       ALU_send_ROB;
wire [31:0]                ALU_ROB_value;
wire [`ROB_SIZE_LOG - 1:0] ALU_ROB_reorder;
wire [31:0]                ALU_ROB_tarPC;

wire                       RS_send_ALU;
wire [`OP_SIZE_LOG - 1:0]  RS_ALU_op;
wire [31:0]                RS_ALU_Vj;
wire [31:0]                RS_ALU_Vk;
wire [31:0]                RS_ALU_imm;
wire [`ROB_SIZE_LOG - 1:0] RS_ALU_reorder;
wire [31:0]                RS_ALU_curPC;

wire [`ROB_SIZE_LOG - 1:0] ROB_tail;
wire [31:0]                ROB_IF_jump_pc;
wire                       ROB_IF_pred;
wire                       ROB_IF_pred_val;
wire                       ROB_commit_valid;
wire [31:0]                ROB_commit_value;
wire [4:0]                 ROB_commit_reg;
wire [`ROB_SIZE_LOG - 1:0] ROB_commit_reorder;
wire                       ROB_SLB_state;
wire [`ROB_SIZE_LOG - 1:0] ROB_SLB_state_reorder;

wire        mem_send_IF;
wire [31:0] mem_IF_mem_val;
wire [1:0]  mem_SLB_state;
wire        mem_send_SLB;
wire [31:0] mem_SLB_load_val;

wire                       SLB_send_ROB;
wire                       SLB_ROB_send_type;
wire [`ROB_SIZE_LOG - 1:0] SLB_ROB_reorder;
wire [31:0]                SLB_ROB_value;
wire                       SLB_ROB_pop_signal;
wire                       SLB_send_mem;
wire                       SLB_mem_type;
wire [31:0]                SLB_mem_store_val;
wire [31:0]                SLB_mem_addr;
wire [2:0]                 SLB_mem_size;

IF _IF(
    .clk  (clk_in),
    .rst  (rst_in),
    .rdy  (rdy_in),

    .jump_rst (jump_rst),
    .jump_pc  (ROB_IF_jump_pc),

    .RS_full  (RS_full),
    .SLB_full (SLB_full),
    .ROB_full (ROB_full),

    .ID_send  (IF_send_ID),

    .instruction  (IF_ID_instruction),
    .pred_result  (IF_issue_pred_result),
    .inst_pc      (IF_issue_pc),

    .mem_valid  (mem_send_IF),
    .mem_val    (mem_IF_mem_val),
    .mem_send   (IF_send_mem),
    .mem_addr   (IF_mem_mem_addr),

    .pred     (ROB_IF_pred),
    .pred_val (ROB_IF_pred_val)
);

ID _ID(
    .clk  (clk_in),
    .rst  (rst_in),
    .rdy  (rdy_in),

    .IF_valid     (IF_send_ID),
    .instruction  (IF_ID_instruction),

    .issue_send (ID_send_issue),
    .op         (ID_issue_op),
    .rs1        (ID_issue_rs1),
    .rs2        (ID_issue_rs2),
    .rd         (ID_issue_rd),
    .imm        (ID_issue_imm)
);

issue _issue(
    .clk  (clk_in),
    .rst  (rst_in),
    .rdy  (rdy_in),  

    .jump_rst (jump_rst),
    
    .ID_valid       (ID_send_issue),
    .op             (ID_issue_op),
    .rs1            (ID_issue_rs1),
    .rs2            (ID_issue_rs2),
    .rd             (ID_issue_rd),
    .imm            (ID_issue_imm),
    .IF_pred_result (IF_issue_pred_result),
    .IF_curPC       (IF_issue_pc),

    .issue_Vj (regfile_issue_Vj),
    .issue_Qj (regfile_issue_Qj),
    .issue_Pj (regfile_issue_Pj),
    .issue_Vk (regfile_issue_Vk),
    .issue_Qk (regfile_issue_Qk),
    .issue_Pk (regfile_issue_Pk),

    .ROB_tail (ROB_tail),

    .Vj             (issue_broadcast_Vj),
    .Qj             (issue_broadcast_Qj),
    .Pj             (issue_broadcast_Pj),
    .Vk             (issue_broadcast_Vk),
    .Qk             (issue_broadcast_Qk),
    .Pk             (issue_broadcast_Pk),
    .issue_pred     (issue_broadcast_pred),
    .issue_op       (issue_broadcast_op),
    .issue_reg      (issue_broadcast_reg),
    .issue_curPC    (issue_broadcast_curPC),
    .issue_imm      (issue_broadcast_imm),
    .issue_reorder  (issue_broadcast_reorder),

    .rename_send    (issue_send_regfile),
    .rename_reg     (issue_regfile_reg),
    .rename_reorder (issue_regfile_reorder),

    .SLB_send (issue_send_SLB),
    .RS_send  (issue_send_RS),
    .ROB_send (issue_send_ROB)
);

Regfile _regfile(
    .clk  (clk_in),
    .rst  (rst_in),
    .rdy  (rdy_in),

    .jump_rst (jump_rst),

    .rs1  (ID_issue_rs1),
    .rs2  (ID_issue_rs2),

    .commit_valid   (ROB_commit_valid),
    .commit_value   (ROB_commit_value),
    .commit_reg     (ROB_commit_reg),
    .commit_reorder (ROB_commit_reorder),
    
    .issue_rename_valid   (issue_send_regfile),
    .issue_rename_reg     (issue_regfile_reg),
    .issue_rename_reorder (issue_regfile_reorder),

    .issue_Vj (regfile_issue_Vj),
    .issue_Qj (regfile_issue_Qj),
    .issue_Pj (regfile_issue_Pj),
    .issue_Vk (regfile_issue_Vk),
    .issue_Qk (regfile_issue_Qk),
    .issue_Pk (regfile_issue_Pk)
);

ALU _ALU(
    .clk  (clk_in),
    .rst  (rst_in),
    .rdy  (rdy_in),

    .jump_rst (jump_rst),

    .RS_valid   (RS_send_ALU),
    .op         (RS_ALU_op),
    .Vj         (RS_ALU_Vj),
    .Vk         (RS_ALU_Vk),
    .imm        (RS_ALU_imm),
    .RS_reorder (RS_ALU_reorder),
    .curPC      (RS_ALU_curPC),

    .ROB_send (ALU_send_ROB), // to ROB
    .val      (ALU_ROB_value),
    .reorder  (ALU_ROB_reorder),
    .targetPC (ALU_ROB_tarPC)
);

RS _RS(
    .clk  (clk_in),
    .rst  (rst_in),
    .rdy  (rdy_in),

    .jump_rst (jump_rst),

    .issue_send     (issue_send_RS),
    .issue_op       (issue_broadcast_op),
    .issue_Vj       (issue_broadcast_Vj),
    .issue_Pj       (issue_broadcast_Pj),
    .issue_Qj       (issue_broadcast_Qj),
    .issue_Vk       (issue_broadcast_Vk),
    .issue_Pk       (issue_broadcast_Pk),
    .issue_Qk       (issue_broadcast_Qk),
    .issue_imm      (issue_broadcast_imm),
    .issue_curPC    (issue_broadcast_curPC),
    .issue_reorder  (issue_broadcast_reorder),

    .RS_send_ALU  (RS_send_ALU),
    .ALU_op       (RS_ALU_op),
    .ALU_Vj       (RS_ALU_Vj),
    .ALU_Vk       (RS_ALU_Vk),
    .ALU_imm      (RS_ALU_imm),
    .ALU_reorder  (RS_ALU_reorder),
    .ALU_curPC    (RS_ALU_curPC),

    .commit_send    (ROB_commit_valid),
    .commit_value   (ROB_commit_value),
    .commit_reorder (ROB_commit_reorder),

    .RS_full  (RS_full)
);

ROB _ROB(
    .clk  (clk_in),
    .rst  (rst_in),
    .rdy  (rdy_in),  
    
    .ALU_valid    (ALU_send_ROB),
    .ALU_val      (ALU_ROB_value),
    .ALU_reorder  (ALU_ROB_reorder),
    .ALU_targetPC (ALU_ROB_tarPC),

    .SLB_valid                (SLB_send_ROB),
    .SLB_send_type            (SLB_ROB_send_type),
    .SLB_reorder              (SLB_ROB_reorder),
    .SLB_val                  (SLB_ROB_value),
    .SLB_store_ROB_pop_signal (SLB_ROB_pop_signal),
    .SLB_state                (ROB_SLB_state),
    .SLB_state_reorder        (ROB_SLB_state_reorder),

    .issue_valid  (issue_send_ROB),
    .issue_op     (issue_broadcast_op),
    .issue_reg    (issue_broadcast_reg), // rd
    .issue_curPC  (issue_broadcast_curPC),
    .issue_pred   (issue_broadcast_pred),

    .IF_jump_pc     (ROB_IF_jump_pc),
    .IF_pred        (ROB_IF_pred),
    .IF_pred_result (ROB_IF_pred_val),
    
    .commit_send    (ROB_commit_valid),
    .commit_value   (ROB_commit_value),
    .commit_reg     (ROB_commit_reg),
    .commit_reorder (ROB_commit_reorder),

    .ROB_full (ROB_full),
    .ROB_tail (ROB_tail),

    .jump_rst (jump_rst)
);

Memctrl _Memctrl(
    .clk  (clk_in),
    .rst  (rst_in),
    .rdy  (rdy_in),

    .jump_rst (jump_rst),
    
    .mem_din  (mem_din),		// data input bus
    .mem_dout (mem_dout),		// data output bus
    .mem_a    (mem_a),			// address bus (only 17:0 is used)
    .mem_wr   (mem_wr),			// write/read signal (1 for write)

    .io_buffer_full (io_buffer_full),  // 1 if uart buffer is full

    .IF_valid (IF_send_mem),
    .IF_addr  (IF_mem_mem_addr),
    .IF_send  (mem_send_IF),
    .IF_inst  (mem_IF_mem_val),

    .SLB_valid  (SLB_send_mem),
    .SLB_type   (SLB_mem_type),
    .store_val  (SLB_mem_store_val),
    .SL_addr    (SLB_mem_addr),
    .SL_size    (SLB_mem_size), // 1,2,4
    .SLB_send   (mem_send_SLB),
    .load_val   (mem_SLB_load_val), // SLB

    .mem_state  (mem_SLB_state)
);

SLB _SLB(
    .clk  (clk_in),
    .rst  (rst_in),
    .rdy  (rdy_in),

    .jump_rst (jump_rst),

    .issue_send     (issue_send_SLB),
    .issue_op       (issue_broadcast_op),
    .issue_Vj       (issue_broadcast_Vj),
    .issue_Pj       (issue_broadcast_Pj),
    .issue_Qj       (issue_broadcast_Qj),
    .issue_Vk       (issue_broadcast_Vk),
    .issue_Pk       (issue_broadcast_Pk),
    .issue_Qk       (issue_broadcast_Qk),
    .issue_imm      (issue_broadcast_imm),
    .issue_reorder  (issue_broadcast_reorder),     

    .mem_valid      (mem_send_SLB),
    .mem_state      (mem_SLB_state),
    .mem_load_val   (mem_SLB_load_val),
    .mem_send       (SLB_send_mem),
    .mem_type       (SLB_mem_type),
    .mem_addr       (SLB_mem_addr),
    .mem_store_val  (SLB_mem_store_val),
    .mem_size       (SLB_mem_size),

    .ROB_state                (ROB_SLB_state),
    .ROB_state_reorder        (ROB_SLB_state_reorder),
    .SLB_store_ROB_pop_signal (SLB_ROB_pop_signal),
    .SLB_val                  (SLB_ROB_value),
    .SLB_send_ROB             (SLB_send_ROB),
    .SLB_send_ROB_type        (SLB_ROB_send_type),
    .SLB_reorder              (SLB_ROB_reorder),

    .commit_send(ROB_commit_valid),
    .commit_value(ROB_commit_value),
    .commit_reorder(ROB_commit_reorder),

    .SLB_full (SLB_full)
);

endmodule

`endif