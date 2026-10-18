`timescale 1ns/1ps
module hazard_detection(
    input logic [5:0] IF_ID_opcode, IF_ID_funct,
    input logic [4:0] IF_ID_rs, IF_ID_rt, ID_EX_rt,
    input logic ID_EX_Mem_Read,
    output logic write, LU_hazard
);
    logic uses_rs, uses_rt;
    always_comb begin
        uses_rs = 0; uses_rt = 0;
        case (IF_ID_opcode)
            6'h00: begin
                case (IF_ID_funct)
                    6'h20, 6'h22, 6'h24, 6'h25, 6'h2a: begin uses_rs = 1; uses_rt = 1; end
                    default: begin end
                endcase
            end
            6'h04, 6'h2b: begin uses_rs = 1; uses_rt = 1; end
            6'h08, 6'h0c, 6'h0d, 6'h0a, 6'h23: uses_rs = 1;
            default: begin end
        endcase
        LU_hazard = ID_EX_Mem_Read && ID_EX_rt != 0 &&
            ((uses_rs && IF_ID_rs == ID_EX_rt) || (uses_rt && IF_ID_rt == ID_EX_rt));
        write = !LU_hazard;
    end
endmodule
