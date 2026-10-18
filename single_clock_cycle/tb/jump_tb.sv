`timescale 1ns/1ps
module jump_tb;
    logic [31:0] fallback, pc4, target;
    logic [25:0] index;
    logic enable;
    jump dut(.not_jump(fallback),.pc_plus_4(pc4),.jump(enable),.is_jump(index),.next_pc(target));
    initial begin
        fallback=32'hdeadbeef; pc4=32'h10000000; index=26'd3; enable=1;
        #1; if(target !== 32'h1000000c) $fatal(1,"Jump high bits incorrect");
        pc4=32'hf0000000; index=26'h3ffffff;
        #1; if(target !== 32'hfffffffc) $fatal(1,"Jump index incorrect");
        enable=0; #1;
        if(target !== fallback) $fatal(1,"Jump disabled selection incorrect");
        $display("PASS jump unit: PC+4 upper bits, index shift, disabled mux"); $finish;
    end
endmodule
