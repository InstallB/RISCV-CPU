`include "config.v"

`ifndef SLBuffer
`define SLBuffer

// 0 is LOAD, 1 is STORE

module SLB(
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
    input wire [`ROB_SIZE_LOG - 1:0] issue_reorder,    

    input wire IF_send_mem,
    input wire mem_valid,
    input wire [1:0] mem_state,
    input wire [31:0] mem_load_val,
    output reg mem_send,
    output reg mem_type,
    output reg [31:0] mem_addr,
    output reg [31:0] mem_store_val,
    output reg [2:0] mem_size,

    input wire ROB_state,
    input wire [`ROB_SIZE_LOG - 1:0] ROB_state_reorder,
    output reg SLB_store_ROB_pop_signal,
    output reg [31:0] SLB_val,
    output reg SLB_send_ROB,
    output reg SLB_send_ROB_type,
    output reg [`ROB_SIZE_LOG - 1:0] SLB_reorder,

    input wire commit_send,
    input wire [31:0] commit_value,
    input wire [`ROB_SIZE_LOG - 1:0] commit_reorder,

    output wire SLB_full
);

integer i;

reg [`SLB_SIZE_LOG - 1:0] h,t;
reg [`SLB_SIZE_LOG:0] sz; // size
// [h,t) queue

reg busy[`SLB_SIZE - 1:0];
reg [`OP_SIZE_LOG - 1:0] op[`SLB_SIZE - 1:0];
reg [31:0] Vj[`SLB_SIZE - 1:0];
reg Pj[`SLB_SIZE - 1:0];
reg [`ROB_SIZE_LOG - 1:0] Qj[`SLB_SIZE - 1:0];
reg [31:0] Vk[`SLB_SIZE - 1:0];
reg Pk[`SLB_SIZE - 1:0];
reg [`ROB_SIZE_LOG - 1:0] Qk[`SLB_SIZE - 1:0];
reg [31:0] imm[`SLB_SIZE - 1:0];
reg [31:0] reorder[`SLB_SIZE - 1:0];
reg state[`SLB_SIZE - 1:0];

assign SLB_full = (sz >= `SLB_SIZE - 1);

reg has_load;

always @(posedge clk) begin
    if(rst || jump_rst) begin
        sz <= 0;
        h <= 0;
        t <= 0;
        mem_send <= 0;
        SLB_store_ROB_pop_signal <= 0;
        SLB_send_ROB <= 0;
        for(i = 0;i < `RS_SIZE;i = i + 1) begin
            busy[i] <= 0;
            Pj[i] <= 0;
            Pk[i] <= 0;
            op[i] <= 0;
            state[i] <= 0;
        end
    end else if(!rdy) begin
    end else begin
        if(issue_send) begin
            busy[t] <= 1;
            t <= (t + 1) & (`SLB_SIZE - 1);
            sz <= sz + 1;
            op[t] <= issue_op;
            Vj[t] <= issue_Vj;
            Pj[t] <= issue_Pj;
            Qj[t] <= issue_Qj;
            Vk[t] <= issue_Vk;
            Pk[t] <= issue_Pk;
            Qk[t] <= issue_Qk;
            if(commit_send && issue_Pj && issue_Qj == commit_reorder) begin
                Pj[t] <= 0;
                Vj[t] <= commit_value;
            end
            if(commit_send && issue_Pk && issue_Qk == commit_reorder) begin
                Pk[t] <= 0;
                Vk[t] <= commit_value;
            end
            imm[t] <= issue_imm;
            state[t] <= 0;
            reorder[t] <= issue_reorder;
        end

        if(commit_send) begin
            for(i = 0;i < `SLB_SIZE;i = i + 1) begin
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

        if(ROB_state) begin
            for(i = 0;i < `SLB_SIZE;i = i + 1) begin
                if(busy[i] && reorder[i] == ROB_state_reorder) begin
                    state[i] <= 1;
                end
            end
        end

        mem_send <= 0;
        SLB_send_ROB <= 0;
        SLB_store_ROB_pop_signal <= 0;
        if(sz > 0 && (Pj[h] == 0 && Pk[h] == 0)) begin
            if(op[h] >= `LB && op[h] <= `LHU) begin
                // load
                if(mem_state == 2'b00 && !IF_send_mem) begin
                    if(mem_valid) begin
                        // received data from memory
                        SLB_send_ROB <= 1;
                        SLB_send_ROB_type <= 0;
                        SLB_reorder <= reorder[h];
                        case(op[h])
                            `LB: SLB_val <= {{24{mem_load_val[7]}},mem_load_val[7:0]};
                            `LH: SLB_val <= {{16{mem_load_val[7]}},mem_load_val[15:0]};
                            `LW: SLB_val <= mem_load_val;
                            `LBU: SLB_val <= mem_load_val[7:0];
                            `LHU: SLB_val <= mem_load_val[15:0];
                        endcase
                        h <= (h + 1) & (`SLB_SIZE - 1);
                        sz <= sz - 1;
                        if(issue_send) sz <= sz;
                        busy[h] <= 0;
                    end else begin
                        mem_send <= 1;
                        mem_type <= 0;
                        mem_addr <= Vj[h] + imm[h];
                        case(op[h])
                            `LB: mem_size <= 1;
                            `LH: mem_size <= 2;
                            `LW: mem_size <= 4;
                            `LBU: mem_size <= 1;
                            `LHU: mem_size <= 2;
                        endcase
                    end
                end
            end else begin
                // store
                if(!state[h]) begin
                    SLB_send_ROB <= 1;
                    SLB_send_ROB_type <= 1;
                    SLB_reorder <= reorder[h];
                end else begin
                    if(mem_state == 2'b00 && !IF_send_mem) begin
                        if(mem_valid) begin
                            h <= (h + 1) & (`SLB_SIZE - 1);
                            sz <= sz - 1;
                            if(issue_send) sz <= sz;
                            SLB_store_ROB_pop_signal <= 1;
                            state[h] <= 0;
                            busy[h] <= 0;
                        end else begin
                            mem_send <= 1;
                            mem_type <= 1;
                            mem_addr <= Vj[h] + imm[h];
                            mem_store_val <= Vk[h];
                            /*
                            case(op[h])
                                `SB: mem_store_val <= Vk[h][7:0];
                                `SH: mem_store_val <= Vk[h][15:0];
                                `SW: mem_store_val <= Vk[h];
                            endcase
                            */
                            case(op[h])
                                `SB: mem_size <= 1;
                                `SH: mem_size <= 2;
                                `SW: mem_size <= 4;
                            endcase
                        end
                    end
                end
            end
        end
    end
end

endmodule

`endif