module datapath_single_cycle(
    input logic clk,
    input logic rst
);
    logic [31:0] current_pc;
    logic [31:0] instruction;
    logic RegDst;
    logic Branch;
    logic MemToReg;
    logic MemWrite;
    logic MemRead;
    logic [1:0] ALUOp;
    logic ALUSrc;
    logic RegWrite;
    logic jump;
    logic [31:0] ReadData1;
    logic [31:0] ReadData2;
    logic [3:0] alu_operation;
    logic [31:0] sign_extend;
    logic is_zero;
    logic [31:0] alu_result;
    logic [31:0] ReadData;
    logic [31:0] pc_plus_4;
    logic [31:0] shift_signed_extend;
    logic [31:0] if_branch;
    logic [31:0] next_pc_branch;
    logic [31:0] next_pc;
    assign sign_extend = {{16{instruction[15]}},instruction[15:0]};
    instruction_mem u_instruction_mem(
        .instruction_address(current_pc),
        .instruction(instruction)
    );
    main_control u_main_control(
        .control(instruction[31:26]),
        .branch(Branch),
        .RegWrite(RegWrite),
        .ALUSrc(ALUSrc),
        .MemWrite(MemWrite),
        .MemRead(MemRead),
        .MemToReg(MemToReg),
        .Jump(jump),
        .AluOP(ALUOp),
        .RegDst(RegDst)
    );
    register u_register(
        .clk(clk),
        .ReadReg1(instruction[25:21]),
        .ReadReg2(instruction[20:16]),
        .RegWrite(RegWrite),
        .WriteReg(RegDst ? instruction[15:11] : instruction[20:16]),
        .WriteData(MemToReg ? ReadData : alu_result),
        .ReadData1(ReadData1),
        .ReadData2(ReadData2)
    );
    
    alu_control u_alu_control(
        .alu_op(ALUOp),
        .funct(instruction[5:0]),
        .alu_operation(alu_operation)
    );
    alu u_alu(
        .inA(ReadData1),
        .inB(ALUSrc ? sign_extend : ReadData2),
        .alu_control(alu_operation),
        .is_zero(is_zero),
        .result(alu_result)
    );
    data_mem u_data_mem(
        .clk(clk),
        .MemWrite(MemWrite),
        .MemRead(MemRead),
        .address(alu_result),
        .WriteData(ReadData2),
        .ReadData(ReadData)
    );
    assign pc_plus_4 = current_pc + 3'b100;
    assign shift_signed_extend = {sign_extend[29:0], 2'b00};
    assign if_branch = pc_plus_4 + shift_signed_extend;
    branch u_branch(
        .branch(Branch),
        .is_zero(is_zero),
        .not_branch(pc_plus_4),
        .is_branch(if_branch),
        .next_pc(next_pc_branch)
    );
    jump u_jump(
        .not_jump(next_pc_branch),
        .jump(jump),
        .is_jump(instruction[25:0]),
        .next_pc(next_pc)
    );
    program_counter u_program_counter(
        .clk(clk),
        .rst(rst),
        .next_pc(next_pc),
        .pc_out(current_pc)
    );
endmodule