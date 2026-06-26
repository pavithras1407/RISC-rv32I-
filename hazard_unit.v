module hazard_unit (
    input  [4:0] rs1_DE,
    input  [4:0] rs2_DE,
    input  [4:0] rd_MW,
    input        rf_en_MW,
input load_valid_WB,
    output reg   forward_a,
    output reg   forward_b,

    input  [31:0] inst_IF,
    input  [4:0]  rd_DE,
    input  [1:0]  wb_sel_DE,
    input         br_taken,
    output reg    stall_IF,
    output reg    flush_DE
);

reg stall_lw;

always @(*) begin
    forward_a = rf_en_MW && (rs1_DE == rd_MW) && (rs1_DE != 5'b0);
    forward_b = rf_en_MW && (rs2_DE == rd_MW) && (rs2_DE != 5'b0);
end

always @(*) begin
    stall_lw = 1'b0;

    if (wb_sel_DE == 2'b10 && rd_DE != 5'b0) begin
        if ((inst_IF[19:15] == rd_DE) || (inst_IF[24:20] == rd_DE))
            stall_lw = 1'b1;
    end

    stall_IF = stall_lw;
    flush_DE = stall_lw | br_taken;
end

endmodule
