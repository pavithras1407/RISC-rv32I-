`timescale 1ns/1fs

// ============================================================================
// Module : rv32i_soc_top_spi_boot
// Purpose:
//   Stage-1 tapeout-style RV32I microcontroller SoC top.
//
// SoC memory map:
//   0x0000_0000 : Boot ROM
//   0x0001_0000 : Program SRAM / instruction memory
//   0x0002_0000 : Data SRAM
//   0x1000_0000 : Timer
//   0x1000_1000 : GPIO
//   0x1000_2000 : SPI
//
// Boot flow:
//   reset -> PC=0x0000_0000 -> Boot ROM -> jump to 0x0001_0000
// ============================================================================

module rv32i_soc_top_spi_boot (
    input             clk,
    input             rst_n,

    // Boot-loader control. When boot_en=1, CPU is held in reset until
    // the SPI boot loader receives a DONE frame.
    input             boot_en,

    // External SPI boot-loader slave pins.
    input             boot_spi_sclk,
    input             boot_spi_mosi,
    output            boot_spi_miso,
    input             boot_spi_cs_n,

    input             jtag_irq,

    input      [ 7:0] gpio_in,
    output     [ 7:0] gpio_out,
    output     [ 7:0] gpio_oe,
    output     [31:0] debug_out,

    // Normal CPU-accessed SPI peripheral pins.
    output            spi_sclk,
    output            spi_mosi,
    input             spi_miso,
    output            spi_cs_n,

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

    output            loader_done,
    output            cpu_rst_dbg
);

    wire rst_raw;
    wire rst;

    wire loader_done_internal;
    wire loader_active;

    reset_sync reset_sync_i (
        .clk    (clk),
        .arst_n (rst_n),
        .srst   (rst_raw)
    );

    assign loader_active = boot_en & ~loader_done_internal;
    assign rst           = rst_raw | loader_active;
    assign loader_done   = loader_done_internal;
    assign cpu_rst_dbg   = rst;

    wire        imem_req;
    wire [31:0] imem_addr;
    wire        imem_ready;
    wire [31:0] imem_rdata;
    wire        imem_error;

    wire        dmem_req;
    wire        dmem_wr;
    wire [31:0] dmem_addr;
    wire [ 2:0] dmem_acc_mode;
    wire [31:0] dmem_wdata;
    wire        dmem_ready;
    wire [31:0] dmem_rdata;
    wire        dmem_error;

    wire        illegal_inst_dbg;
    wire        timer_irq_internal;
    wire        spi_irq_internal;

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

    wire [31:0]  s0_axi_awaddr;
    wire         s0_axi_awvalid;
    wire         s0_axi_awready;
    wire [31:0]  s0_axi_wdata;
    wire [3:0]   s0_axi_wstrb;
    wire         s0_axi_wvalid;
    wire         s0_axi_wready;
    wire [1:0]   s0_axi_bresp;
    wire         s0_axi_bvalid;
    wire         s0_axi_bready;
    wire [31:0]  s0_axi_araddr;
    wire         s0_axi_arvalid;
    wire         s0_axi_arready;
    wire [31:0]  s0_axi_rdata;
    wire [1:0]   s0_axi_rresp;
    wire         s0_axi_rvalid;
    wire         s0_axi_rready;
    wire [31:0]  s1_axi_awaddr;
    wire         s1_axi_awvalid;
    wire         s1_axi_awready;
    wire [31:0]  s1_axi_wdata;
    wire [3:0]   s1_axi_wstrb;
    wire         s1_axi_wvalid;
    wire         s1_axi_wready;
    wire [1:0]   s1_axi_bresp;
    wire         s1_axi_bvalid;
    wire         s1_axi_bready;
    wire [31:0]  s1_axi_araddr;
    wire         s1_axi_arvalid;
    wire         s1_axi_arready;
    wire [31:0]  s1_axi_rdata;
    wire [1:0]   s1_axi_rresp;
    wire         s1_axi_rvalid;
    wire         s1_axi_rready;
    wire [31:0]  s2_axi_awaddr;
    wire         s2_axi_awvalid;
    wire         s2_axi_awready;
    wire [31:0]  s2_axi_wdata;
    wire [3:0]   s2_axi_wstrb;
    wire         s2_axi_wvalid;
    wire         s2_axi_wready;
    wire [1:0]   s2_axi_bresp;
    wire         s2_axi_bvalid;
    wire         s2_axi_bready;
    wire [31:0]  s2_axi_araddr;
    wire         s2_axi_arvalid;
    wire         s2_axi_arready;
    wire [31:0]  s2_axi_rdata;
    wire [1:0]   s2_axi_rresp;
    wire         s2_axi_rvalid;
    wire         s2_axi_rready;
    wire [31:0]  s3_axi_awaddr;
    wire         s3_axi_awvalid;
    wire         s3_axi_awready;
    wire [31:0]  s3_axi_wdata;
    wire [3:0]   s3_axi_wstrb;
    wire         s3_axi_wvalid;
    wire         s3_axi_wready;
    wire [1:0]   s3_axi_bresp;
    wire         s3_axi_bvalid;
    wire         s3_axi_bready;
    wire [31:0]  s3_axi_araddr;
    wire         s3_axi_arvalid;
    wire         s3_axi_arready;
    wire [31:0]  s3_axi_rdata;
    wire [1:0]   s3_axi_rresp;
    wire         s3_axi_rvalid;
    wire         s3_axi_rready;
    wire [31:0]  s4_axi_awaddr;
    wire         s4_axi_awvalid;
    wire         s4_axi_awready;
    wire [31:0]  s4_axi_wdata;
    wire [3:0]   s4_axi_wstrb;
    wire         s4_axi_wvalid;
    wire         s4_axi_wready;
    wire [1:0]   s4_axi_bresp;
    wire         s4_axi_bvalid;
    wire         s4_axi_bready;
    wire [31:0]  s4_axi_araddr;
    wire         s4_axi_arvalid;
    wire         s4_axi_arready;
    wire [31:0]  s4_axi_rdata;
    wire [1:0]   s4_axi_rresp;
    wire         s4_axi_rvalid;
    wire         s4_axi_rready;
    wire [31:0]  s5_axi_awaddr;
    wire         s5_axi_awvalid;
    wire         s5_axi_awready;
    wire [31:0]  s5_axi_wdata;
    wire [3:0]   s5_axi_wstrb;
    wire         s5_axi_wvalid;
    wire         s5_axi_wready;
    wire [1:0]   s5_axi_bresp;
    wire         s5_axi_bvalid;
    wire         s5_axi_bready;
    wire [31:0]  s5_axi_araddr;
    wire         s5_axi_arvalid;
    wire         s5_axi_arready;
    wire [31:0]  s5_axi_rdata;
    wire [1:0]   s5_axi_rresp;
    wire         s5_axi_rvalid;
    wire         s5_axi_rready;

    // ============================================================
    // SPI boot-loader AXI write master and Program SRAM mux.
    // While loader_active=1, Program SRAM S1 port is controlled by
    // the SPI loader. The CPU and SoC interconnect are held in reset,
    // so there is no CPU conflict.
    // ============================================================
    wire [31:0]  ldr_axi_awaddr;
    wire         ldr_axi_awvalid;
    wire         ldr_axi_awready;
    wire [31:0]  ldr_axi_wdata;
    wire [3:0]   ldr_axi_wstrb;
    wire         ldr_axi_wvalid;
    wire         ldr_axi_wready;
    wire [1:0]   ldr_axi_bresp;
    wire         ldr_axi_bvalid;
    wire         ldr_axi_bready;

    wire [31:0]  ps_axi_awaddr;
    wire         ps_axi_awvalid;
    wire         ps_axi_awready;
    wire [31:0]  ps_axi_wdata;
    wire [3:0]   ps_axi_wstrb;
    wire         ps_axi_wvalid;
    wire         ps_axi_wready;
    wire [1:0]   ps_axi_bresp;
    wire         ps_axi_bvalid;
    wire         ps_axi_bready;
    wire [31:0]  ps_axi_araddr;
    wire         ps_axi_arvalid;
    wire         ps_axi_arready;
    wire [31:0]  ps_axi_rdata;
    wire [1:0]   ps_axi_rresp;
    wire         ps_axi_rvalid;
    wire         ps_axi_rready;

    assign ps_axi_awaddr  = loader_active ? ldr_axi_awaddr  : s1_axi_awaddr;
    assign ps_axi_awvalid = loader_active ? ldr_axi_awvalid : s1_axi_awvalid;
    assign ps_axi_wdata   = loader_active ? ldr_axi_wdata   : s1_axi_wdata;
    assign ps_axi_wstrb   = loader_active ? ldr_axi_wstrb   : s1_axi_wstrb;
    assign ps_axi_wvalid  = loader_active ? ldr_axi_wvalid  : s1_axi_wvalid;
    assign ps_axi_bready  = loader_active ? ldr_axi_bready  : s1_axi_bready;

    // SPI loader is write-only. Disable Program SRAM reads during load.
    assign ps_axi_araddr  = loader_active ? 32'b0          : s1_axi_araddr;
    assign ps_axi_arvalid = loader_active ? 1'b0           : s1_axi_arvalid;
    assign ps_axi_rready  = loader_active ? 1'b0           : s1_axi_rready;

    assign ldr_axi_awready = loader_active ? ps_axi_awready : 1'b0;
    assign ldr_axi_wready  = loader_active ? ps_axi_wready  : 1'b0;
    assign ldr_axi_bresp   = loader_active ? ps_axi_bresp   : 2'b00;
    assign ldr_axi_bvalid  = loader_active ? ps_axi_bvalid  : 1'b0;

    assign s1_axi_awready = loader_active ? 1'b0           : ps_axi_awready;
    assign s1_axi_wready  = loader_active ? 1'b0           : ps_axi_wready;
    assign s1_axi_bresp   = loader_active ? 2'b00          : ps_axi_bresp;
    assign s1_axi_bvalid  = loader_active ? 1'b0           : ps_axi_bvalid;
    assign s1_axi_arready = loader_active ? 1'b0           : ps_axi_arready;
    assign s1_axi_rdata   = loader_active ? 32'b0          : ps_axi_rdata;
    assign s1_axi_rresp   = loader_active ? 2'b00          : ps_axi_rresp;
    assign s1_axi_rvalid  = loader_active ? 1'b0           : ps_axi_rvalid;


    spi_boot_loader spi_boot_loader_i (
        .clk            (clk),
        .rst            (rst_raw),
        .boot_en        (boot_en),
        .spi_sclk       (boot_spi_sclk),
        .spi_mosi       (boot_spi_mosi),
        .spi_miso       (boot_spi_miso),
        .spi_csn        (boot_spi_cs_n),
        .loader_done    (loader_done_internal),
        .M_AXI_AWADDR   (ldr_axi_awaddr),
        .M_AXI_AWVALID  (ldr_axi_awvalid),
        .M_AXI_AWREADY  (ldr_axi_awready),
        .M_AXI_WDATA    (ldr_axi_wdata),
        .M_AXI_WSTRB    (ldr_axi_wstrb),
        .M_AXI_WVALID   (ldr_axi_wvalid),
        .M_AXI_WREADY   (ldr_axi_wready),
        .M_AXI_BRESP    (ldr_axi_bresp),
        .M_AXI_BVALID   (ldr_axi_bvalid),
        .M_AXI_BREADY   (ldr_axi_bready)
    );

    processor_soc core (
        .clk              (clk),
        .rst              (rst),
        .timer_irq        (timer_irq_internal),
        .spi_irq          (spi_irq_internal),
        .jtag_irq         (jtag_irq),

        .imem_req         (imem_req),
        .imem_addr        (imem_addr),
        .imem_ready       (imem_ready),
        .imem_rdata       (imem_rdata),
        .imem_error       (imem_error),

        .dmem_req         (dmem_req),
        .dmem_wr          (dmem_wr),
        .dmem_addr        (dmem_addr),
        .dmem_acc_mode    (dmem_acc_mode),
        .dmem_wdata       (dmem_wdata),
        .dmem_ready       (dmem_ready),
        .dmem_rdata       (dmem_rdata),
        .dmem_error       (dmem_error),

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

    rv32i_axi_master_wrapper #(
        .IMEM_BASE (32'h0000_0000),
        .DMEM_BASE (32'h0002_0000)
    ) axi_master_i (
        .clk              (clk),
        .rst              (rst),
        .imem_req         (imem_req),
        .imem_addr        (imem_addr),
        .imem_ready       (imem_ready),
        .imem_rdata       (imem_rdata),
        .imem_error       (imem_error),
        .dmem_req         (dmem_req),
        .dmem_wr          (dmem_wr),
        .dmem_addr        (dmem_addr),
        .dmem_acc_mode    (dmem_acc_mode),
        .dmem_wdata       (dmem_wdata),
        .dmem_ready       (dmem_ready),
        .dmem_rdata       (dmem_rdata),
        .dmem_error       (dmem_error),
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

    axi4lite_soc_interconnect axi_ic_i (
        .clk       (clk),
        .rst       (rst),
        .M_AWADDR   (m_axi_awaddr),
        .M_AWVALID  (m_axi_awvalid),
        .M_AWREADY  (m_axi_awready),
        .M_WDATA    (m_axi_wdata),
        .M_WSTRB    (m_axi_wstrb),
        .M_WVALID   (m_axi_wvalid),
        .M_WREADY   (m_axi_wready),
        .M_BRESP    (m_axi_bresp),
        .M_BVALID   (m_axi_bvalid),
        .M_BREADY   (m_axi_bready),
        .M_ARADDR   (m_axi_araddr),
        .M_ARVALID  (m_axi_arvalid),
        .M_ARREADY  (m_axi_arready),
        .M_RDATA    (m_axi_rdata),
        .M_RRESP    (m_axi_rresp),
        .M_RVALID   (m_axi_rvalid),
        .M_RREADY   (m_axi_rready),
        .S0_AWADDR   (s0_axi_awaddr),
        .S0_AWVALID  (s0_axi_awvalid),
        .S0_AWREADY  (s0_axi_awready),
        .S0_WDATA    (s0_axi_wdata),
        .S0_WSTRB    (s0_axi_wstrb),
        .S0_WVALID   (s0_axi_wvalid),
        .S0_WREADY   (s0_axi_wready),
        .S0_BRESP    (s0_axi_bresp),
        .S0_BVALID   (s0_axi_bvalid),
        .S0_BREADY   (s0_axi_bready),
        .S0_ARADDR   (s0_axi_araddr),
        .S0_ARVALID  (s0_axi_arvalid),
        .S0_ARREADY  (s0_axi_arready),
        .S0_RDATA    (s0_axi_rdata),
        .S0_RRESP    (s0_axi_rresp),
        .S0_RVALID   (s0_axi_rvalid),
        .S0_RREADY   (s0_axi_rready),
        .S1_AWADDR   (s1_axi_awaddr),
        .S1_AWVALID  (s1_axi_awvalid),
        .S1_AWREADY  (s1_axi_awready),
        .S1_WDATA    (s1_axi_wdata),
        .S1_WSTRB    (s1_axi_wstrb),
        .S1_WVALID   (s1_axi_wvalid),
        .S1_WREADY   (s1_axi_wready),
        .S1_BRESP    (s1_axi_bresp),
        .S1_BVALID   (s1_axi_bvalid),
        .S1_BREADY   (s1_axi_bready),
        .S1_ARADDR   (s1_axi_araddr),
        .S1_ARVALID  (s1_axi_arvalid),
        .S1_ARREADY  (s1_axi_arready),
        .S1_RDATA    (s1_axi_rdata),
        .S1_RRESP    (s1_axi_rresp),
        .S1_RVALID   (s1_axi_rvalid),
        .S1_RREADY   (s1_axi_rready),
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
        .S2_RREADY   (s2_axi_rready),
        .S3_AWADDR   (s3_axi_awaddr),
        .S3_AWVALID  (s3_axi_awvalid),
        .S3_AWREADY  (s3_axi_awready),
        .S3_WDATA    (s3_axi_wdata),
        .S3_WSTRB    (s3_axi_wstrb),
        .S3_WVALID   (s3_axi_wvalid),
        .S3_WREADY   (s3_axi_wready),
        .S3_BRESP    (s3_axi_bresp),
        .S3_BVALID   (s3_axi_bvalid),
        .S3_BREADY   (s3_axi_bready),
        .S3_ARADDR   (s3_axi_araddr),
        .S3_ARVALID  (s3_axi_arvalid),
        .S3_ARREADY  (s3_axi_arready),
        .S3_RDATA    (s3_axi_rdata),
        .S3_RRESP    (s3_axi_rresp),
        .S3_RVALID   (s3_axi_rvalid),
        .S3_RREADY   (s3_axi_rready),
        .S4_AWADDR   (s4_axi_awaddr),
        .S4_AWVALID  (s4_axi_awvalid),
        .S4_AWREADY  (s4_axi_awready),
        .S4_WDATA    (s4_axi_wdata),
        .S4_WSTRB    (s4_axi_wstrb),
        .S4_WVALID   (s4_axi_wvalid),
        .S4_WREADY   (s4_axi_wready),
        .S4_BRESP    (s4_axi_bresp),
        .S4_BVALID   (s4_axi_bvalid),
        .S4_BREADY   (s4_axi_bready),
        .S4_ARADDR   (s4_axi_araddr),
        .S4_ARVALID  (s4_axi_arvalid),
        .S4_ARREADY  (s4_axi_arready),
        .S4_RDATA    (s4_axi_rdata),
        .S4_RRESP    (s4_axi_rresp),
        .S4_RVALID   (s4_axi_rvalid),
        .S4_RREADY   (s4_axi_rready),
        .S5_AWADDR   (s5_axi_awaddr),
        .S5_AWVALID  (s5_axi_awvalid),
        .S5_AWREADY  (s5_axi_awready),
        .S5_WDATA    (s5_axi_wdata),
        .S5_WSTRB    (s5_axi_wstrb),
        .S5_WVALID   (s5_axi_wvalid),
        .S5_WREADY   (s5_axi_wready),
        .S5_BRESP    (s5_axi_bresp),
        .S5_BVALID   (s5_axi_bvalid),
        .S5_BREADY   (s5_axi_bready),
        .S5_ARADDR   (s5_axi_araddr),
        .S5_ARVALID  (s5_axi_arvalid),
        .S5_ARREADY  (s5_axi_arready),
        .S5_RDATA    (s5_axi_rdata),
        .S5_RRESP    (s5_axi_rresp),
        .S5_RVALID   (s5_axi_rvalid),
        .S5_RREADY   (s5_axi_rready)
    );

    axi4lite_boot_rom boot_rom_i (
        .clk           (clk),
        .rst           (rst),
        .S_AXI_AWADDR  (s0_axi_awaddr),
        .S_AXI_AWVALID (s0_axi_awvalid),
        .S_AXI_AWREADY (s0_axi_awready),
        .S_AXI_WDATA   (s0_axi_wdata),
        .S_AXI_WSTRB   (s0_axi_wstrb),
        .S_AXI_WVALID  (s0_axi_wvalid),
        .S_AXI_WREADY  (s0_axi_wready),
        .S_AXI_BRESP   (s0_axi_bresp),
        .S_AXI_BVALID  (s0_axi_bvalid),
        .S_AXI_BREADY  (s0_axi_bready),
        .S_AXI_ARADDR  (s0_axi_araddr),
        .S_AXI_ARVALID (s0_axi_arvalid),
        .S_AXI_ARREADY (s0_axi_arready),
        .S_AXI_RDATA   (s0_axi_rdata),
        .S_AXI_RRESP   (s0_axi_rresp),
        .S_AXI_RVALID  (s0_axi_rvalid),
        .S_AXI_RREADY  (s0_axi_rready)
    );

    axi4lite_sram_slave program_sram_i (
        .clk           (clk),
        .rst           (rst_raw),
        .S_AXI_AWADDR  (ps_axi_awaddr),
        .S_AXI_AWVALID (ps_axi_awvalid),
        .S_AXI_AWREADY (ps_axi_awready),
        .S_AXI_WDATA   (ps_axi_wdata),
        .S_AXI_WSTRB   (ps_axi_wstrb),
        .S_AXI_WVALID  (ps_axi_wvalid),
        .S_AXI_WREADY  (ps_axi_wready),
        .S_AXI_BRESP   (ps_axi_bresp),
        .S_AXI_BVALID  (ps_axi_bvalid),
        .S_AXI_BREADY  (ps_axi_bready),
        .S_AXI_ARADDR  (ps_axi_araddr),
        .S_AXI_ARVALID (ps_axi_arvalid),
        .S_AXI_ARREADY (ps_axi_arready),
        .S_AXI_RDATA   (ps_axi_rdata),
        .S_AXI_RRESP   (ps_axi_rresp),
        .S_AXI_RVALID  (ps_axi_rvalid),
        .S_AXI_RREADY  (ps_axi_rready)
    );

    axi4lite_sram_slave data_sram_i (
        .clk           (clk),
        .rst           (rst),
        .S_AXI_AWADDR  (s2_axi_awaddr),
        .S_AXI_AWVALID (s2_axi_awvalid),
        .S_AXI_AWREADY (s2_axi_awready),
        .S_AXI_WDATA   (s2_axi_wdata),
        .S_AXI_WSTRB   (s2_axi_wstrb),
        .S_AXI_WVALID  (s2_axi_wvalid),
        .S_AXI_WREADY  (s2_axi_wready),
        .S_AXI_BRESP   (s2_axi_bresp),
        .S_AXI_BVALID  (s2_axi_bvalid),
        .S_AXI_BREADY  (s2_axi_bready),
        .S_AXI_ARADDR  (s2_axi_araddr),
        .S_AXI_ARVALID (s2_axi_arvalid),
        .S_AXI_ARREADY (s2_axi_arready),
        .S_AXI_RDATA   (s2_axi_rdata),
        .S_AXI_RRESP   (s2_axi_rresp),
        .S_AXI_RVALID  (s2_axi_rvalid),
        .S_AXI_RREADY  (s2_axi_rready)
    );

    axi4lite_timer_slave timer_i (
        .clk           (clk),
        .rst           (rst),
        .S_AXI_AWADDR  (s3_axi_awaddr),
        .S_AXI_AWVALID (s3_axi_awvalid),
        .S_AXI_AWREADY (s3_axi_awready),
        .S_AXI_WDATA   (s3_axi_wdata),
        .S_AXI_WSTRB   (s3_axi_wstrb),
        .S_AXI_WVALID  (s3_axi_wvalid),
        .S_AXI_WREADY  (s3_axi_wready),
        .S_AXI_BRESP   (s3_axi_bresp),
        .S_AXI_BVALID  (s3_axi_bvalid),
        .S_AXI_BREADY  (s3_axi_bready),
        .S_AXI_ARADDR  (s3_axi_araddr),
        .S_AXI_ARVALID (s3_axi_arvalid),
        .S_AXI_ARREADY (s3_axi_arready),
        .S_AXI_RDATA   (s3_axi_rdata),
        .S_AXI_RRESP   (s3_axi_rresp),
        .S_AXI_RVALID  (s3_axi_rvalid),
        .S_AXI_RREADY  (s3_axi_rready),
        .timer_irq     (timer_irq_internal)
    );

    axi4lite_gpio_slave #(
        .GPIO_WIDTH (8)
    ) gpio_i (
        .clk           (clk),
        .rst           (rst),
        .S_AXI_AWADDR  (s4_axi_awaddr),
        .S_AXI_AWVALID (s4_axi_awvalid),
        .S_AXI_AWREADY (s4_axi_awready),
        .S_AXI_WDATA   (s4_axi_wdata),
        .S_AXI_WSTRB   (s4_axi_wstrb),
        .S_AXI_WVALID  (s4_axi_wvalid),
        .S_AXI_WREADY  (s4_axi_wready),
        .S_AXI_BRESP   (s4_axi_bresp),
        .S_AXI_BVALID  (s4_axi_bvalid),
        .S_AXI_BREADY  (s4_axi_bready),
        .S_AXI_ARADDR  (s4_axi_araddr),
        .S_AXI_ARVALID (s4_axi_arvalid),
        .S_AXI_ARREADY (s4_axi_arready),
        .S_AXI_RDATA   (s4_axi_rdata),
        .S_AXI_RRESP   (s4_axi_rresp),
        .S_AXI_RVALID  (s4_axi_rvalid),
        .S_AXI_RREADY  (s4_axi_rready),
        .gpio_in       (gpio_in),
        .gpio_out      (gpio_out),
        .gpio_oe       (gpio_oe),
        .debug_out     (debug_out)
    );

    axi4lite_spi_slave spi_i (
        .clk           (clk),
        .rst           (rst),
        .S_AXI_AWADDR  (s5_axi_awaddr),
        .S_AXI_AWVALID (s5_axi_awvalid),
        .S_AXI_AWREADY (s5_axi_awready),
        .S_AXI_WDATA   (s5_axi_wdata),
        .S_AXI_WSTRB   (s5_axi_wstrb),
        .S_AXI_WVALID  (s5_axi_wvalid),
        .S_AXI_WREADY  (s5_axi_wready),
        .S_AXI_BRESP   (s5_axi_bresp),
        .S_AXI_BVALID  (s5_axi_bvalid),
        .S_AXI_BREADY  (s5_axi_bready),
        .S_AXI_ARADDR  (s5_axi_araddr),
        .S_AXI_ARVALID (s5_axi_arvalid),
        .S_AXI_ARREADY (s5_axi_arready),
        .S_AXI_RDATA   (s5_axi_rdata),
        .S_AXI_RRESP   (s5_axi_rresp),
        .S_AXI_RVALID  (s5_axi_rvalid),
        .S_AXI_RREADY  (s5_axi_rready),
        .spi_sclk      (spi_sclk),
        .spi_mosi      (spi_mosi),
        .spi_miso      (spi_miso),
        .spi_irq       (spi_irq_internal),
        .spi_cs_n      (spi_cs_n)
    );

endmodule
