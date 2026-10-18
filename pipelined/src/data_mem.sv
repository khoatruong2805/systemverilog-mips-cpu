`timescale 1ns/1ps
module data_mem(
    input logic        clk,
    input logic        MemWrite,
    input logic        MemRead,
    input logic [31:0] address,
    input logic [31:0] WriteData,
    output logic [31:0] ReadData
);
    logic [31:0] data [0:63];
    assign ReadData = MemRead ? data[address[31:2]] : 32'b0;
    // synthesis translate_off
    always @(posedge clk) begin
        if (MemRead || MemWrite) begin
            if ($isunknown(address) || address >= 256 || address[1:0] != 0)
                $fatal(1, "Invalid data-memory address: %h", address);
        end
    end
    // synthesis translate_on
    always_ff @(posedge clk) begin
        if (MemWrite) begin
            data[address[31:2]] <= WriteData;
        end
    end

endmodule