module branch(
    input logic branch,
    input logic is_zero,
    input logic [31:0] not_branch,
    input logic [31:0] is_branch,
    output logic [31:0] next_pc
);
    always_comb begin
        if (branch && is_zero) begin
            next_pc = is_branch;
        end else begin
            next_pc = not_branch;
        end
    end
endmodule