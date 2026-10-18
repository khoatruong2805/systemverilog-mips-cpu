`timescale 1ns/1ps
module pipe_reg_IF_ID(
    input logic clk,
    input logic rst,
    input logic flush,
    input logic write,
    input logic [31:0] pc_plus_4,
    input logic [31:0] instruction,
    output logic [31:0] instruction_out,
    output logic [31:0] pc_plus_4_out
);
    always_ff @(posedge clk) begin
        if (rst || flush) begin
            instruction_out <= '0;
            pc_plus_4_out <= '0;
        end else begin
            if (write) begin
                pc_plus_4_out <= pc_plus_4;
                instruction_out <= instruction;
            end
        end
    end
endmodule
