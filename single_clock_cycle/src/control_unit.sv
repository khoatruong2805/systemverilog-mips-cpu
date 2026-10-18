`timescale 1ns/1ps
module main_control(
    input logic [5:0] control, funct,
    input logic rst,
    output logic branch, RegWrite, ALUSrc, MemWrite, MemRead,
    output logic MemToReg, Jump,
    output logic [2:0] AluOP,
    output logic RegDst
);
    always_comb begin
        branch = 0; RegWrite = 0; ALUSrc = 0; MemWrite = 0;
        MemRead = 0; MemToReg = 0; Jump = 0; AluOP = 3'b000; RegDst = 0;
        if (!rst) begin
            case (control)
                6'h00: begin
                    RegDst = 1;
                    AluOP = 3'b010;
                    case (funct)
                        6'h20, 6'h22, 6'h24, 6'h25, 6'h2a: RegWrite = 1;
                        default: RegWrite = 0; // NOP / unsupported R-type
                    endcase
                end
                6'h08, 6'h0c, 6'h0d, 6'h0a: begin
                    RegWrite = 1; ALUSrc = 1;
                    case (control)
                        6'h0c: AluOP = 3'b011;
                        6'h0d: AluOP = 3'b100;
                        6'h0a: AluOP = 3'b101;
                        default: AluOP = 3'b000;
                    endcase
                end
                6'h23: begin
                    RegWrite = 1; ALUSrc = 1; MemRead = 1; MemToReg = 1;
                end
                6'h2b: begin ALUSrc = 1; MemWrite = 1; end
                6'h04: begin branch = 1; AluOP = 3'b001; end
                6'h02: Jump = 1;
                default: begin end // Unsupported opcode has no side effects.
            endcase
        end
    end
endmodule
