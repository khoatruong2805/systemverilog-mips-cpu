module jump(
    input logic [31:0] not_jump,
    input logic jump,
    input logic [25:0] is_jump,
    output logic [31:0] next_pc
); 
    logic [31:0] jump_target;
    assign jump_target = {not_jump[31:28], is_jump, 2'b00};
    always_comb begin
        if (jump) begin
            next_pc = jump_target;
        end
        else begin
            next_pc = not_jump;
        end
    end
endmodule