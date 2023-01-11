`include "config.v"

`ifndef ReorderBuffer
`define ReorderBuffer

module ROB(
    input wire clk,
    input wire rst,
    input wire rdy,   
    
    input wire ALU_valid,
    input wire [31:0] ALU_val,
    input wire [`ROB_SIZE_LOG - 1:0] ALU_reorder,
    input wire [31:0] ALU_targetPC,

    input wire SLB_valid,
    input wire SLB_send_type,
    input wire [`ROB_SIZE_LOG - 1:0] SLB_reorder,
    input wire [31:0] SLB_val,
    input wire SLB_store_ROB_pop_signal,
    output reg SLB_state,
    output reg [`ROB_SIZE_LOG - 1:0] SLB_state_reorder,

    input wire issue_valid,
    input wire [`OP_SIZE_LOG - 1:0] issue_op,
    input wire [4:0] issue_reg, // rd
    input wire [31:0] issue_curPC,
    input wire issue_pred,

    output reg [31:0] IF_jump_pc,
    output reg IF_pred,
    output reg IF_pred_result,
    
    output reg commit_send,
    output reg [31:0] commit_value,
    output reg [4:0] commit_reg,
    output reg [`ROB_SIZE_LOG - 1:0] commit_reorder,

    output wire ROB_full,
    output wire [`ROB_SIZE_LOG - 1:0] ROB_tail,

    output reg jump_rst
);

reg [`ROB_SIZE_LOG - 1:0] h,t;
reg [`ROB_SIZE_LOG:0] sz; // size
// [h,t) queue

reg busy[`ROB_SIZE - 1:0];
reg ready[`ROB_SIZE - 1:0];
reg [4:0] dest[`ROB_SIZE - 1:0]; // register size 32
reg [31:0] val[`ROB_SIZE - 1:0];
reg [`OP_SIZE_LOG - 1:0] op[`ROB_SIZE - 1:0];
reg [31:0] curPC[`ROB_SIZE - 1:0];
reg [31:0] tarPC[`ROB_SIZE - 1:0];
reg pred[`ROB_SIZE - 1:0];

assign ROB_full = (sz == `ROB_SIZE);
assign ROB_tail = t;

integer i;

always @(posedge clk) begin
    if(rst || jump_rst) begin
        h <= 0;
        t <= 0;
        sz <= 0;
        jump_rst <= 0;
        for(i = 0;i < `ROB_SIZE;i = i + 1) begin
            ready[i] <= 0;
            busy[i] <= 0;
        end
    end else if(!rdy) begin
    end else begin
        if(SLB_valid) begin
            if(SLB_send_type == 0) begin
                ready[SLB_reorder] <= 1;
                val[SLB_reorder] <= SLB_val;
                // load
            end else begin
                ready[SLB_reorder] <= 1;
                // store
            end
        end
        if(issue_valid) begin
            // ROB is not full
            ready[t] <= 0;
            op[t] <= issue_op;
            dest[t] <= issue_reg;
            curPC[t] <= issue_curPC;
            pred[t] <= issue_pred;
            t <= (t + 1) & (`ROB_SIZE - 1);
            sz <= sz + 1;
            busy[t] <= 1;
        end
        if(ALU_valid) begin
            ready[ALU_reorder] <= 1;
            val[ALU_reorder] <= ALU_val;
            tarPC[ALU_reorder] <= ALU_targetPC;
        end

        IF_pred <= 0;
        jump_rst <= 0;
        SLB_state <= 0;
        commit_send <= 0;
        if(sz > 0 && ready[h] == 1) begin
            if((op[h] >= `ADDI && op[h] <= `AND) || (op[h] >= `LB && op[h] <= `LHU) || (op[h] >= `LUI && op[h] <= `JALR)) begin
                if(op[h] == `JAL || op[h] == `JALR) begin
                    jump_rst <= 1;
                    IF_jump_pc <= tarPC[h];
                    // jump
                end
                commit_send <= 1;
                commit_value <= val[h];
                commit_reg <= dest[h];
                commit_reorder <= h;
            end // calc
            if(op[h] >= `BEQ && op[h] <= `BGEU) begin
                IF_pred <= 1;
                IF_pred_result <= val[h];
                if(val[h] != pred[h]) begin
                    jump_rst <= 1;
                    IF_jump_pc <= tarPC[h];
                end
            end // branch
            if(op[h] >= `SB && op[h] <= `SW) begin
                SLB_state <= 1;
                SLB_state_reorder <= h;
            end // store, state command
            if(!(op[h] >= `SB && op[h] <= `SW) || SLB_store_ROB_pop_signal) begin
                h <= (h + 1) & (`ROB_SIZE - 1);
                sz <= sz - 1;
                ready[h] <= 0;
                busy[h] <= 0;
            end
        end // commit
    end
end

endmodule

`endif