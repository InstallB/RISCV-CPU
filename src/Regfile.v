`include "config.v"

`ifndef REGFILE
`define REGFILE

module Regfile(
    input wire clk,
    input wire rst,
    input wire rdy,

    input wire jump_rst,

    input wire [4:0] rs1,
    input wire [4:0] rs2,

    input wire commit_valid,
    input wire [31:0] commit_value,
    input wire [4:0] commit_reg,
    input wire [`ROB_SIZE_LOG - 1:0] commit_reorder,
    
    input wire issue_rename_valid,
    input wire [4:0] issue_rename_reg,
    input wire [`ROB_SIZE_LOG - 1:0] issue_rename_reorder,

    output wire [31:0] issue_Vj,
    output wire [`ROB_SIZE_LOG - 1:0] issue_Qj,
    output wire issue_Pj, // whether Qj is valid
    output wire [31:0] issue_Vk,
    output wire [`ROB_SIZE_LOG - 1:0] issue_Qk,
    output wire issue_Pk // whether Qk is valid
    // to issue
);

// use extra 'vis' array to tell whether 'reorder' is null, reorder is 0-31
// vis,Pj,Pk = 1 means has reorder
// meaning of Pj,Pk is same as above
// 32 registers

reg [31:0] val [31:0];
reg [`ROB_SIZE_LOG - 1:0] reorder [31:0];
reg vis [31:0]; // whether register is reordered
integer i;

assign issue_Pj = vis[rs1] && !(commit_valid && commit_reg == rs1 && commit_reorder == reorder[rs1]);
assign issue_Vj = (vis[rs1] && commit_valid && commit_reg == rs1 && commit_reorder == reorder[rs1]) ? commit_value : val[rs1];
assign issue_Qj = reorder[rs1];
assign issue_Pk = vis[rs2] && !(commit_valid && commit_reg == rs1 && commit_reorder == reorder[rs2]);
assign issue_Vk = (vis[rs2] && commit_valid && commit_reg == rs1 && commit_reorder == reorder[rs2]) ? commit_value : val[rs2];
assign issue_Qk = reorder[rs2];

// integer fd;
// initial begin
//     fd = $fopen("test.out", "w+"); 
// end

always @(posedge clk) begin
    if(rst) begin
        for(i = 0;i < 32;i = i + 1) begin
            val[i] <= 0;
            reorder[i] <= 0;
            vis[i] <= 0;
        end
    end else if(!rdy) begin
    end else begin
        // for(i = 0;i < 32;i = i + 1) begin
        //     $fwrite(fd,"%d-%h",i,val[i]);
        // end
        // $fdisplay(fd,"");

        if(commit_valid) begin
            if(commit_reg != 0) begin
                val[commit_reg] <= commit_value;
                if(vis[commit_reg] && commit_reorder == reorder[commit_reg]) begin
                    reorder[commit_reg] <= 0;
                    vis[commit_reg] <= 0;
                    // committed, clear reorder
                end
            end
            // reg 0 can't be modified
        end
        if(jump_rst) begin
            for(i = 0;i < 32;i = i + 1) begin
                reorder[i] <= 0;
                vis[i] <= 0;
            end
        end else begin
            if(issue_rename_valid && issue_rename_reg != 0) begin
                reorder[issue_rename_reg] <= issue_rename_reorder;
                vis[issue_rename_reg] <= 1;
            end
        end
    end
end

endmodule

`endif