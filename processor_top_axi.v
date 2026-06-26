`timescale 1ns/1fs

// ============================================================================
// Module : processor_top_axi
// Purpose:
//   AXI4-Lite based top module for RV32I processor.
//
// Structure:
//   processor core
//        |
//        | ready/valid imem + dmem interface
//        v
//   rv32i_axi_master_wrapper
//        |
//        | single AXI4-Lite master bus
//        v
//   axi4lite_interconnect
//        |                         |
//        v                         v
//   imem_axi_slave             dmem_axi_slave
//   SPRAM_1024x36              SPRAM_1024x36
// ============================================================================

module processor_top_axi (
    input             clk,
    input             rst,

    input             spi_irq,
    input             jtag_irq,

    output     [31:0] pc_debug,
    output     [31:0] inst_debug,

    output            rf_we,
    output     [ 4:0] rf_waddr,
    output     [31:0] rf_wdata,

    output            mem_we,
    output            mem_re,
    output     [31:0] mem_addr,
    output     [31:0] mem_wdata,
    output     [31:0] mem_rdata,

    output            br_taken_dbg,
    output            trap_taken,
    output     [31:0] epc_debug,
    output            timer_irq_dbg,
output spi_sclk,
output spi_mosi,
input  spi_miso,
output spi_cs_n
);

    // ============================================================
    // Core ready/valid memory interface wires
    // ============================================================

    wire        imem_req;
    wire [31:0] imem_addr;
    wire        imem_ready;
    wire [31:0] imem_rdata;

    wire        dmem_req;
    wire        dmem_wr;
    wire [31:0] dmem_addr;
    wire [ 2:0] dmem_acc_mode;
    wire [31:0] dmem_wdata;
    wire        dmem_ready;
    wire [31:0] dmem_rdata;

    wire        illegal_inst_dbg;

    // ============================================================
    // AXI master wrapper to interconnect wires
    // ============================================================

    wire [31:0] m_axi_awaddr;
    wire        m_axi_awvalid;
    wire        m_axi_awready;

    wire [31:0] m_axi_wdata;
    wire [ 3:0] m_axi_wstrb;
    wire        m_axi_wvalid;
    wire        m_axi_wready;

    wire [ 1:0] m_axi_bresp;
    wire        m_axi_bvalid;
    wire        m_axi_bready;

    wire [31:0] m_axi_araddr;
    wire        m_axi_arvalid;
    wire        m_axi_arready;

    wire [31:0] m_axi_rdata;
    wire [ 1:0] m_axi_rresp;
    wire        m_axi_rvalid;
    wire        m_axi_rready;

    // ============================================================
    // Interconnect to IMEM slave wires
    // ============================================================

    wire [31:0] s0_axi_awaddr;
    wire        s0_axi_awvalid;
    wire        s0_axi_awready;

    wire [31:0] s0_axi_wdata;
    wire [ 3:0] s0_axi_wstrb;
    wire        s0_axi_wvalid;
    wire        s0_axi_wready;

    wire [ 1:0] s0_axi_bresp;
    wire        s0_axi_bvalid;
    wire        s0_axi_bready;

    wire [31:0] s0_axi_araddr;
    wire        s0_axi_arvalid;
    wire        s0_axi_arready;

    wire [31:0] s0_axi_rdata;
    wire [ 1:0] s0_axi_rresp;
    wire        s0_axi_rvalid;
    wire        s0_axi_rready;
   
    // ============================================================
    // Interconnect to DMEM slave wires
    // ============================================================

    wire [31:0] s1_axi_awaddr;
    wire        s1_axi_awvalid;
    wire        s1_axi_awready;

    wire [31:0] s1_axi_wdata;
    wire [ 3:0] s1_axi_wstrb;
    wire        s1_axi_wvalid;
    wire        s1_axi_wready;

    wire [ 1:0] s1_axi_bresp;
    wire        s1_axi_bvalid;
    wire        s1_axi_bready;

    wire [31:0] s1_axi_araddr;
    wire        s1_axi_arvalid;
    wire        s1_axi_arready;

    wire [31:0] s1_axi_rdata;
    wire [ 1:0] s1_axi_rresp;
    wire        s1_axi_rvalid;
    wire        s1_axi_rready;
wire [31:0] s2_axi_awaddr;
wire        s2_axi_awvalid;
wire        s2_axi_awready;

wire [31:0] s2_axi_wdata;
wire [3:0]  s2_axi_wstrb;
wire        s2_axi_wvalid;
wire        s2_axi_wready;

wire [1:0]  s2_axi_bresp;
wire        s2_axi_bvalid;
wire        s2_axi_bready;

wire [31:0] s2_axi_araddr;
wire        s2_axi_arvalid;
wire        s2_axi_arready;

wire [31:0] s2_axi_rdata;
wire [1:0]  s2_axi_rresp;
wire        s2_axi_rvalid;
wire        s2_axi_rready;

    // ============================================================
    // RV32I processor core
    // ============================================================

    processor core (
        .clk              (clk),
        .rst              (rst),

         .spi_irq(spi_irq),
        .jtag_irq         (jtag_irq),

        .imem_req         (imem_req),
        .imem_addr        (imem_addr),
        .imem_ready       (imem_ready),
        .imem_rdata       (imem_rdata),

        .dmem_req         (dmem_req),
        .dmem_wr          (dmem_wr),
        .dmem_addr        (dmem_addr),
        .dmem_acc_mode    (dmem_acc_mode),
        .dmem_wdata       (dmem_wdata),
        .dmem_ready       (dmem_ready),
        .dmem_rdata       (dmem_rdata),

        .pc_debug         (pc_debug),
        .inst_debug       (inst_debug),

        .rf_we            (rf_we),
        .rf_waddr         (rf_waddr),
        .rf_wdata         (rf_wdata),

        .mem_we           (mem_we),
        .mem_re           (mem_re),
        .mem_addr         (mem_addr),
        .mem_wdata        (mem_wdata),
        .mem_rdata        (mem_rdata),

        .br_taken_dbg     (br_taken_dbg),
        .trap_taken       (trap_taken),
        .epc_debug        (epc_debug),
        .timer_irq_dbg    (timer_irq_dbg),
        .illegal_inst_dbg (illegal_inst_dbg)
    );

    // ============================================================
    // Core ready/valid to AXI4-Lite master wrapper
    // ============================================================

    rv32i_axi_master_wrapper axi_master_i (
        .clk              (clk),
        .rst              (rst),

        .imem_req         (imem_req),
        .imem_addr        (imem_addr),
        .imem_ready       (imem_ready),
        .imem_rdata       (imem_rdata),

        .dmem_req         (dmem_req),
        .dmem_wr          (dmem_wr),
        .dmem_addr        (dmem_addr),
        .dmem_acc_mode    (dmem_acc_mode),
        .dmem_wdata       (dmem_wdata),
        .dmem_ready       (dmem_ready),
        .dmem_rdata       (dmem_rdata),

        .M_AXI_AWADDR     (m_axi_awaddr),
        .M_AXI_AWVALID    (m_axi_awvalid),
        .M_AXI_AWREADY    (m_axi_awready),

        .M_AXI_WDATA      (m_axi_wdata),
        .M_AXI_WSTRB      (m_axi_wstrb),
        .M_AXI_WVALID     (m_axi_wvalid),
        .M_AXI_WREADY     (m_axi_wready),

        .M_AXI_BRESP      (m_axi_bresp),
        .M_AXI_BVALID     (m_axi_bvalid),
        .M_AXI_BREADY     (m_axi_bready),

        .M_AXI_ARADDR     (m_axi_araddr),
        .M_AXI_ARVALID    (m_axi_arvalid),
        .M_AXI_ARREADY    (m_axi_arready),

        .M_AXI_RDATA      (m_axi_rdata),
        .M_AXI_RRESP      (m_axi_rresp),
        .M_AXI_RVALID     (m_axi_rvalid),
        .M_AXI_RREADY     (m_axi_rready)
    );

    // ============================================================
    // AXI4-Lite interconnect
    // S0 = instruction memory
    // S1 = data memory
    // ============================================================

    axi4lite_interconnect axi_ic_i (
        .clk          (clk),
        .rst          (rst),

        .M_AWADDR     (m_axi_awaddr),
        .M_AWVALID    (m_axi_awvalid),
        .M_AWREADY    (m_axi_awready),

        .M_WDATA      (m_axi_wdata),
        .M_WSTRB      (m_axi_wstrb),
        .M_WVALID     (m_axi_wvalid),
        .M_WREADY     (m_axi_wready),

        .M_BRESP      (m_axi_bresp),
        .M_BVALID     (m_axi_bvalid),
        .M_BREADY     (m_axi_bready),

        .M_ARADDR     (m_axi_araddr),
        .M_ARVALID    (m_axi_arvalid),
        .M_ARREADY    (m_axi_arready),

        .M_RDATA      (m_axi_rdata),
        .M_RRESP      (m_axi_rresp),
        .M_RVALID     (m_axi_rvalid),
        .M_RREADY     (m_axi_rready),

        // Slave 0: IMEM
        .S0_AWADDR    (s0_axi_awaddr),
        .S0_AWVALID   (s0_axi_awvalid),
        .S0_AWREADY   (s0_axi_awready),

        .S0_WDATA     (s0_axi_wdata),
        .S0_WSTRB     (s0_axi_wstrb),
        .S0_WVALID    (s0_axi_wvalid),
        .S0_WREADY    (s0_axi_wready),

        .S0_BRESP     (s0_axi_bresp),
        .S0_BVALID    (s0_axi_bvalid),
        .S0_BREADY    (s0_axi_bready),

        .S0_ARADDR    (s0_axi_araddr),
        .S0_ARVALID   (s0_axi_arvalid),
        .S0_ARREADY   (s0_axi_arready),

        .S0_RDATA     (s0_axi_rdata),
        .S0_RRESP     (s0_axi_rresp),
        .S0_RVALID    (s0_axi_rvalid),
        .S0_RREADY    (s0_axi_rready),

        // Slave 1: DMEM
        .S1_AWADDR    (s1_axi_awaddr),
        .S1_AWVALID   (s1_axi_awvalid),
        .S1_AWREADY   (s1_axi_awready),

        .S1_WDATA     (s1_axi_wdata),
        .S1_WSTRB     (s1_axi_wstrb),
        .S1_WVALID    (s1_axi_wvalid),
        .S1_WREADY    (s1_axi_wready),

        .S1_BRESP     (s1_axi_bresp),
        .S1_BVALID    (s1_axi_bvalid),
        .S1_BREADY    (s1_axi_bready),

        .S1_ARADDR    (s1_axi_araddr),
        .S1_ARVALID   (s1_axi_arvalid),
        .S1_ARREADY   (s1_axi_arready),

        .S1_RDATA     (s1_axi_rdata),
        .S1_RRESP     (s1_axi_rresp),
        .S1_RVALID    (s1_axi_rvalid),
        .S1_RREADY    (s1_axi_rready),
.S2_AWADDR   (s2_axi_awaddr),
.S2_AWVALID  (s2_axi_awvalid),
.S2_AWREADY  (s2_axi_awready),

.S2_WDATA    (s2_axi_wdata),
.S2_WSTRB    (s2_axi_wstrb),
.S2_WVALID   (s2_axi_wvalid),
.S2_WREADY   (s2_axi_wready),

.S2_BRESP    (s2_axi_bresp),
.S2_BVALID   (s2_axi_bvalid),
.S2_BREADY   (s2_axi_bready),

.S2_ARADDR   (s2_axi_araddr),
.S2_ARVALID  (s2_axi_arvalid),
.S2_ARREADY  (s2_axi_arready),

.S2_RDATA    (s2_axi_rdata),
.S2_RRESP    (s2_axi_rresp),
.S2_RVALID   (s2_axi_rvalid),
.S2_RREADY   (s2_axi_rready)
    );

    // ============================================================
    // AXI4-Lite instruction memory slave
    // Address range: 0x0000_0000 - 0x0000_0FFF
    // ============================================================

    axi4lite_sram_slave imem_axi_slave (
        .clk             (clk),
        .rst             (rst),

        .S_AXI_AWADDR    (s0_axi_awaddr),
        .S_AXI_AWVALID   (s0_axi_awvalid),
        .S_AXI_AWREADY   (s0_axi_awready),

        .S_AXI_WDATA     (s0_axi_wdata),
        .S_AXI_WSTRB     (s0_axi_wstrb),
        .S_AXI_WVALID    (s0_axi_wvalid),
        .S_AXI_WREADY    (s0_axi_wready),

        .S_AXI_BRESP     (s0_axi_bresp),
        .S_AXI_BVALID    (s0_axi_bvalid),
        .S_AXI_BREADY    (s0_axi_bready),

        .S_AXI_ARADDR    (s0_axi_araddr),
        .S_AXI_ARVALID   (s0_axi_arvalid),
        .S_AXI_ARREADY   (s0_axi_arready),

        .S_AXI_RDATA     (s0_axi_rdata),
        .S_AXI_RRESP     (s0_axi_rresp),
        .S_AXI_RVALID    (s0_axi_rvalid),
        .S_AXI_RREADY    (s0_axi_rready)
    );

    // ============================================================
    // AXI4-Lite data memory slave
    // Address range: 0x0001_0000 - 0x0001_0FFF
    // ============================================================

    axi4lite_sram_slave dmem_axi_slave (
        .clk             (clk),
        .rst             (rst),

        .S_AXI_AWADDR    (s1_axi_awaddr),
        .S_AXI_AWVALID   (s1_axi_awvalid),
        .S_AXI_AWREADY   (s1_axi_awready),

        .S_AXI_WDATA     (s1_axi_wdata),
        .S_AXI_WSTRB     (s1_axi_wstrb),
        .S_AXI_WVALID    (s1_axi_wvalid),
        .S_AXI_WREADY    (s1_axi_wready),

        .S_AXI_BRESP     (s1_axi_bresp),
        .S_AXI_BVALID    (s1_axi_bvalid),
        .S_AXI_BREADY    (s1_axi_bready),

        .S_AXI_ARADDR    (s1_axi_araddr),
        .S_AXI_ARVALID   (s1_axi_arvalid),
        .S_AXI_ARREADY   (s1_axi_arready),

        .S_AXI_RDATA     (s1_axi_rdata),
        .S_AXI_RRESP     (s1_axi_rresp),
        .S_AXI_RVALID    (s1_axi_rvalid),
        .S_AXI_RREADY    (s1_axi_rready)
    );
axi4lite_spi_slave spi_axi_slave
(
    .clk            (clk),
    .rst            (rst),

    .S_AXI_AWADDR   (s2_axi_awaddr),
    .S_AXI_AWVALID  (s2_axi_awvalid),
    .S_AXI_AWREADY  (s2_axi_awready),

    .S_AXI_WDATA    (s2_axi_wdata),
    .S_AXI_WSTRB    (s2_axi_wstrb),
    .S_AXI_WVALID   (s2_axi_wvalid),
    .S_AXI_WREADY   (s2_axi_wready),

    .S_AXI_BRESP    (s2_axi_bresp),
    .S_AXI_BVALID   (s2_axi_bvalid),
    .S_AXI_BREADY   (s2_axi_bready),

    .S_AXI_ARADDR   (s2_axi_araddr),
    .S_AXI_ARVALID  (s2_axi_arvalid),
    .S_AXI_ARREADY  (s2_axi_arready),

    .S_AXI_RDATA    (s2_axi_rdata),
    .S_AXI_RRESP    (s2_axi_rresp),
    .S_AXI_RVALID   (s2_axi_rvalid),
    .S_AXI_RREADY   (s2_axi_rready),

    .spi_sclk       (spi_sclk),
    .spi_mosi       (spi_mosi),
    .spi_miso       (spi_miso),
    .spi_irq(spi_irq),
    .spi_cs_n       (spi_cs_n)
);

endmodule
