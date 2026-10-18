`timescale 1ns/1ps
// These cases must fail with the explicit memory-address diagnostic.
module memory_guard_tb;
    logic clk=0;
    logic [31:0] address, value;
    logic rd, wr;
    integer scenario;
    data_mem dut(.clk(clk), .MemRead(rd), .MemWrite(wr),
                 .address(address), .WriteData(32'd1), .ReadData(value));
    always #5 clk=~clk;
    initial begin
        if (!$value$plusargs("CASE=%d",scenario)) scenario=0;
        rd=(scenario<2); wr=!rd;
        case(scenario)
            0: address=2;
            1: address=256;
            2: address=3;
            3: address=32'hfffffffc;
            default: address=32'bx;
        endcase
        #20;
        $fatal(1,"GUARD_MISSING");
    end
endmodule
