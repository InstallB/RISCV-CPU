// temporary file



// RISCV32I CPU top module
// port modification allowed for debugging purposes

module cpu(
  input  wire                 clk_in,			// system clock signal
  input  wire                 rst_in,			// reset signal
	input  wire					        rdy_in,			// ready signal, pause cpu when low

  input  wire [ 7:0]          mem_din,		// data input bus
  output wire [ 7:0]          mem_dout,		// data output bus
  output wire [31:0]          mem_a,			// address bus (only 17:0 is used)
  output wire                 mem_wr,			// write/read signal (1 for write)
	
	input  wire                 io_buffer_full, // 1 if uart buffer is full
	
	output wire [31:0]			dbgreg_dout		// cpu register output (debugging demo)
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

wire IF_send_ID;
wire [31:0] IF_ID_instruction;
wire IF_issue_pred_result;
wire [31:0] IF_issue_pc;
wire IF_send_mem;
wire [31:0] IF_mem_mem_addr;

IF _IF(
    input wire clk(clk_in),
    input wire rst(rst_in),
    input wire rdy(rdy_in),

    input wire jump_rst(jump_rst),
    input wire [31:0] jump_pc(ROB_IF_jump_pc),

    input wire RS_full(RS_full),
    input wire SLB_full(SLB_full),
    input wire ROB_full(ROB_full),

    output reg ID_send(IF_send_ID),

    output reg [31:0] instruction(IF_ID_instruction),
    output reg pred_result(IF_issue_pred_result),
    output reg [31:0] inst_pc(IF_issue_pc),

    input wire mem_valid(mem_send_IF),
    input wire [31:0] mem_val(mem_IF_mem_val),
    output reg mem_send(IF_send_mem),
    output reg [31:0] mem_addr(IF_mem_mem_addr),

    input wire pred(ROB_IF_pred),
    input wire pred_val(ROB_IF_pred_val)
);

wire ID_send_issue;
wire [5:0] ID_issue_op;
wire [4:0] ID_issue_rs1;
wire [4:0] ID_issue_rs2;
wire [4:0] ID_issue_rd;
wire [31:0] ID_issue_imm;

ID _ID(
    input wire clk(clk_in),
    input wire rst(rst_in),
    input wire rdy(rdy_in),

    input wire IF_valid(IF_send_ID),
    input wire [31:0] instruction(IF_ID_instruction),

    output reg issue_send(ID_send_issue),
    output reg [5:0] op(ID_issue_op),
    output reg [4:0] rs1(ID_issue_rs1),
    output reg [4:0] rs2(ID_issue_rs2),
    output reg [4:0] rd(ID_issue_rd),
    output reg [31:0] imm(ID_issue_imm)
);

wire issue_send_SLB;
wire issue_send_RS;
wire issue_send_ROB;
wire [31:0] issue_broadcast_Vj;
wire [31:0] issue_broadcast_Vk;
wire [`ROB_SIZE_LOG - 1:0] issue_broadcast_Qj;
wire [`ROB_SIZE_LOG - 1:0] issue_broadcast_Qk;
wire issue_broadcast_Pj;
wire issue_broadcast_Pk;
wire [`OP_SIZE_LOG - 1:0] issue_broadcast_op;
wire [4:0] issue_broadcast_reg;
wire [31:0] issue_broadcast_curPC;
wire [31:0] issue_broadcast_imm;
wire [`ROB_SIZE_LOG - 1:0] issue_broadcast_reorder;
wire issue_send_regfile;
wire [4:0] issue_regfile_reg;
wire [`ROB_SIZE_LOG - 1:0] issue_regfile_reorder;

issue _issue(
    input wire clk(clk_in),
    input wire rst(rst_in),
    input wire rdy(rdy_in),  

    input wire jump_rst(jump_rst),
    
    input wire ID_valid(ID_send_issue),
    input wire [5:0] op(ID_issue_op),
    input wire [4:0] rs1(ID_issue_rs1),
    input wire [4:0] rs2(ID_issue_rs2),
    input wire [4:0] rd(ID_issue_rd),
    input wire [31:0] imm(ID_issue_imm),
    input wire IF_pred_result(IF_issue_pred_result),
    input wire [31:0] IF_curPC(IF_issue_pc),

    input wire [31:0] issue_Vj(regfile_issue_Vj),
    input wire [`ROB_SIZE_LOG - 1:0] issue_Qj(regfile_issue_Qj),
    input wire issue_Pj(regfile_issue_Pj),
    input wire [31:0] issue_Vk(regfile_issue_Vk),
    input wire [`ROB_SIZE_LOG - 1:0] issue_Qk(regfile_issue_Qk),
    input wire issue_Pk(regfile_issue_Pk),

    input wire [`ROB_SIZE_LOG - 1:0] ROB_tail(ROB_tail),

    output wire [31:0] Vj(issue_broadcast_Vj),
    output wire [`ROB_SIZE_LOG - 1:0] Qj(issue_broadcast_Qj),
    output wire Pj(issue_broadcast_Pj),
    output wire [31:0] Vk(issue_broadcast_Vk),
    output wire [`ROB_SIZE_LOG - 1:0] Qk(issue_broadcast_Qk),
    output wire Pk(issue_broadcast_Pk),
    output wire issue_pred(issue_broadcast_pred),
    output wire [`OP_SIZE_LOG - 1:0] issue_op(issue_broadcast_op);
    output wire [4:0] issue_reg(issue_broadcast_reg),
    output wire [31:0] issue_curPC(issue_broadcast_curPC),
    output wire [31:0] issue_imm(issue_broadcast_imm),
    output wire [`ROB_SIZE_LOG - 1:0] issue_reorder(issue_broadcast_reorder),

    output reg rename_send(issue_send_regfile),
    output wire [4:0] rename_reg(issue_regfile_reg),
    output wire [`ROB_SIZE_LOG - 1:0] rename_reorder(issue_regfile_reorder),

    output reg SLB_send(issue_send_SLB),
    output reg RS_send(issue_send_RS),
    output reg ROB_send(issue_send_ROB)
);

wire [31:0] regfile_issue_Vj;
wire [31:0] regfile_issue_Vk;
wire [`ROB_SIZE_LOG - 1:0] regfile_issue_Qj;
wire [`ROB_SIZE_LOG - 1:0] regfile_issue_Qk;
wire regfile_issue_Pj;
wire regfile_issue_Pk;

Regfile _regfile(
    input wire clk(clk_in),
    input wire rst(rst_in),
    input wire rdy(rdy_in),

    input wire jump_rst(jump_rst),

    input wire [4:0] rs1(ID_issue_rs1),
    input wire [4:0] rs2(ID_issue_rs2),

    input wire commit_valid(ROB_commit_valid),
    input wire [31:0] commit_value(ROB_commit_value),
    input wire [4:0] commit_reg(ROB_commit_reg),
    input wire [`ROB_SIZE_LOG - 1:0] commit_reorder(ROB_commit_reorder),
    
    input wire issue_rename_valid(issue_send_regfile),
    input wire [4:0] issue_rename_reg(issue_regfile_reg),
    input wire [`ROB_SIZE_LOG - 1:0] issue_rename_reorder(issue_regfile_reorder),

    output wire [31:0] issue_Vj(regfile_issue_Vj),
    output wire [`ROB_SIZE_LOG - 1:0] issue_Qj(regfile_issue_Qj),
    output wire issue_Pj(regfile_issue_Pj),
    output wire [31:0] issue_Vk(regfile_issue_Vk),
    output wire [`ROB_SIZE_LOG - 1:0] issue_Qk(regfile_issue_Qk),
    output wire issue_Pk(regfile_issue_Pk)
);

wire ALU_send_ROB;
wire [31:0] ALU_ROB_value;
wire [`ROB_SIZE_LOG - 1:0] ALU_ROB_reorder;
wire [31:0] ALU_ROB_tarPC;

ALU _ALU(
    input wire clk(clk_in),
    input wire rst(rst_in),
    input wire rdy(rdy_in),

    input wire jump_rst(jump_rst),

    input wire RS_valid(RS_send_ALU),
    input wire [`OP_SIZE_LOG - 1:0] op(RS_ALU_op),
    input wire [31:0] Vj(RS_ALU_Vj),
    input wire [31:0] Vk(RS_ALU_Vk),
    input wire [31:0] imm(RS_ALU_imm),
    input wire [`ROB_SIZE_LOG - 1:0] RS_reorder(RS_ALU_reorder),
    input wire [31:0] curPC(RS_ALU_curPC),

    output reg ROB_send(ALU_send_ROB), // to ROB
    output reg [31:0] val(ALU_ROB_value),
    output reg [`ROB_SIZE_LOG - 1:0] reorder(ALU_ROB_reorder),
    output reg [31:0] targetPC(ALU_ROB_tarPC)
);

wire RS_send_ALU;
wire [`OP_SIZE_LOG - 1:0] RS_ALU_op;
wire [31:0] RS_ALU_Vj;
wire [31:0] RS_ALU_Vk;
wire [31:0] RS_ALU_imm;
wire [`ROB_SIZE_LOG - 1:0] RS_ALU_reorder;
wire [31:0] RS_ALU_curPC;

RS _RS(
    input wire clk(clk_in),
    input wire rst(rst_in),
    input wire rdy(rdy_in),

    input wire jump_rst(jump_rst),

    input wire issue_send(issue_send_RS),
    input wire [`OP_SIZE_LOG - 1:0] issue_op(issue_broadcast_op),
    input wire [31:0] issue_Vj(issue_broadcast_Vj),
    input wire issue_Pj(issue_broadcast_Pj),
    input wire [`ROB_SIZE_LOG - 1:0] issue_Qj(issue_broadcast_Qj),
    input wire [31:0] issue_Vk(issue_broadcast_Vk),
    input wire issue_Pk(issue_broadcast_Pk),
    input wire [`ROB_SIZE_LOG - 1:0] issue_Qk(issue_broadcast_Qk),
    input wire [31:0] issue_imm(issue_broadcast_imm),
    input wire [31:0] issue_curPC(issue_broadcast_curPC),
    input wire [`ROB_SIZE_LOG - 1:0] issue_reorder(issue_broadcast_reorder),

    output reg RS_send_ALU(RS_send_ALU),
    output reg [`OP_SIZE_LOG - 1:0] ALU_op(RS_ALU_op),
    output reg [31:0] ALU_Vj(RS_ALU_Vj),
    output reg [31:0] ALU_Vk(RS_ALU_Vk),
    output reg [31:0] ALU_imm(RS_ALU_imm),
    output reg [`ROB_SIZE_LOG - 1:0] ALU_reorder(RS_ALU_reorder),
    output reg [31:0] ALU_curPC(RS_ALU_curPC),

    input wire commit_send(ROB_commit_valid),
    input wire [31:0] commit_value(ROB_commit_value),
    input wire [`ROB_SIZE_LOG - 1:0] commit_reorder(ROB_commit_reorder),

    output wire RS_full(RS_full)
);

wire [`ROB_SIZE_LOG - 1:0] ROB_tail;
wire [31:0] ROB_IF_jump_pc;
wire ROB_IF_pred;
wire ROB_IF_pred_val;
wire ROB_commit_valid;
wire [31:0] ROB_commit_value;
wire [4:0] ROB_commit_reg;
wire [`ROB_SIZE_LOG - 1:0] ROB_commit_reorder;
wire ROB_SLB_state;
wire [`ROB_SIZE_LOG - 1:0] ROB_SLB_state_reorder;

ROB _ROB(
    input wire clk(clk_in),
    input wire rst(rst_in),
    input wire rdy(rdy_in),   
    
    input wire ALU_valid(ALU_send_ROB),
    input wire [31:0] ALU_val(ALU_ROB_value),
    input wire [`ROB_SIZE_LOG - 1:0] ALU_reorder(ALU_ROB_reorder),
    input wire [31:0] ALU_targetPC(ALU_ROB_tarPC),

    input wire SLB_valid(SLB_send_ROB),
    input wire SLB_send_type(SLB_ROB_send_type),
    input wire [`ROB_SIZE_LOG - 1:0] SLB_reorder(SLB_ROB_reorder),
    input wire [31:0] SLB_val(SLB_ROB_value),
    input wire SLB_store_ROB_pop_signal(SLB_ROB_pop_signal),
    output reg SLB_state(ROB_SLB_state),
    output reg [`ROB_SIZE_LOG - 1:0] SLB_state_reorder(ROB_SLB_state_reorder),

    input wire issue_valid(issue_send_ROB),
    input wire [`OP_SIZE_LOG - 1:0] issue_op(issue_broadcast_op),
    input wire [4:0] issue_reg(issue_broadcast_reg), // rd
    input wire [31:0] issue_curPC(issue_broadcast_curPC),
    input wire issue_pred(issue_broadcast_pred),

    output reg [31:0] IF_jump_pc(ROB_IF_jump_pc),
    output reg IF_pred(ROB_IF_pred),
    output reg IF_pred_result(ROB_IF_pred_val),
    
    output reg commit_send(ROB_commit_valid),
    output reg [31:0] commit_value(ROB_commit_value),
    output reg [4:0] commit_reg(ROB_commit_reg),
    output reg [`ROB_SIZE_LOG - 1:0] commit_reorder(ROB_commit_reorder),
(
    output wire ROB_full(ROB_full),
    output wire [`ROB_SIZE_LOG - 1:0] ROB_tail(ROB_tail),

    output reg jump_rst(jump_rst)
);

wire mem_send_IF;
wire [31:0] mem_IF_mem_val;
wire [1:0] mem_SLB_state;
wire mem_send_SLB;
wire [31:0] mem_SLB_load_val;

Memctrl _Memctrl(
    input wire clk(clk_in),
    input wire rst(rst_in),
    input wire rdy(rdy_in), 
    
    input wire [7:0] mem_din(mem_din),		// data input bus
    output reg [7:0] mem_dout(mem_dout),		// data output bus
    output reg [31:0] mem_a(mem_a),			// address bus (only 17:0 is used)
    output reg mem_wr(mem_wr),			// write/read signal (1 for write)

    input wire io_buffer_full(io_buffer_full),  // 1 if uart buffer is full

    input wire IF_valid(IF_send_mem),
    input wire [31:0] IF_addr(IF_mem_mem_addr),
    output reg IF_send(mem_send_IF),
    output reg [31:0] IF_inst(mem_IF_mem_val),

    input wire SLB_valid(SLB_send_mem),
    input wire SLB_type(SLB_mem_type),
    input wire [31:0] store_val(SLB_mem_store_val),
    input wire [31:0] SL_addr(SLB_mem_addr),
    input wire [2:0] SL_size(SLB_mem_size), // 1,2,4
    output reg SLB_send(mem_send_SLB),
    output reg [31:0] load_val(mem_SLB_load_val), // SLB

    output wire [1:0] mem_state(mem_SLB_state),

    input wire jump_rst(jump_rst)
);

wire SLB_send_ROB;
wire SLB_ROB_send_type;
wire [`ROB_SIZE_LOG - 1:0] SLB_ROB_reorder;
wire [31:0] SLB_ROB_value;
wire SLB_ROB_pop_signal;
wire SLB_send_mem;
wire SLB_mem_type;
wire [31:0] SLB_mem_store_val;
wire [31:0] SLB_mem_addr;
wire [2:0] SLB_mem_size;

SLB _SLB(
    input wire clk(clk_in),
    input wire rst(rst_in),
    input wire rdy(rdy_in),

    input wire jump_rst(jump_rst),

    input wire issue_send(issue_send_SLB),
    input wire [`OP_SIZE_LOG - 1:0] issue_op(issue_broadcast_op),
    input wire [31:0] issue_Vj(issue_broadcast_Vj),
    input wire issue_Pj(issue_broadcast_Pj),
    input wire [`ROB_SIZE_LOG - 1:0] issue_Qj(issue_broadcast_Qj),
    input wire [31:0] issue_Vk(issue_broadcast_Vk),
    input wire issue_Pk(issue_broadcast_Pk),
    input wire [`ROB_SIZE_LOG - 1:0] issue_Qk(issue_broadcast_Qk),
    input wire [31:0] issue_imm(issue_broadcast_imm),
    input wire [`ROB_SIZE_LOG - 1:0] issue_reorder(issue_broadcast_reorder),   

    input wire mem_valid(mem_send_SLB),
    input wire [1:0] mem_state(mem_SLB_state),
    input wire [31:0] mem_load_val(mem_SLB_load_val),
    output reg mem_send(SLB_send_mem),
    output reg mem_type(SLB_mem_type),
    output reg [31:0] mem_addr(SLB_mem_addr),
    output reg [31:0] mem_store_val(SLB_mem_store_val),
    output reg [2:0] mem_size(SLB_mem_size),

    input wire ROB_state(ROB_SLB_state),
    input wire [`ROB_SIZE_LOG - 1:0] ROB_state_reorder(ROB_SLB_state_reorder),
    output reg SLB_store_ROB_pop_signal(SLB_ROB_pop_signal),
    output reg [31:0] SLB_val(SLB_ROB_value),
    output reg SLB_send_ROB(SLB_send_ROB),
    output reg SLB_send_ROB_type(SLB_ROB_send_type),
    output reg [`ROB_SIZE_LOG - 1:0] SLB_reorder(SLB_ROB_reorder),
    
    input wire commit_send(ROB_commit_valid),
    input wire [31:0] commit_value(ROB_commit_value),
    input wire [`ROB_SIZE_LOG - 1:0] commit_reorder(ROB_commit_reorder),

    output wire SLB_full(SLB_full)
);