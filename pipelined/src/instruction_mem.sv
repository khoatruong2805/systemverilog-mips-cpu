`timescale 1ns/1ps
module instruction_mem #(parameter PROGRAM_FILE = "program.txt")(
    input logic [31:0] instruction_address,
    output logic [31:0] instruction
);
    logic [31:0] rom [0:63];
    initial begin
        for (int i = 0; i < 64; i++) rom[i] = 32'd0;
        if (PROGRAM_FILE != "") $readmemh(PROGRAM_FILE, rom);
    end
    // Invalid fetches remain visible as X; never alias an out-of-range address.
    assign instruction = (instruction_address < 256 && instruction_address[1:0] == 0)
        ? rom[instruction_address[31:2]] : 32'bx;
endmodule
