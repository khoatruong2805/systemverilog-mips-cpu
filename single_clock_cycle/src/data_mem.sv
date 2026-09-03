module data_mem(
    input logic clk,
    input logic MemWrite,
    input logic MemRead,
    input logic [31:0] address,
    input logic [31:0] WriteData,
    output logic [31:0] ReadData
);
    logic [31:0] data [0:63];
    assign ReadData = MemRead ? data[address[31:2]] : 32'b0;
    always_ff @(posedge clk) begin
        if (MemWrite) begin
            data[address[31:2]] <= WriteData;
        end
    end
endmodule