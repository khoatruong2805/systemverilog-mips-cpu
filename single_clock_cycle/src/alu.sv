module alu(
    input logic [31:0] inA,
    input logic [31:0] inB,
    input logic [3:0] alu_control,
    output logic is_zero,
    output logic [31:0] result
);
    assign is_zero = (result == 32'b0) ? 1'b1 : 1'b0;
    always_comb begin
        case (alu_control) 
            4'b0000: result = inA & inB; // and
            4'b0001: result = inA | inB; // or
            4'b0010: result = inA + inB; // add
            4'b0110: result = inA - inB; // subtract
            4'b0111: result = ($signed(inA) < $signed(inB)) ? 32'b1 : 32'b0;
            4'b1100: result = ~(inA | inB); // nor
            default: result = 32'b0;
        endcase
    end
endmodule