module register(
    input logic clk,
    input logic [4:0] ReadReg1,
    input logic [4:0] ReadReg2,
    input logic RegWrite,
    input logic [4:0] WriteReg,
    input logic [31:0] WriteData,
    output logic [31:0] ReadData1,
    output logic [31:0] ReadData2
);
    logic [31:0] data [0:31];
    assign ReadData1 = (ReadReg1 == 5'b00000) ? 32'b0 : data[ReadReg1];
    assign ReadData2 = (ReadReg2 == 5'b00000) ? 32'b0 : data[ReadReg2];
    always_ff @(posedge clk) begin
        if (RegWrite && WriteReg != 5'b00000) begin
            data[WriteReg] <= WriteData;
        end
    end
endmodule