`timescale 1ns/1ps
module program_counter(
    input  logic        clk,
    input  logic        rst,
    input  logic        write,
    input  logic [31:0] next_pc,
    output logic [31:0] pc_out
);

    always_ff @(posedge clk) begin
        if (rst) 
            pc_out <= 32'b0;
        else if (write)
            pc_out <= next_pc;
    end
endmodule