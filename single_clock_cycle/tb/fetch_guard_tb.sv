`timescale 1ns/1ps
module fetch_guard_tb;
    logic clk=0,rst=1;
    integer scenario;
    datapath_single_cycle #(.PROGRAM_FILE("")) dut(clk,rst);
    always #5 clk=~clk;
    initial begin
        if(!$value$plusargs("CASE=%d",scenario)) scenario=0;
        #1;
        dut.u_instruction_mem.rom[0]=(scenario==0) ? 32'h08000040 : 32'bx;
        repeat(2) @(negedge clk); rst=0;
        #50; $fatal(1,"GUARD_MISSING");
    end
endmodule
