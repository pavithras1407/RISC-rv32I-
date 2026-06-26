`timescale 1ns/1fs
// Program Counter  (XLEN = 32)
module pc (
    input             clk,
    input             rst,
    input             en,
    input      [31:0] pc_in,
    output reg [31:0] pc_out
);
    always @(posedge clk) begin
        if (rst)       pc_out <= 32'b0;
        else if (en)   pc_out <= pc_in;
    end
endmodule
