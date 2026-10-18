`timescale 1ns/1ps
module pipe_reg_ID_EX(
    input logic        clk,
    input logic rst,
    input logic flush,
    input logic        branch,
    input logic        RegWrite,
    input logic        ALUSrc,
    input logic        MemWrite,
    input logic        MemRead,
    input logic        MemToReg,
    input logic [2:0]  AluOP,
    input logic        RegDst,
    input logic [31:0] pc_plus_4,
    input logic [31:0] ReadData1,
    input logic [31:0] ReadData2,
    input logic [31:0] sign_extend,
    input logic [5:0]  funct,
    input logic [4:0]  rs,
    input logic [4:0]  rt,
    input logic [4:0]  rd,
    output logic       branch_out,
    output logic       RegWrite_out,
    output logic       ALUSrc_out,
    output logic       MemWrite_out,
    output logic       MemRead_out,
    output logic       MemToReg_out,
    output logic [2:0] AluOP_out,
    output logic       RegDst_out,
    output logic [31:0] pc_plus_4_out,
    output logic [31:0] ReadData1_out,
    output logic [31:0] ReadData2_out,
    output logic [31:0] sign_extend_out,
    output logic [5:0]  funct_out,
    output logic [4:0]  rs_out,
    output logic [4:0]  rt_out,
    output logic [4:0]  rd_out
);
    always_ff @(posedge clk) begin
        if (rst || flush) begin
            branch_out <= '0;
            RegWrite_out <= '0;
            ALUSrc_out <= '0;
            MemWrite_out <= '0;
            MemRead_out <= '0;
            MemToReg_out <= '0;
            AluOP_out <= '0;
            RegDst_out <= '0;
            pc_plus_4_out <= '0;
            ReadData1_out <= '0;
            ReadData2_out <= '0;
            sign_extend_out <= '0;
            funct_out <= '0;
            rs_out <= '0;
            rt_out <= '0;
            rd_out <= '0;
        end else begin
            branch_out <= branch;
            RegWrite_out <= RegWrite;
            ALUSrc_out <= ALUSrc;
            MemWrite_out <= MemWrite;
            MemRead_out <= MemRead;
            MemToReg_out <= MemToReg;
            AluOP_out <= AluOP;
            RegDst_out <= RegDst;
            pc_plus_4_out <= pc_plus_4;
            ReadData1_out <= ReadData1;
            ReadData2_out <= ReadData2;
            sign_extend_out <= sign_extend;
            funct_out <= funct;
            rs_out <= rs;
            rt_out <= rt;
            rd_out <= rd;
        end
    end
endmodule
