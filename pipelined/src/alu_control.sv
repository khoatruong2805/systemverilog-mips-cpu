`timescale 1ns/1ps
module alu_control(
    input  logic [2:0] alu_op,
    input  logic [5:0] funct,
    output logic [3:0] alu_operation
);
    always_comb begin
        case (alu_op)
            3'b000: alu_operation = 4'b0010; // lw/sw
            3'b001: alu_operation = 4'b0110; // beq
            3'b010: begin // R-Type
                case (funct)
                    6'b100000: alu_operation = 4'b0010; // ADD
                    6'b100010: alu_operation = 4'b0110; // SUB
                    6'b100100: alu_operation = 4'b0000; // AND
                    6'b100101: alu_operation = 4'b0001; // OR
                    6'b101010: alu_operation = 4'b0111; // SLT
                    default:   alu_operation = 4'b0000;
                endcase
            end
            3'b011: alu_operation = 4'b0000; // andi
            3'b100: alu_operation = 4'b0001; // ori
            3'b101: alu_operation = 4'b0111; // slti
            default: alu_operation = 4'b0000;
        endcase
    end
endmodule