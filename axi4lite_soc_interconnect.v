`timescale 1ns/1fs

// ============================================================================
// Module : axi4lite_soc_interconnect
// Purpose:
//   Simple single-master AXI4-Lite address decoder for RV32I SoC.
//
// Address map:
//   S0 Boot ROM      : 0x0000_0000 - 0x0000_FFFF
//   S1 Program SRAM  : 0x0001_0000 - 0x0001_FFFF
//   S2 Data SRAM     : 0x0002_0000 - 0x0002_FFFF
//   S3 Timer         : 0x1000_0000 - 0x1000_0FFF
//   S4 GPIO          : 0x1000_1000 - 0x1000_1FFF
//   S5 SPI           : 0x1000_2000 - 0x1000_2FFF
//
// Notes:
//   - Designed for the existing rv32i_axi_master_wrapper: one transfer at a time.
//   - No burst, no outstanding transactions.
//   - Unsupported addresses return SLVERR.
// ============================================================================

module axi4lite_soc_interconnect (
    input             clk,
    input             rst,

    input      [31:0] M_AWADDR,
    input             M_AWVALID,
    output reg        M_AWREADY,
    input      [31:0] M_WDATA,
    input      [ 3:0] M_WSTRB,
    input             M_WVALID,
    output reg        M_WREADY,
    output reg [ 1:0] M_BRESP,
    output reg        M_BVALID,
    input             M_BREADY,
    input      [31:0] M_ARADDR,
    input             M_ARVALID,
    output reg        M_ARREADY,
    output reg [31:0] M_RDATA,
    output reg [ 1:0] M_RRESP,
    output reg        M_RVALID,
    input             M_RREADY,

    output reg [31:0] S0_AWADDR,
    output reg        S0_AWVALID,
    input             S0_AWREADY,
    output reg [31:0] S0_WDATA,
    output reg [ 3:0] S0_WSTRB,
    output reg        S0_WVALID,
    input             S0_WREADY,
    input      [ 1:0] S0_BRESP,
    input             S0_BVALID,
    output reg        S0_BREADY,
    output reg [31:0] S0_ARADDR,
    output reg        S0_ARVALID,
    input             S0_ARREADY,
    input      [31:0] S0_RDATA,
    input      [ 1:0] S0_RRESP,
    input             S0_RVALID,
    output reg        S0_RREADY,

    output reg [31:0] S1_AWADDR,
    output reg        S1_AWVALID,
    input             S1_AWREADY,
    output reg [31:0] S1_WDATA,
    output reg [ 3:0] S1_WSTRB,
    output reg        S1_WVALID,
    input             S1_WREADY,
    input      [ 1:0] S1_BRESP,
    input             S1_BVALID,
    output reg        S1_BREADY,
    output reg [31:0] S1_ARADDR,
    output reg        S1_ARVALID,
    input             S1_ARREADY,
    input      [31:0] S1_RDATA,
    input      [ 1:0] S1_RRESP,
    input             S1_RVALID,
    output reg        S1_RREADY,

    output reg [31:0] S2_AWADDR,
    output reg        S2_AWVALID,
    input             S2_AWREADY,
    output reg [31:0] S2_WDATA,
    output reg [ 3:0] S2_WSTRB,
    output reg        S2_WVALID,
    input             S2_WREADY,
    input      [ 1:0] S2_BRESP,
    input             S2_BVALID,
    output reg        S2_BREADY,
    output reg [31:0] S2_ARADDR,
    output reg        S2_ARVALID,
    input             S2_ARREADY,
    input      [31:0] S2_RDATA,
    input      [ 1:0] S2_RRESP,
    input             S2_RVALID,
    output reg        S2_RREADY,

    output reg [31:0] S3_AWADDR,
    output reg        S3_AWVALID,
    input             S3_AWREADY,
    output reg [31:0] S3_WDATA,
    output reg [ 3:0] S3_WSTRB,
    output reg        S3_WVALID,
    input             S3_WREADY,
    input      [ 1:0] S3_BRESP,
    input             S3_BVALID,
    output reg        S3_BREADY,
    output reg [31:0] S3_ARADDR,
    output reg        S3_ARVALID,
    input             S3_ARREADY,
    input      [31:0] S3_RDATA,
    input      [ 1:0] S3_RRESP,
    input             S3_RVALID,
    output reg        S3_RREADY,

    output reg [31:0] S4_AWADDR,
    output reg        S4_AWVALID,
    input             S4_AWREADY,
    output reg [31:0] S4_WDATA,
    output reg [ 3:0] S4_WSTRB,
    output reg        S4_WVALID,
    input             S4_WREADY,
    input      [ 1:0] S4_BRESP,
    input             S4_BVALID,
    output reg        S4_BREADY,
    output reg [31:0] S4_ARADDR,
    output reg        S4_ARVALID,
    input             S4_ARREADY,
    input      [31:0] S4_RDATA,
    input      [ 1:0] S4_RRESP,
    input             S4_RVALID,
    output reg        S4_RREADY,

    output reg [31:0] S5_AWADDR,
    output reg        S5_AWVALID,
    input             S5_AWREADY,
    output reg [31:0] S5_WDATA,
    output reg [ 3:0] S5_WSTRB,
    output reg        S5_WVALID,
    input             S5_WREADY,
    input      [ 1:0] S5_BRESP,
    input             S5_BVALID,
    output reg        S5_BREADY,
    output reg [31:0] S5_ARADDR,
    output reg        S5_ARVALID,
    input             S5_ARREADY,
    input      [31:0] S5_RDATA,
    input      [ 1:0] S5_RRESP,
    input             S5_RVALID,
    output reg        S5_RREADY
);

    wire aw_s0 = (M_AWADDR[31:16] == 16'h0000);
    wire aw_s1 = (M_AWADDR[31:16] == 16'h0001);
    wire aw_s2 = (M_AWADDR[31:16] == 16'h0002);
    wire aw_s3 = (M_AWADDR[31:12] == 20'h10000);
    wire aw_s4 = (M_AWADDR[31:12] == 20'h10001);
    wire aw_s5 = (M_AWADDR[31:12] == 20'h10002);

    wire ar_s0 = (M_ARADDR[31:16] == 16'h0000);
    wire ar_s1 = (M_ARADDR[31:16] == 16'h0001);
    wire ar_s2 = (M_ARADDR[31:16] == 16'h0002);
    wire ar_s3 = (M_ARADDR[31:12] == 20'h10000);
    wire ar_s4 = (M_ARADDR[31:12] == 20'h10001);
    wire ar_s5 = (M_ARADDR[31:12] == 20'h10002);

    always @(*) begin
        M_AWREADY = 1'b0;
        M_WREADY  = 1'b0;
        M_BRESP   = 2'b00;
        M_BVALID  = 1'b0;
        M_ARREADY = 1'b0;
        M_RDATA   = 32'b0;
        M_RRESP   = 2'b00;
        M_RVALID  = 1'b0;

        S0_AWADDR = M_AWADDR; S0_AWVALID = 1'b0; S0_WDATA = M_WDATA; S0_WSTRB = M_WSTRB; S0_WVALID = 1'b0; S0_BREADY = 1'b0; S0_ARADDR = M_ARADDR; S0_ARVALID = 1'b0; S0_RREADY = 1'b0;
        S1_AWADDR = M_AWADDR; S1_AWVALID = 1'b0; S1_WDATA = M_WDATA; S1_WSTRB = M_WSTRB; S1_WVALID = 1'b0; S1_BREADY = 1'b0; S1_ARADDR = M_ARADDR; S1_ARVALID = 1'b0; S1_RREADY = 1'b0;
        S2_AWADDR = M_AWADDR; S2_AWVALID = 1'b0; S2_WDATA = M_WDATA; S2_WSTRB = M_WSTRB; S2_WVALID = 1'b0; S2_BREADY = 1'b0; S2_ARADDR = M_ARADDR; S2_ARVALID = 1'b0; S2_RREADY = 1'b0;
        S3_AWADDR = M_AWADDR; S3_AWVALID = 1'b0; S3_WDATA = M_WDATA; S3_WSTRB = M_WSTRB; S3_WVALID = 1'b0; S3_BREADY = 1'b0; S3_ARADDR = M_ARADDR; S3_ARVALID = 1'b0; S3_RREADY = 1'b0;
        S4_AWADDR = M_AWADDR; S4_AWVALID = 1'b0; S4_WDATA = M_WDATA; S4_WSTRB = M_WSTRB; S4_WVALID = 1'b0; S4_BREADY = 1'b0; S4_ARADDR = M_ARADDR; S4_ARVALID = 1'b0; S4_RREADY = 1'b0;
        S5_AWADDR = M_AWADDR; S5_AWVALID = 1'b0; S5_WDATA = M_WDATA; S5_WSTRB = M_WSTRB; S5_WVALID = 1'b0; S5_BREADY = 1'b0; S5_ARADDR = M_ARADDR; S5_ARVALID = 1'b0; S5_RREADY = 1'b0;

        if (aw_s0) begin
            S0_AWVALID = M_AWVALID; S0_WVALID = M_WVALID; M_AWREADY = S0_AWREADY; M_WREADY = S0_WREADY; M_BRESP = S0_BRESP; M_BVALID = S0_BVALID; S0_BREADY = M_BREADY;
        end else if (aw_s1) begin
            S1_AWVALID = M_AWVALID; S1_WVALID = M_WVALID; M_AWREADY = S1_AWREADY; M_WREADY = S1_WREADY; M_BRESP = S1_BRESP; M_BVALID = S1_BVALID; S1_BREADY = M_BREADY;
        end else if (aw_s2) begin
            S2_AWVALID = M_AWVALID; S2_WVALID = M_WVALID; M_AWREADY = S2_AWREADY; M_WREADY = S2_WREADY; M_BRESP = S2_BRESP; M_BVALID = S2_BVALID; S2_BREADY = M_BREADY;
        end else if (aw_s3) begin
            S3_AWVALID = M_AWVALID; S3_WVALID = M_WVALID; M_AWREADY = S3_AWREADY; M_WREADY = S3_WREADY; M_BRESP = S3_BRESP; M_BVALID = S3_BVALID; S3_BREADY = M_BREADY;
        end else if (aw_s4) begin
            S4_AWVALID = M_AWVALID; S4_WVALID = M_WVALID; M_AWREADY = S4_AWREADY; M_WREADY = S4_WREADY; M_BRESP = S4_BRESP; M_BVALID = S4_BVALID; S4_BREADY = M_BREADY;
        end else if (aw_s5) begin
            S5_AWVALID = M_AWVALID; S5_WVALID = M_WVALID; M_AWREADY = S5_AWREADY; M_WREADY = S5_WREADY; M_BRESP = S5_BRESP; M_BVALID = S5_BVALID; S5_BREADY = M_BREADY;
        end else begin
            M_AWREADY = 1'b1;
            M_WREADY  = 1'b1;
            M_BRESP   = 2'b10;
            M_BVALID  = M_AWVALID & M_WVALID;
        end

        if (ar_s0) begin
            S0_ARVALID = M_ARVALID; M_ARREADY = S0_ARREADY; M_RDATA = S0_RDATA; M_RRESP = S0_RRESP; M_RVALID = S0_RVALID; S0_RREADY = M_RREADY;
        end else if (ar_s1) begin
            S1_ARVALID = M_ARVALID; M_ARREADY = S1_ARREADY; M_RDATA = S1_RDATA; M_RRESP = S1_RRESP; M_RVALID = S1_RVALID; S1_RREADY = M_RREADY;
        end else if (ar_s2) begin
            S2_ARVALID = M_ARVALID; M_ARREADY = S2_ARREADY; M_RDATA = S2_RDATA; M_RRESP = S2_RRESP; M_RVALID = S2_RVALID; S2_RREADY = M_RREADY;
        end else if (ar_s3) begin
            S3_ARVALID = M_ARVALID; M_ARREADY = S3_ARREADY; M_RDATA = S3_RDATA; M_RRESP = S3_RRESP; M_RVALID = S3_RVALID; S3_RREADY = M_RREADY;
        end else if (ar_s4) begin
            S4_ARVALID = M_ARVALID; M_ARREADY = S4_ARREADY; M_RDATA = S4_RDATA; M_RRESP = S4_RRESP; M_RVALID = S4_RVALID; S4_RREADY = M_RREADY;
        end else if (ar_s5) begin
            S5_ARVALID = M_ARVALID; M_ARREADY = S5_ARREADY; M_RDATA = S5_RDATA; M_RRESP = S5_RRESP; M_RVALID = S5_RVALID; S5_RREADY = M_RREADY;
        end else begin
            M_ARREADY = 1'b1;
            M_RDATA   = 32'h0000_0000;
            M_RRESP   = 2'b10;
            M_RVALID  = M_ARVALID;
        end
    end

endmodule
