`timescale 1ns/1ps
module forwarding_unit(
    input logic [4:0] ID_EX_rt,
    input logic [4:0] ID_EX_rs,
    input logic [4:0] EX_MEM_rd,
    input logic       EX_MEM_RegWrite,
    input logic       MEM_WB_RegWrite,
    input logic [4:0] MEM_WB_rd,
    output logic [1:0] forward_A,
    output logic [1:0] forward_B
);
    always_comb begin
        forward_A = 2'b00;
        forward_B = 2'b00;
        //ex-hazard - mâu thuẫn với lệnh trước đó
        if (EX_MEM_RegWrite && EX_MEM_rd && (EX_MEM_rd == ID_EX_rs))
            forward_A = 2'b10;
        if (EX_MEM_RegWrite && EX_MEM_rd && (EX_MEM_rd == ID_EX_rt))
            forward_B = 2'b10;
        //mem-hazard - mâu thuẫn với lệnh cách đó 2 lệnh
        if (MEM_WB_RegWrite && MEM_WB_rd && !(EX_MEM_RegWrite && EX_MEM_rd && (EX_MEM_rd == ID_EX_rs)) && (MEM_WB_rd == ID_EX_rs))
            forward_A = 2'b01;
        if (MEM_WB_RegWrite && MEM_WB_rd && !(EX_MEM_RegWrite && EX_MEM_rd && (EX_MEM_rd == ID_EX_rt)) && (MEM_WB_rd == ID_EX_rt))
            forward_B = 2'b01;
    end
endmodule