module alu_control(
    input  logic [1:0] alu_op,
    input  logic [5:0] funct,
    output logic [3:0] alu_operation
);
    always_comb begin
        case (alu_op)
            2'b00: alu_operation = 4'b0010; // lw/sw -> Luôn bắt ALU làm phép CỘNG
            2'b01: alu_operation = 4'b0110; // beq -> Luôn bắt ALU làm phép TRỪ
            2'b10: begin // R-Type -> Phải lôi funct ra xét
                case (funct)
                    6'b100000: alu_operation = 4'b0010; // ADD
                    6'b100010: alu_operation = 4'b0110; // SUB
                    6'b100100: alu_operation = 4'b0000; // AND
                    6'b100101: alu_operation = 4'b0001; // OR
                    6'b101010: alu_operation = 4'b0111; // SLT
                    default:   alu_operation = 4'b0000;
                endcase
            end
            default: alu_operation = 4'b0000;
        endcase
    end
endmodule