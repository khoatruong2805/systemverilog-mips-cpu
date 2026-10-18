`timescale 1ns/1ps
module pipeline_regression_tb;
    logic clk=0, rst=1;
    five_stage_pipelined #(.PROGRAM_FILE("")) dut(.clk(clk), .rst(rst));
    always #5 clk=~clk;
    logic [31:0] regs_ref[0:31], mem_ref[0:63];
    logic [31:0] event_value[0:1023];
    integer event_kind[0:1023], event_dest[0:1023];
    integer event_count, event_seen, stalls, tests=0, assertions=0;
    integer branch_stall_hits=0, branch_jump_hits=0;
    integer seed=32'h12345678;
    bit checking=0;
    string test_name;

    function automatic [31:0] ri(input integer rs, rt, rd, fn);
        ri=(rs<<21)|(rt<<16)|(rd<<11)|fn;
    endfunction
    function automatic [31:0] ii(input integer op, rs, rt, imm);
        ii=(op<<26)|(rs<<21)|(rt<<16)|(imm & 65535);
    endfunction
    function automatic [31:0] ji(input integer word_address);
        ji=(2<<26)|word_address;
    endfunction
    // Deterministic LCG, independent of simulator random implementations.
    function automatic integer rand_next();
        seed=seed*1664525+1013904223;
        rand_next=(seed >> 1)&32'h7fffffff;
    endfunction
    task automatic eq(input string label, input logic [31:0] actual, expected);
        assertions++;
        if (actual !== expected)
            $fatal(1, "%s / %s: got %h expected %h", test_name,label,actual,expected);
    endtask
    task automatic expect_event(input integer kind, dest, input logic [31:0] value);
        if(event_count>=1024) $fatal(1,"Reference event overflow");
        event_kind[event_count]=kind;
        event_dest[event_count]=dest;
        event_value[event_count]=value;
        event_count++;
    endtask
    task automatic commit(input integer kind, dest, input logic [31:0] value);
        if(event_seen>=event_count) $fatal(1,"%s: unexpected architectural write",test_name);
        eq("commit kind",kind,event_kind[event_seen]);
        eq("commit destination",dest,event_dest[event_seen]);
        eq("commit value",value,event_value[event_seen]);
        event_seen++;
    endtask
    // Sequential ISA oracle. No pipeline control or forwarding signals are used.
    task automatic reference_run;
        integer pc, nextpc, steps, op, rs, rt, rd, fn, dst, addr;
        logic [31:0] ins, imm, value;
        bit wr;
        pc=0; steps=0; event_count=0;
        for(integer i=0;i<32;i++) regs_ref[i]=0;
        for(integer i=0;i<64;i++) mem_ref[i]=dut.DataMemory.data[i];
        while(pc!=240 && steps<1000) begin
            if(pc<0 || pc>=256 || pc%4!=0) $fatal(1,"Invalid reference PC");
            ins=dut.im.rom[pc/4]; op=ins[31:26]; rs=ins[25:21];
            rt=ins[20:16]; rd=ins[15:11]; fn=ins[5:0];
            imm={{16{ins[15]}},ins[15:0]};
            nextpc=pc+4; wr=0; dst=rt; value=0;
            case(op)
                0: begin
                    dst=rd;
                    case(fn)
                        32: begin value=regs_ref[rs]+regs_ref[rt]; wr=1; end
                        34: begin value=regs_ref[rs]-regs_ref[rt]; wr=1; end
                        36: begin value=regs_ref[rs]&regs_ref[rt]; wr=1; end
                        37: begin value=regs_ref[rs]|regs_ref[rt]; wr=1; end
                        42: begin value=($signed(regs_ref[rs])<$signed(regs_ref[rt])); wr=1; end
                        default: begin end
                    endcase
                end
                8: begin value=regs_ref[rs]+imm; wr=1; end
                12: begin value=regs_ref[rs]&{16'd0,ins[15:0]}; wr=1; end
                13: begin value=regs_ref[rs]|{16'd0,ins[15:0]}; wr=1; end
                10: begin value=($signed(regs_ref[rs])<$signed(imm)); wr=1; end
                35,43: begin
                    addr=regs_ref[rs]+imm;
                    if(addr<0 || addr>=256 || addr%4!=0) $fatal(1,"Invalid reference data address");
                    if(op==35) begin value=mem_ref[addr/4]; wr=1; end
                    else begin
                        mem_ref[addr/4]=regs_ref[rt];
                        expect_event(1,addr,regs_ref[rt]);
                    end
                end
                4: if(regs_ref[rs]==regs_ref[rt]) nextpc=pc+4+($signed(imm)*4);
                2: nextpc=((pc+4)&32'hf0000000)|((ins & 32'h03ffffff)<<2);
                default: begin end
            endcase
            if(wr && dst!=0) begin regs_ref[dst]=value; expect_event(0,dst,value); end
            pc=nextpc; steps++;
        end
        if(steps>=1000) $fatal(1,"Reference did not reach terminal loop");
    endtask
    task automatic prepare(input string name);
        @(negedge clk);
        checking=0; rst=1; test_name=name;
        for(integer i=0;i<64;i++) begin dut.im.rom[i]=0; dut.DataMemory.data[i]=0; end
        dut.im.rom[60]=ji(60);
        repeat(2) @(negedge clk);
        event_seen=0; stalls=0;
    endtask
    task automatic run_case(input integer expected_stalls);
        reference_run();
        checking=1; rst=0;
        repeat(180) @(negedge clk);
        eq("all expected writes retired",event_seen,event_count);
        for(integer i=0;i<32;i++) eq($sformatf("r%0d",i),dut.regfile.data[i],regs_ref[i]);
        for(integer i=0;i<64;i++) eq($sformatf("mem[%0d]",i),dut.DataMemory.data[i],mem_ref[i]);
        if(expected_stalls>=0) eq("load-use stalls",stalls,expected_stalls);
        tests++;
        $display("PASS %02d %s (writes=%0d stalls=%0d)",tests,test_name,event_seen,stalls);
        checking=0;
    endtask

    // Sample commits before NBA; inspect next-cycle pipeline state after NBA.
    always @(posedge clk) begin : monitor
        logic [31:0] old_pc, old_ins, target;
        bit branch_now, jump_now, stall_now;
        if(checking && !rst) begin
            if ((^{dut.pc_out,dut.MEM_WB_RegWrite,dut.EX_MEM_MemWrite,dut.LU_hazard,dut.PCSrc,dut.Jump}) === 1'bx)
                $fatal(1,"%s: unknown control state PC=%h WB=%b MW=%b LU=%b BR=%b J=%b",test_name,dut.pc_out,dut.MEM_WB_RegWrite,dut.EX_MEM_MemWrite,dut.LU_hazard,dut.PCSrc,dut.Jump);
            if(dut.MEM_WB_RegWrite && dut.MEM_WB_rd!=0)
                commit(0,dut.MEM_WB_rd,dut.MEM_WB_Data);
            if(dut.EX_MEM_MemWrite)
                commit(1,dut.EX_MEM_result,dut.EX_MEM_forward_B_data);
            old_pc=dut.pc_out; old_ins=dut.instruction_out;
            branch_now=dut.PCSrc; jump_now=dut.Jump; stall_now=dut.LU_hazard;
            target=branch_now ? dut.EX_MEM_branch_address : dut.jump_target;
            if(stall_now) stalls++;
            if(branch_now && stall_now) branch_stall_hits++;
            if(branch_now && jump_now) branch_jump_hits++;
            #1;
            if(branch_now || jump_now) begin
                eq("redirect PC",dut.pc_out,target);
                eq("flush IF/ID",dut.instruction_out,0);
                eq("flush ID/EX controls",{dut.ID_EX_RegWrite,dut.ID_EX_MemWrite,dut.ID_EX_MemRead,dut.ID_EX_branch},0);
                if(branch_now)
                    eq("flush EX/MEM controls",{dut.EX_MEM_RegWrite,dut.EX_MEM_MemWrite,dut.EX_MEM_MemRead,dut.EX_MEM_branch},0);
            end else if(stall_now) begin
                eq("stall holds PC",dut.pc_out,old_pc);
                eq("stall holds IF/ID",dut.instruction_out,old_ins);
                eq("stall inserts bubble",{dut.ID_EX_RegWrite,dut.ID_EX_MemWrite,dut.ID_EX_MemRead,dut.ID_EX_branch},0);
            end
        end
    end

    initial begin : suite
        integer x, rs, rt, rd, choice;
        #1;
        prepare("EX forwarding, both operands and store data");
        dut.im.rom[0]=ii(8,0,1,5); dut.im.rom[1]=ii(8,0,2,10);
        dut.im.rom[2]=ri(1,2,3,32); dut.im.rom[3]=ri(3,3,4,32);
        dut.im.rom[4]=ii(43,0,4,0); run_case(0);

        prepare("MEM/WB forwarding, both operands");
        dut.im.rom[0]=ii(8,0,1,7); dut.im.rom[2]=ri(1,1,2,32); run_case(0);
        prepare("WB to ID bypass, both operands");
        dut.im.rom[0]=ii(8,0,1,7); dut.im.rom[3]=ri(1,1,2,32); run_case(0);
        prepare("newest forwarding producer wins");
        dut.im.rom[0]=ii(8,0,1,7); dut.im.rom[1]=ii(8,1,1,9);
        dut.im.rom[2]=ri(1,1,2,32); run_case(0);
        prepare("load-use on both operands");
        dut.DataMemory.data[0]=42;
        dut.im.rom[0]=ii(35,0,3,0); dut.im.rom[1]=ri(3,3,4,32); run_case(1);
        prepare("load to store data");
        dut.DataMemory.data[0]=42;
        dut.im.rom[0]=ii(35,0,3,0); dut.im.rom[1]=ii(43,0,3,4); run_case(1);
        prepare("load to address and negative offset");
        dut.DataMemory.data[0]=8; dut.DataMemory.data[1]=123;
        dut.im.rom[0]=ii(35,0,3,0); dut.im.rom[1]=ii(35,3,4,-4);
        dut.im.rom[2]=ii(43,3,4,0); run_case(2);
        prepare("no false hazard on immediate destination");
        dut.im.rom[0]=ii(35,0,3,0); dut.im.rom[1]=ii(8,0,3,7); run_case(0);
        prepare("zero register and load to zero");
        dut.DataMemory.data[0]=999;
        dut.im.rom[0]=ii(8,0,0,99); dut.im.rom[1]=ii(35,0,0,0);
        dut.im.rom[2]=ri(0,0,1,32); run_case(0);
        prepare("taken branch kills EX store, ID and IF writes");
        dut.im.rom[0]=ii(8,0,1,10); dut.im.rom[1]=ii(4,1,1,3);
        dut.im.rom[2]=ii(43,0,1,0); dut.im.rom[3]=ii(8,0,2,99);
        dut.im.rom[4]=ii(8,0,3,99); dut.im.rom[5]=ii(8,0,4,7); run_case(0);
        prepare("not-taken branch with forwarded operands");
        dut.im.rom[0]=ii(8,0,1,10); dut.im.rom[1]=ii(4,1,0,2);
        dut.im.rom[2]=ii(8,0,2,99); run_case(0);
        prepare("load to taken branch");
        dut.DataMemory.data[0]=0;
        dut.im.rom[0]=ii(35,0,1,0); dut.im.rom[1]=ii(4,1,0,3);
        dut.im.rom[2]=ii(8,0,2,99); dut.im.rom[3]=ii(43,0,1,4);
        dut.im.rom[5]=ii(8,0,3,7); run_case(1);
        prepare("branch overrides wrong-path load-use stall");
        dut.im.rom[0]=ii(4,0,0,4); dut.im.rom[1]=ii(35,0,3,0);
        dut.im.rom[2]=ri(3,3,4,32); dut.im.rom[3]=ii(8,0,5,99);
        dut.im.rom[5]=ii(8,0,6,7); run_case(1);
        prepare("jump has no delay slot");
        dut.im.rom[0]=ji(4); dut.im.rom[1]=ii(43,0,0,0);
        dut.im.rom[2]=ii(8,0,2,99); dut.im.rom[4]=ii(8,0,3,7); run_case(0);
        prepare("older branch overrides younger jump");
        dut.im.rom[0]=ii(4,0,0,4); dut.im.rom[2]=ji(10);
        dut.im.rom[5]=ii(8,0,3,7); dut.im.rom[6]=ji(60);
        dut.im.rom[10]=ii(8,0,3,99); run_case(0);
        prepare("immediates, signed comparisons and all R operations");
        dut.im.rom[0]=ii(8,0,1,-1); dut.im.rom[1]=ii(12,1,2,32768);
        dut.im.rom[2]=ii(13,0,3,32768); dut.im.rom[3]=ii(10,1,4,0);
        dut.im.rom[4]=ii(10,0,5,-1); dut.im.rom[5]=ri(1,0,6,42);
        dut.im.rom[6]=ri(3,2,7,34); dut.im.rom[7]=ri(1,2,8,36);
        dut.im.rom[8]=ri(2,4,9,37); run_case(0);
        prepare("backward branch loop and jump");
        dut.im.rom[0]=ii(8,0,1,3); dut.im.rom[1]=ii(8,1,1,-1);
        dut.im.rom[2]=ii(4,1,0,3); dut.im.rom[3]=ii(4,0,0,-3);
        dut.im.rom[4]=ii(8,0,2,99); dut.im.rom[6]=ji(60); run_case(0);
        prepare("NOP and unsupported instructions have no side effects");
        dut.im.rom[0]=ii(35,0,3,0); dut.im.rom[1]=ri(3,3,5,63);
        dut.im.rom[2]=ii(63,3,3,1); run_case(0);
        prepare("last data word remains addressable");
        dut.im.rom[0]=ii(8,0,1,123); dut.im.rom[1]=ii(43,0,1,252);
        dut.im.rom[2]=ii(35,0,2,252); run_case(0);

        // Randomized legal straight-line streams with frequent dependencies.
        for(integer trial=0;trial<20;trial++) begin
            prepare($sformatf("deterministic random stream %0d",trial));
            for(integer i=0;i<48;i++) begin
                rs=rand_next()%8; rt=rand_next()%8; rd=1+rand_next()%7;
                choice=rand_next()%10; x=rand_next();
                case(choice)
                    0: dut.im.rom[i]=ri(rs,rt,rd,32);
                    1: dut.im.rom[i]=ri(rs,rt,rd,34);
                    2: dut.im.rom[i]=ri(rs,rt,rd,36);
                    3: dut.im.rom[i]=ri(rs,rt,rd,37);
                    4: dut.im.rom[i]=ri(rs,rt,rd,42);
                    5: dut.im.rom[i]=ii(8,rs,rd,x);
                    6: dut.im.rom[i]=ii(12,rs,rd,x);
                    7: dut.im.rom[i]=ii(13,rs,rd,x);
                    8: dut.im.rom[i]=ii(35,0,rd,(x%16)*4);
                    9: dut.im.rom[i]=ii(43,0,rt,(x%16)*4);
                endcase
            end
            run_case(-1);
        end

        // Assert reset with an actual store in MEM and register write in WB.
        prepare("reset mid-flight cancels pending writes");
        dut.im.rom[0]=ii(8,0,1,9); dut.im.rom[1]=ii(43,0,1,0);
        dut.im.rom[2]=ii(8,0,2,8); rst=0;
        repeat(4) @(negedge clk);
        eq("pending store before reset",dut.EX_MEM_MemWrite,1);
        eq("pending WB before reset",dut.MEM_WB_RegWrite,1);
        rst=1;
        repeat(3) @(negedge clk);
        eq("reset PC",dut.pc_out,0);
        eq("reset prevents store",dut.DataMemory.data[0],0);
        for(integer i=0;i<32;i++) eq("reset clears register",dut.regfile.data[i],0);
        eq("reset pipeline controls",{dut.ID_EX_RegWrite,dut.EX_MEM_MemWrite,dut.MEM_WB_RegWrite},0);
        tests++; $display("PASS %02d %s",tests,test_name);
        // Restart with a fresh program without clearing the datapath from the TB.
        for(integer i=0;i<64;i++) dut.im.rom[i]=0;
        dut.im.rom[0]=ii(8,0,1,77); dut.im.rom[60]=ji(60);
        event_seen=0; stalls=0; test_name="restart after mid-flight reset"; run_case(0);
        if(branch_stall_hits<1 || branch_jump_hits<1) $fatal(1,"Priority collision coverage missing");
        $display("ALL PASS: %0d cases, %0d checks; branch/stall=%0d branch/jump=%0d",tests,assertions,branch_stall_hits,branch_jump_hits);
        $finish;
    end
    initial begin #1000000; $fatal(1,"Regression timeout"); end
endmodule
