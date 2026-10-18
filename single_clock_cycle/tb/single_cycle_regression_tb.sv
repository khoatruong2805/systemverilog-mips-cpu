`timescale 1ns/1ps
module single_cycle_regression_tb;
    logic clk=0, rst=1;
    datapath_single_cycle #(.PROGRAM_FILE("")) dut(.clk(clk),.rst(rst));
    always #5 clk=~clk;
    logic [31:0] ref_regs[0:31], ref_mem[0:63];
    integer ref_pc, tests=0, checks=0, cycles=0;
    integer seed=32'h518ace21;
    string name;
    function automatic [31:0] ri(input integer rs,rt,rd,fn);
        ri=(rs<<21)|(rt<<16)|(rd<<11)|fn;
    endfunction
    function automatic [31:0] ii(input integer op,rs,rt,imm);
        ii=(op<<26)|(rs<<21)|(rt<<16)|(imm&65535);
    endfunction
    function automatic [31:0] ji(input integer addr);
        ji=(2<<26)|addr;
    endfunction
    function automatic integer rng();
        seed=seed*1664525+1013904223;
        rng=(seed>>8)&32'h00ffffff;
    endfunction
    task automatic eq(input string label,input logic[31:0] got,want);
        checks++;
        if(got !== want) $fatal(1,"%s / %s: got=%h expected=%h cycle=%0d",name,label,got,want,cycles);
    endtask
    task automatic prepare(input string label);
        @(negedge clk); rst=1; name=label;
        for(integer i=0;i<64;i++) begin
            dut.u_instruction_mem.rom[i]=0;
            dut.u_data_mem.data[i]=0;
        end
        dut.u_instruction_mem.rom[60]=ji(60);
        repeat(2) @(negedge clk);
        ref_pc=0;
        for(integer i=0;i<32;i++) ref_regs[i]=0;
    endtask
    // One independent architectural step per CPU clock, no DUT ALU/control reuse.
    task automatic step;
        integer op,rs,rt,rd,fn,dst,addr,nextpc;
        logic [31:0] ins,imm,value;
        bit wr,store,load;
        eq("PC before instruction",dut.current_pc,ref_pc);
        ins=dut.u_instruction_mem.rom[ref_pc/4];
        op=ins[31:26]; rs=ins[25:21]; rt=ins[20:16]; rd=ins[15:11]; fn=ins[5:0];
        imm={{16{ins[15]}},ins[15:0]}; dst=rt; nextpc=ref_pc+4;
        wr=0; store=0; load=0; value=0; addr=0;
        case(op)
            0: begin
                dst=rd;
                case(fn)
                    32: begin value=ref_regs[rs]+ref_regs[rt]; wr=1; end
                    34: begin value=ref_regs[rs]-ref_regs[rt]; wr=1; end
                    36: begin value=ref_regs[rs]&ref_regs[rt]; wr=1; end
                    37: begin value=ref_regs[rs]|ref_regs[rt]; wr=1; end
                    42: begin value=($signed(ref_regs[rs])<$signed(ref_regs[rt])); wr=1; end
                    default: begin end
                endcase
            end
            8: begin value=ref_regs[rs]+imm; wr=1; end
            12: begin value=ref_regs[rs]&{16'd0,ins[15:0]}; wr=1; end
            13: begin value=ref_regs[rs]|{16'd0,ins[15:0]}; wr=1; end
            10: begin value=($signed(ref_regs[rs])<$signed(imm)); wr=1; end
            35,43: begin
                addr=ref_regs[rs]+imm;
                if(addr<0 || addr>=256 || addr%4!=0) $fatal(1,"Bad reference address");
                if(op==35) begin value=ref_mem[addr/4]; wr=1; load=1; end
                else store=1;
            end
            4: if(ref_regs[rs]==ref_regs[rt]) nextpc=ref_pc+4+($signed(imm)*4);
            2: nextpc=((ref_pc+4)&32'hf0000000)|((ins&32'h03ffffff)<<2);
            default: begin end
        endcase
        @(posedge clk);
        eq("RegWrite",dut.RegWrite,wr);
        eq("MemWrite",dut.MemWrite,store);
        eq("MemRead",dut.MemRead,load);
        if(wr && dst!=0) ref_regs[dst]=value;
        if(store) ref_mem[addr/4]=ref_regs[rt];
        ref_pc=nextpc;
        #1;
        eq("PC after one clock",dut.current_pc,ref_pc);
        for(integer i=0;i<32;i++) eq($sformatf("r%0d",i),dut.u_register.data[i],ref_regs[i]);
        for(integer i=0;i<64;i++) eq($sformatf("mem[%0d]",i),dut.u_data_mem.data[i],ref_mem[i]);
        cycles++;
        @(negedge clk);
    endtask
    task automatic run_case;
        integer count;
        for(integer i=0;i<64;i++) ref_mem[i]=dut.u_data_mem.data[i];
        rst=0; count=0;
        while(ref_pc!=240 && count<200) begin step(); count++; end
        if(count>=200) $fatal(1,"%s: program did not terminate",name);
        step(); // Terminal self-jump must also execute in one cycle.
        tests++; $display("PASS %02d %s (%0d instructions)",tests,name,count+1);
    endtask
    initial begin : suite
        integer rs,rt,rd,x,choice;
        #1;
        prepare("all R-type operations and back-to-back dependencies");
        dut.u_instruction_mem.rom[0]=ii(8,0,1,5);
        dut.u_instruction_mem.rom[1]=ii(8,0,2,10);
        dut.u_instruction_mem.rom[2]=ri(1,2,3,32);
        dut.u_instruction_mem.rom[3]=ri(3,1,4,34);
        dut.u_instruction_mem.rom[4]=ri(1,2,5,36);
        dut.u_instruction_mem.rom[5]=ri(1,2,6,37);
        dut.u_instruction_mem.rom[6]=ri(1,2,7,42); run_case();
        prepare("ANDI ORI SLTI exact formerly failing examples");
        dut.u_instruction_mem.rom[0]=ii(8,0,1,5);
        dut.u_instruction_mem.rom[1]=ii(12,1,2,3);
        dut.u_instruction_mem.rom[2]=ii(13,1,3,3);
        dut.u_instruction_mem.rom[3]=ii(10,1,4,6); run_case();
        prepare("logical zero extension and signed immediates");
        dut.u_instruction_mem.rom[0]=ii(8,0,1,-1);
        dut.u_instruction_mem.rom[1]=ii(12,1,2,32768);
        dut.u_instruction_mem.rom[2]=ii(13,0,3,32768);
        dut.u_instruction_mem.rom[3]=ii(13,0,4,65535);
        dut.u_instruction_mem.rom[4]=ii(8,0,5,-32768);
        dut.u_instruction_mem.rom[5]=ii(10,1,6,0);
        dut.u_instruction_mem.rom[6]=ii(10,0,7,-1);
        dut.u_instruction_mem.rom[7]=ri(5,3,8,42); run_case();
        prepare("load store dependencies and negative address offsets");
        dut.u_data_mem.data[0]=42;
        dut.u_instruction_mem.rom[0]=ii(35,0,1,0);
        dut.u_instruction_mem.rom[1]=ri(1,1,2,32);
        dut.u_instruction_mem.rom[2]=ii(43,0,2,4);
        dut.u_instruction_mem.rom[3]=ii(8,0,3,8);
        dut.u_instruction_mem.rom[4]=ii(35,3,4,-4);
        dut.u_instruction_mem.rom[5]=ii(43,3,4,0); run_case();
        prepare("first and last RAM word");
        dut.u_instruction_mem.rom[0]=ii(8,0,1,123);
        dut.u_instruction_mem.rom[1]=ii(43,0,1,252);
        dut.u_instruction_mem.rom[2]=ii(35,0,2,252);
        dut.u_instruction_mem.rom[3]=ii(43,0,2,0); run_case();
        prepare("writes and loads to zero register");
        dut.u_data_mem.data[0]=999;
        dut.u_instruction_mem.rom[0]=ii(8,0,0,77);
        dut.u_instruction_mem.rom[1]=ii(35,0,0,0);
        dut.u_instruction_mem.rom[2]=ri(0,0,1,32);
        dut.u_instruction_mem.rom[3]=ii(43,0,0,4); run_case();
        prepare("taken BEQ skips register and memory writes, no delay slot");
        dut.u_instruction_mem.rom[0]=ii(8,0,1,7);
        dut.u_instruction_mem.rom[1]=ii(4,1,1,2);
        dut.u_instruction_mem.rom[2]=ii(43,0,1,0);
        dut.u_instruction_mem.rom[3]=ii(8,0,2,99);
        dut.u_instruction_mem.rom[4]=ii(8,0,3,11); run_case();
        prepare("BEQ not taken and immediate load-to-branch");
        dut.u_data_mem.data[0]=5;
        dut.u_instruction_mem.rom[0]=ii(35,0,1,0);
        dut.u_instruction_mem.rom[1]=ii(4,1,0,2);
        dut.u_instruction_mem.rom[2]=ii(8,0,2,77);
        dut.u_instruction_mem.rom[3]=ii(4,1,1,2);
        dut.u_instruction_mem.rom[4]=ii(8,0,3,99); run_case();
        prepare("backward branch loop");
        dut.u_instruction_mem.rom[0]=ii(8,0,1,3);
        dut.u_instruction_mem.rom[1]=ii(8,1,1,-1);
        dut.u_instruction_mem.rom[2]=ii(4,1,0,3);
        dut.u_instruction_mem.rom[3]=ii(4,0,0,-3);
        dut.u_instruction_mem.rom[4]=ii(8,0,2,99);
        dut.u_instruction_mem.rom[6]=ji(60); run_case();
        prepare("jump skips side effects and preserves older state");
        dut.u_instruction_mem.rom[0]=ii(8,0,1,7);
        dut.u_instruction_mem.rom[1]=ji(4);
        dut.u_instruction_mem.rom[2]=ii(43,0,1,0);
        dut.u_instruction_mem.rom[3]=ii(8,0,1,99);
        dut.u_instruction_mem.rom[4]=ii(8,1,2,1); run_case();
        prepare("NOP and unsupported opcode/funct are inert");
        dut.u_instruction_mem.rom[0]=ii(8,0,1,7);
        dut.u_instruction_mem.rom[1]=ri(1,1,2,63);
        dut.u_instruction_mem.rom[2]=ii(63,1,3,1); run_case();
        prepare("32-bit wraparound and signed boundaries");
        dut.u_data_mem.data[0]=32'h7fffffff;
        dut.u_data_mem.data[1]=32'h80000000;
        dut.u_instruction_mem.rom[0]=ii(35,0,1,0);
        dut.u_instruction_mem.rom[1]=ii(8,1,2,1);
        dut.u_instruction_mem.rom[2]=ii(35,0,3,4);
        dut.u_instruction_mem.rom[3]=ri(3,1,4,42);
        dut.u_instruction_mem.rom[4]=ri(3,1,5,34); run_case();
        for(integer trial=0;trial<20;trial++) begin
            prepare($sformatf("seeded random arithmetic/memory %0d",trial));
            for(integer i=0;i<48;i++) begin
                rs=rng()%8; rt=rng()%8; rd=rng()%8; x=rng(); choice=rng()%11;
                case(choice)
                    0: dut.u_instruction_mem.rom[i]=ri(rs,rt,rd,32);
                    1: dut.u_instruction_mem.rom[i]=ri(rs,rt,rd,34);
                    2: dut.u_instruction_mem.rom[i]=ri(rs,rt,rd,36);
                    3: dut.u_instruction_mem.rom[i]=ri(rs,rt,rd,37);
                    4: dut.u_instruction_mem.rom[i]=ri(rs,rt,rd,42);
                    5: dut.u_instruction_mem.rom[i]=ii(8,rs,rd,x);
                    6: dut.u_instruction_mem.rom[i]=ii(12,rs,rd,x);
                    7: dut.u_instruction_mem.rom[i]=ii(13,rs,rd,x);
                    8: dut.u_instruction_mem.rom[i]=ii(10,rs,rd,x);
                    9: dut.u_instruction_mem.rom[i]=ii(35,0,rd,(x%16)*4);
                    10: dut.u_instruction_mem.rom[i]=ii(43,0,rt,(x%16)*4);
                endcase
            end
            run_case();
        end
        prepare("reset suppresses pending register write and clears state");
        dut.u_instruction_mem.rom[0]=ii(8,0,1,5);
        dut.u_instruction_mem.rom[1]=ii(8,1,1,1);
        rst=0; @(negedge clk); eq("pre-reset r1",dut.u_register.data[1],5);
        rst=1; repeat(3) @(negedge clk);
        eq("reset PC",dut.current_pc,0);
        for(integer i=0;i<32;i++) eq("reset register",dut.u_register.data[i],0);
        eq("reset disables control",{dut.RegWrite,dut.MemWrite,dut.MemRead},0);
        tests++; $display("PASS %02d %s",tests,name);
        prepare("reset cancels pending store and preserves RAM");
        dut.u_data_mem.data[0]=77;
        dut.u_instruction_mem.rom[0]=ii(8,0,1,42);
        dut.u_instruction_mem.rom[1]=ii(43,0,1,0);
        rst=0; @(negedge clk); eq("store pending",dut.MemWrite,1);
        rst=1; repeat(3) @(negedge clk);
        eq("RAM retained",dut.u_data_mem.data[0],77);
        tests++; $display("PASS %02d %s",tests,name);
        // Resume from reset, using the untouched register file and program.
        name="restart after reset"; ref_pc=0;
        for(integer i=0;i<32;i++) ref_regs[i]=0;
        run_case();
        $display("ALL PASS: %0d cases, %0d checks, %0d instruction cycles",tests,checks,cycles);
        $finish;
    end
    initial begin #1000000; $fatal(1,"Regression timeout"); end
endmodule
