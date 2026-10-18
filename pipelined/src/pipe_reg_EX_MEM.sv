`timescale 1ns/1ps
module pipe_reg_EX_MEM(
    input logic clk,
    input logic rst,
    input logic flush,
    input logic branch,
    input logic MemWrite,
    input logic MemRead,
    input logic MemToReg,
    input logic isZero,
    input logic [31:0] result,
    input logic [4:0] RegDstData,
    input logic [31:0] WriteData,
    input logic [31:0] branch_address,
    input logic RegWrite,
    output logic branch_out,
    output logic MemWrite_out,
    output logic MemRead_out,
    output logic MemToReg_out,
    output logic isZero_out,
    output logic [31:0] result_out,
    output logic [4:0] RegDstData_out,
    output logic [31:0] WriteData_out,
    output logic [31:0] branch_address_out,
    output logic RegWrite_out
);
    always_ff @(posedge clk) begin
        if (rst || flush) begin
            branch_out <= '0;
            MemWrite_out <= '0;
            MemRead_out <= '0;
            MemToReg_out <= '0;
            isZero_out <= '0;
            result_out <= '0;
            RegDstData_out <= '0;
            WriteData_out <= '0;
            branch_address_out <= '0;
            RegWrite_out <= '0;
        end else begin
            branch_out <= branch;
            MemWrite_out <= MemWrite;
            MemRead_out <= MemRead;
            MemToReg_out <= MemToReg;
            isZero_out <= isZero;
            result_out <= result;
            RegDstData_out <= RegDstData;
            WriteData_out <= WriteData;
            branch_address_out <= branch_address;
            RegWrite_out <= RegWrite;
        end
    end
endmodule
