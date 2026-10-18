`timescale 1ns/1ps
module datapath_single_cycle_tb;
    logic clk=0, rst=1;
    datapath_single_cycle u_cpu(.clk(clk), .rst(rst));
    always #5 clk=~clk;
    task automatic check(input string name,input logic[31:0] got,want);
        if(got !== want) $fatal(1,"%s: got %h expected %h",name,got,want);
    endtask
    initial begin
        if($test$plusargs("VCD")) begin
            $dumpfile("waveform.vcd"); $dumpvars(0,datapath_single_cycle_tb);
        end
        repeat(2) @(negedge clk); rst=0;
        repeat(4) @(negedge clk);
        check("addi r8",u_cpu.u_register.data[8],15);
        check("addi r9",u_cpu.u_register.data[9],5);
        check("sub",u_cpu.u_register.data[10],10);
        check("slt",u_cpu.u_register.data[11],0);
        repeat(2) @(negedge clk);
        check("sw",u_cpu.u_data_mem.data[1],15);
        check("lw",u_cpu.u_register.data[11],15);
        @(negedge clk); check("taken beq",u_cpu.current_pc,36);
        @(negedge clk); check("jump",u_cpu.current_pc,0);
        check("skipped r12",u_cpu.u_register.data[12],0);
        check("skipped r13",u_cpu.u_register.data[13],0);
        $display("PASS demo: 10 checks on original machine-code program"); $finish;
    end
    initial begin #10000; $fatal(1,"Demo timeout"); end
endmodule
