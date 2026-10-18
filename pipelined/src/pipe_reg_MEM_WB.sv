`timescale 1ns/1ps
module pipe_reg_MEM_WB(
    input logic clk,
    input logic rst,
    input logic MemToReg,
    input logic [31:0] ReadData,
    input logic [31:0] result,
    input logic [4:0] RegDstData,
    input logic RegWrite,
    output logic MemToReg_out,
    output logic [31:0] ReadData_out,
    output logic [31:0] result_out,
    output logic [4:0] RegDstData_out,
    output logic RegWrite_out
);
    always_ff @(posedge clk) begin
        if (rst) begin
            MemToReg_out <= '0;
            ReadData_out <= '0;
            result_out <= '0;
            RegDstData_out <= '0;
            RegWrite_out <= '0;
        end else begin
            MemToReg_out <= MemToReg;
            result_out <= result;
            ReadData_out <= ReadData;
            RegDstData_out <= RegDstData;
            RegWrite_out   <= RegWrite;
        end
    end
endmodule
