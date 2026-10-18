`timescale 1ns/1ps
module register(
    input logic clk, rst,
    input logic [4:0] ReadReg1, ReadReg2,
    input logic RegWrite,
    input logic [4:0] WriteReg,
    input logic [31:0] WriteData,
    output logic [31:0] ReadData1, ReadData2
);
    logic [31:0] data [0:31];
    // Write-through bypass: ID sees the value retiring at this clock edge.
    assign ReadData1 = (ReadReg1 == 0) ? 32'd0 :
        (RegWrite && WriteReg != 0 && WriteReg == ReadReg1) ? WriteData : data[ReadReg1];
    assign ReadData2 = (ReadReg2 == 0) ? 32'd0 :
        (RegWrite && WriteReg != 0 && WriteReg == ReadReg2) ? WriteData : data[ReadReg2];
    always_ff @(posedge clk) begin
        if (rst) begin
            for (int i = 0; i < 32; i++) data[i] <= 32'd0;
        end else if (RegWrite && WriteReg != 0) begin
            data[WriteReg] <= WriteData;
        end
    end
endmodule
