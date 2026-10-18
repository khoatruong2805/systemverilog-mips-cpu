`timescale 1ns/1ps
module five_stage_pipelined #(parameter PROGRAM_FILE = "program.txt")(
    input logic clk,
    input logic rst
);
    logic [31:0] pc_out;
    logic        write;
    logic [31:0] next_pc;
    logic pc_write, flush_if_id, flush_id_ex, flush_ex_mem;
    logic [31:0] jump_target;
    logic [31:0] instruction;
    logic [31:0] instruction_out;
    logic [31:0] pc_plus_4;
    logic [31:0] IF_ID_pc_plus_4;
    logic [31:0] ID_EX_pc_plus_4;
    logic [5:0]  opcode;
    logic        LU_hazard;
    logic [4:0]  IF_ID_rs;
    logic [4:0]  IF_ID_rt;
    logic [4:0]  IF_ID_rd;
    logic [4:0]  ID_EX_rs;
    logic [4:0]  ID_EX_rt;
    logic [4:0]  ID_EX_rd;
    logic [4:0]  EX_MEM_rd;
    logic [31:0] IF_ID_sign_extend;
    logic [31:0] ID_EX_sign_extend;
    logic        ID_EX_MemRead;
    logic        IF_ID_MemRead;
    logic        EX_MEM_MemRead;
    logic [2:0]  IF_ID_AluOP;
    logic [2:0]  ID_EX_AluOP;
    logic        IF_ID_ALUSrc;
    logic        ID_EX_ALUSrc;
    logic        IF_ID_branch;
    logic        ID_EX_branch;
    logic        EX_MEM_branch;
    logic        Jump;
    logic        IF_ID_MemToReg;
    logic        ID_EX_MemToReg;
    logic        EX_MEM_MemToReg;
    logic        MEM_WB_MemToReg;
    logic        IF_ID_MemWrite;
    logic        ID_EX_MemWrite;
    logic        EX_MEM_MemWrite;
    logic        IF_ID_RegDst;
    logic        ID_EX_RegDst;
    logic        IF_ID_RegWrite;
    logic        ID_EX_RegWrite;
    logic        EX_MEM_RegWrite;
    logic        MEM_WB_RegWrite;
    logic [31:0] IF_ID_ReadData1;
    logic [31:0] ID_EX_ReadData1;
    logic [31:0] IF_ID_ReadData2;
    logic [31:0] ID_EX_ReadData2;
    logic [4:0]  MEM_WB_rd;
    logic [31:0] MEM_WB_Data;
    logic [5:0]  IF_ID_funct;
    logic [5:0]  ID_EX_funct;
    logic [31:0] sign_extend_sl2;
    logic [31:0] ID_EX_branch_address;
    logic [31:0] EX_MEM_branch_address;
    logic [3:0]  ALUOperator;
    logic [1:0]  forward_A;
    logic [1:0]  forward_B;
    logic [31:0] ID_EX_forward_B_data;
    logic [31:0] EX_MEM_forward_B_data;
    logic [31:0] alu_oprd1;
    logic [31:0] alu_oprd2;
    logic [31:0] ID_EX_result;
    logic [31:0] EX_MEM_result;
    logic [31:0] MEM_WB_result;
    logic        ID_EX_is_zero;
    logic        EX_MEM_is_zero;
    logic [4:0]  RegDstData;
    logic        PCSrc;
    logic [31:0] EX_MEM_MemToRegData;
    logic [31:0] MEM_WB_MemToRegData;
    program_counter pc(
        .clk(clk),
        .next_pc(next_pc),
        .pc_out(pc_out),
        .rst(rst),
        .write(pc_write)
    );
    assign pc_plus_4 = pc_out + 32'd4;

    instruction_mem #(.PROGRAM_FILE(PROGRAM_FILE)) im(
        .instruction_address(pc_out),
        .instruction(instruction)
    );
    pipe_reg_IF_ID if_id(
        .rst(rst),
        .flush(flush_if_id),
        .clk(clk),
        .instruction(instruction),
        .instruction_out(instruction_out),
        .pc_plus_4(pc_plus_4),
        .pc_plus_4_out(IF_ID_pc_plus_4),
        .write(write)
    );
    assign IF_ID_rs = instruction_out[25:21];
    assign IF_ID_rt = instruction_out[20:16];
    assign IF_ID_rd = instruction_out[15:11];
    assign IF_ID_sign_extend = ((opcode == 6'h0c) || (opcode == 6'h0d))
        ? {16'b0, instruction_out[15:0]}
        : {{16{instruction_out[15]}}, instruction_out[15:0]};
    assign opcode = instruction_out[31:26];
    assign IF_ID_funct = instruction_out[5:0];
    hazard_detection hd(
        .IF_ID_opcode(opcode),
        .IF_ID_funct(IF_ID_funct),
        .ID_EX_Mem_Read(ID_EX_MemRead),
        .ID_EX_rt(ID_EX_rt),
        .IF_ID_rs(IF_ID_rs),
        .IF_ID_rt(IF_ID_rt),
        .LU_hazard(LU_hazard),
        .write(write)
    );
    main_control mc(
        .funct(IF_ID_funct),
        .AluOP(IF_ID_AluOP),
        .ALUSrc(IF_ID_ALUSrc),
        .branch(IF_ID_branch),
        .control(opcode),
        .Jump(Jump),
        .LU_hazard(LU_hazard),
        .MemRead(IF_ID_MemRead),
        .MemToReg(IF_ID_MemToReg),
        .MemWrite(IF_ID_MemWrite),
        .RegDst(IF_ID_RegDst),
        .RegWrite(IF_ID_RegWrite)
    );
    register regfile (
        .rst(rst),
        .clk(clk),
        .ReadData1(IF_ID_ReadData1),
        .ReadData2(IF_ID_ReadData2),
        .ReadReg1(IF_ID_rs),
        .ReadReg2(IF_ID_rt),
        .RegWrite(MEM_WB_RegWrite && !rst),
        .WriteData(MEM_WB_Data),
        .WriteReg(MEM_WB_rd)
    );
    pipe_reg_ID_EX id_ex(
        .rst(rst),
        .flush(flush_id_ex),
        .clk(clk),
        .AluOP(IF_ID_AluOP),
        .AluOP_out(ID_EX_AluOP),
        .ALUSrc(IF_ID_ALUSrc),
        .ALUSrc_out(ID_EX_ALUSrc),
        .branch(IF_ID_branch),
        .branch_out(ID_EX_branch),
        .funct(IF_ID_funct),
        .funct_out(ID_EX_funct),
        .MemRead(IF_ID_MemRead),
        .MemRead_out(ID_EX_MemRead),
        .MemToReg(IF_ID_MemToReg),
        .MemToReg_out(ID_EX_MemToReg),
        .MemWrite(IF_ID_MemWrite),
        .MemWrite_out(ID_EX_MemWrite),
        .pc_plus_4(IF_ID_pc_plus_4),
        .pc_plus_4_out(ID_EX_pc_plus_4),
        .rd(IF_ID_rd),
        .rd_out(ID_EX_rd),
        .rs(IF_ID_rs),
        .rs_out(ID_EX_rs),
        .rt(IF_ID_rt),
        .rt_out(ID_EX_rt),
        .ReadData1(IF_ID_ReadData1),
        .ReadData1_out(ID_EX_ReadData1),
        .ReadData2(IF_ID_ReadData2),
        .ReadData2_out(ID_EX_ReadData2),
        .RegDst(IF_ID_RegDst),
        .RegDst_out(ID_EX_RegDst),
        .RegWrite(IF_ID_RegWrite),
        .RegWrite_out(ID_EX_RegWrite),
        .sign_extend(IF_ID_sign_extend),
        .sign_extend_out(ID_EX_sign_extend)
    );
    assign sign_extend_sl2 = {ID_EX_sign_extend[29:0], 2'b00};
    assign ID_EX_branch_address = sign_extend_sl2 + ID_EX_pc_plus_4;
    alu_control ALUControl(
        .alu_op(ID_EX_AluOP),
        .funct(ID_EX_funct),
        .alu_operation(ALUOperator)
    );
    forwarding_unit forward(
        .EX_MEM_rd(EX_MEM_rd),
        .EX_MEM_RegWrite(EX_MEM_RegWrite),
        .forward_A(forward_A),
        .forward_B(forward_B),
        .ID_EX_rs(ID_EX_rs),
        .ID_EX_rt(ID_EX_rt),
        .MEM_WB_rd(MEM_WB_rd),
        .MEM_WB_RegWrite(MEM_WB_RegWrite)
    );
    always_comb begin
        case(forward_A)
            2'b10: alu_oprd1 = EX_MEM_result;
            2'b01: alu_oprd1 = MEM_WB_Data;
            default: alu_oprd1 = ID_EX_ReadData1;
        endcase

        case(forward_B)
            2'b10: ID_EX_forward_B_data = EX_MEM_result;
            2'b01: ID_EX_forward_B_data = MEM_WB_Data;
            default: ID_EX_forward_B_data = ID_EX_ReadData2;
        endcase
    end
    assign alu_oprd2 = ID_EX_ALUSrc ? ID_EX_sign_extend : ID_EX_forward_B_data;
    assign RegDstData = ID_EX_RegDst ? ID_EX_rd : ID_EX_rt;
    alu ALU(
        .inA(alu_oprd1),
        .inB(alu_oprd2),
        .alu_control(ALUOperator),
        .is_zero(ID_EX_is_zero),
        .result(ID_EX_result)
    );
    pipe_reg_EX_MEM ex_mem(
        .rst(rst),
        .flush(flush_ex_mem),
        .branch(ID_EX_branch),
        .branch_out(EX_MEM_branch),
        .clk(clk),
        .isZero(ID_EX_is_zero),
        .isZero_out(EX_MEM_is_zero),
        .MemRead(ID_EX_MemRead),
        .MemRead_out(EX_MEM_MemRead),
        .MemToReg(ID_EX_MemToReg),
        .MemToReg_out(EX_MEM_MemToReg),
        .MemWrite(ID_EX_MemWrite),
        .MemWrite_out(EX_MEM_MemWrite),
        .RegDstData(RegDstData),
        .RegDstData_out(EX_MEM_rd),
        .result(ID_EX_result),
        .result_out(EX_MEM_result),
        .WriteData(ID_EX_forward_B_data),
        .WriteData_out(EX_MEM_forward_B_data),
        .branch_address(ID_EX_branch_address),
        .branch_address_out(EX_MEM_branch_address),
        .RegWrite(ID_EX_RegWrite),
        .RegWrite_out(EX_MEM_RegWrite)
    );
    assign PCSrc = EX_MEM_branch & EX_MEM_is_zero;
    // Older branch in MEM has priority over jump in ID and load-use stall.
    assign jump_target = {IF_ID_pc_plus_4[31:28], instruction_out[25:0], 2'b00};
    assign next_pc = PCSrc ? EX_MEM_branch_address : Jump ? jump_target : pc_plus_4;
    assign pc_write = PCSrc || Jump || write;
    assign flush_if_id = PCSrc || Jump;
    assign flush_id_ex = PCSrc || Jump || LU_hazard;
    assign flush_ex_mem = PCSrc;
    data_mem DataMemory(
        .address(EX_MEM_result),
        .clk(clk),
        .MemRead(EX_MEM_MemRead && !rst),
        .MemWrite(EX_MEM_MemWrite && !rst),
        .ReadData(EX_MEM_MemToRegData),
        .WriteData(EX_MEM_forward_B_data)
    );
    pipe_reg_MEM_WB mem_wb(
        .rst(rst),
        .clk(clk),
        .MemToReg(EX_MEM_MemToReg),
        .MemToReg_out(MEM_WB_MemToReg),
        .ReadData(EX_MEM_MemToRegData),
        .ReadData_out(MEM_WB_MemToRegData),
        .RegDstData(EX_MEM_rd),
        .RegDstData_out(MEM_WB_rd),
        .result(EX_MEM_result),
        .result_out(MEM_WB_result),
        .RegWrite(EX_MEM_RegWrite),
        .RegWrite_out(MEM_WB_RegWrite)
    );
    assign MEM_WB_Data = MEM_WB_MemToReg ? MEM_WB_MemToRegData : MEM_WB_result;
endmodule
