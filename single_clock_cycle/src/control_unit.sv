module main_control(
    input  logic [5:0] control,
    input  logic       flush,
    output logic       branch,
    output logic       RegWrite,
    output logic       ALUSrc,
    output logic       MemWrite,
    output logic       MemRead,
    output logic       MemToReg,
    output logic       Jump,
    output logic [1:0] AluOP,
    output logic       RegDst
);
    always_comb begin
        if (flush) begin
            RegDst = 0;   RegWrite = 0;  ALUSrc = 0;
            MemRead = 0;  MemWrite = 0;  Jump = 0;
            branch = 0;   MemToReg = 0;  AluOP = 2'b00; 
        end
        else begin
            case (control)
                // R-type (ADD, SUB, AND, OR, SLT)
                6'b000000: begin
                    RegDst = 1;   RegWrite = 1;  ALUSrc = 0;
                    MemRead = 0;  MemWrite = 0;  Jump = 0;
                    branch = 0;   MemToReg = 0;  AluOP = 2'b10; // 10 cho R-Type
                end
                // ADDI, ANDI, ORI, SLTI (Nhóm Immediate)
                6'b001000, 6'b001100, 6'b001101, 6'b001010: begin
                    RegDst = 0;   RegWrite = 1;  ALUSrc = 1;
                    MemRead = 0;  MemWrite = 0;  Jump = 0;
                    branch = 0;   MemToReg = 0;  AluOP = 2'b00; // Mượn ALU làm tính toán cơ bản
                end
                // LW (Load Word)
                6'b100011: begin
                    RegDst = 0;   RegWrite = 1;  ALUSrc = 1;
                    MemRead = 1;  MemWrite = 0;  Jump = 0;
                    branch = 0;   MemToReg = 1;  AluOP = 2'b00; // 00 cho ALU làm phép cộng địa chỉ
                end
                // SW (Store Word)
                6'b101011: begin
                    RegDst = 0;   RegWrite = 0;  ALUSrc = 1;
                    MemRead = 0;  MemWrite = 1;  Jump = 0;
                    branch = 0;   MemToReg = 0;  AluOP = 2'b00; // 00 cho ALU làm phép cộng địa chỉ
                end
                // BEQ (Branch if Equal)
                6'b000100: begin
                    RegDst = 0;   RegWrite = 0;  ALUSrc = 0;
                    MemRead = 0;  MemWrite = 0;  Jump = 0;
                    branch = 1;   MemToReg = 0;  AluOP = 2'b01; // 01 cho ALU làm phép trừ
                end
                // J (Jump)
                6'b000010: begin
                    RegDst = 0;   RegWrite = 0;  ALUSrc = 0;
                    MemRead = 0;  MemWrite = 0;  Jump = 1;
                    branch = 0;   MemToReg = 0;  AluOP = 2'b00; // Không quan tâm ALU làm gì
                end
                // Default case (Tránh sinh ra chốt Latch ngoài ý muốn)
                default: begin
                    RegDst = 0;   RegWrite = 0;  ALUSrc = 0;
                    MemRead = 0;  MemWrite = 0;  Jump = 0;
                    branch = 0;   MemToReg = 0;  AluOP = 2'b00; 
                end
            endcase
        end
    end
endmodule