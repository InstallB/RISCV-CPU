`include "config.v"

`ifndef MEMCtrl
`define MEMCtrl

`define IDLE 2'b00
`define IF 2'b01
`define LOAD 2'b10
`define STORE 2'b11

module Memctrl(
    input wire clk,
    input wire rst,
    input wire rdy, 

    input wire jump_rst,
    
    input wire [7:0] mem_din,		// data input bus
    output reg [7:0] mem_dout,		// data output bus
    output reg [31:0] mem_a,			// address bus (only 17:0 is used)
    output reg mem_wr,			// write/read signal (1 for write)

    input wire io_buffer_full,  // 1 if uart buffer is full

    input wire IF_valid,
    input wire [31:0] IF_addr,
    output reg IF_send,
    output reg [31:0] IF_inst,

    input wire SLB_valid,
    input wire SLB_type,
    input wire [31:0] store_val,
    input wire [31:0] SL_addr,
    input wire [2:0] SL_size, // 1,2,4
    output reg SLB_send,
    output reg [31:0] load_val, // SLB

    output wire [1:0] mem_state
);

reg [1:0] state;
reg [2:0] pos;

assign mem_state = state;

always @(posedge clk) begin
    if(rst || jump_rst) begin
        state <= `IDLE;
        pos <= 0;
        mem_wr <= 0;
        mem_a <= 0;
        IF_send <= 0;
        SLB_send <= 0;
    end else if(!rdy) begin
    end else begin
        IF_send <= 0;
        SLB_send <= 0;
        if(state == `IDLE) begin
            mem_a <= 0;
            if(SLB_valid) begin
                pos <= 0;
                if(SLB_type == 1) begin
                    // store
                    state <= `STORE;
                end else begin
                    // load
                    state <= `LOAD;
                    mem_a <= SL_addr;
                    mem_wr <= 0;
                end
            end else if(IF_valid) begin
                state <= `IF;
                mem_a <= IF_addr;
                mem_wr <= 0;
                pos <= 0;
            end
        end
        if(state == `IF) begin
            case(pos)
                1: IF_inst[7:0] <= mem_din;
                2: IF_inst[15:8] <= mem_din;
                3: IF_inst[23:16] <= mem_din;
                4: IF_inst[31:24] <= mem_din;
            endcase
            if(pos == 4) begin
                IF_send <= 1;
                // state <= `IDLE;
                mem_a <= 0;
                pos <= 0;
            end else begin
                pos <= pos + 1;
                mem_a <= mem_a + 1;
            end
            if(!IF_valid) begin
                state <= `IDLE;
            end
        end
        if(state == `LOAD) begin
            case(pos)
                1: load_val[7:0] <= mem_din;
                2: load_val[15:8] <= mem_din;
                3: load_val[23:16] <= mem_din;
                4: load_val[31:24] <= mem_din;
            endcase
            if(pos == SL_size) begin
                SLB_send <= 1;
                state <= `IDLE;
                mem_a <= 0;
                pos <= 0;
            end else begin
                pos <= pos + 1;
                mem_a <= mem_a + 1;
            end
        end
        if(state == `STORE && !io_buffer_full) begin
            mem_wr <= 1;
            case(pos)
                0: mem_dout <= store_val[7:0];
                1: mem_dout <= store_val[15:8];
                2: mem_dout <= store_val[23:16];
                3: mem_dout <= store_val[31:24];
            endcase
            if(pos == SL_size) begin
                SLB_send <= 1;
                state <= `IDLE;
                mem_wr <= 0;
                mem_a <= 0;
                pos <= 0;
            end else begin
                pos <= pos + 1;
                mem_a <= mem_a + 1;
                if(pos == 0) mem_a <= SL_addr;
            end
        end
    end
end

endmodule

`endif