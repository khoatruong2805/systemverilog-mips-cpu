module instruction_mem(
    input logic [31:0] instruction_address,
    output logic [31:0] instruction
);
    logic [31:0] rom [0:63];
    assign instruction = rom[instruction_address[31:2]]; // if address = 1000 => instruction = 2 => take instruction no.2
endmodule