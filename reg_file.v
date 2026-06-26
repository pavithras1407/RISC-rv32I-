module reg_file (
    input             clk,
    input             rst,
    input             rf_en,
    input      [ 4:0] rs1,
    input      [ 4:0] rs2,
    input      [ 4:0] rd,
    input      [31:0] wdata,
    output reg [31:0] rdata1,
    output reg [31:0] rdata2
);
    reg [31:0] reg_mem [1:31];
    integer i;

    always @(*) begin
        rdata1 = (rs1 == 5'b00000) ? 32'b0 : reg_mem[rs1];
        rdata2 = (rs2 == 5'b00000) ? 32'b0 : reg_mem[rs2];
    end

    always @(posedge clk) begin
        if (rst) begin
            for (i = 1; i < 32; i = i + 1)
                reg_mem[i] <= 32'b0;
        end
        else if (rf_en && (rd != 5'b00000)) begin
            reg_mem[rd] <= wdata;
        end
    end
endmodule
