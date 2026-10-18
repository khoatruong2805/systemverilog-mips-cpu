`timescale 1ns/1ps
module five_stage_pipelined_tb;
    logic clk = 0, rst = 1;
    five_stage_pipelined dut(.clk(clk), .rst(rst));
    always #5 clk = ~clk;
    initial begin
        if ($test$plusargs("VCD")) begin
            $dumpfile("cpu_pipeline_sim.vcd");
            $dumpvars(0, five_stage_pipelined_tb);
        end
        repeat (2) @(negedge clk);
        rst = 0;
        repeat (40) @(negedge clk);
        if (dut.regfile.data[3] !== 15 || dut.regfile.data[4] !== 15 ||
            dut.regfile.data[5] !== 20 || dut.DataMemory.data[0] !== 15)
            $fatal(1, "Demo program failed");
        $display("PASS demo: r3=15 r4=15 r5=20 memory[0]=15");
        $finish;
    end
    initial begin #10000; $fatal(1, "Simulation timeout"); end
endmodule
