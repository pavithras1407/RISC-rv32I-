`timescale 1ns/1fs

// ============================================================================
// Module : rv32i_chip_top_spi_boot
// Purpose:
//   Chip-level wrapper for Stage-3 RV32I SoC with SPI program loader.
//
// Boot SPI pins are separate from the normal CPU-controlled SPI peripheral.
// During boot_en=1, the CPU is held in reset until the boot SPI loader receives
// a DONE frame. The loader writes Program SRAM through a muxed AXI4-Lite port.
// ============================================================================

module rv32i_chip_top_spi_boot (
    input             clk_pad,
    input             rst_n_pad,

    input             boot_en_pad,
    input             boot_spi_sclk_pad,
    input             boot_spi_mosi_pad,
    output            boot_spi_miso_pad,
    input             boot_spi_cs_n_pad,
    output            loader_done_pad,
    output            cpu_rst_dbg_pad,

    input             jtag_irq_pad,

    input      [ 7:0] gpio_in_pad,
    output     [ 7:0] gpio_out_pad,
    output     [ 7:0] gpio_oe_pad,
    output     [31:0] debug_out_pad,

    // Normal CPU-accessed SPI peripheral pins.
    output            spi_sclk_pad,
    output            spi_mosi_pad,
    input             spi_miso_pad,
    output            spi_cs_n_pad,

    output     [31:0] pc_debug_pad,
    output     [31:0] inst_debug_pad,
    output            trap_taken_pad,
    output            timer_irq_dbg_pad
);

    wire        rf_we_unused;
    wire [ 4:0] rf_waddr_unused;
    wire [31:0] rf_wdata_unused;
    wire        mem_we_unused;
    wire        mem_re_unused;
    wire [31:0] mem_addr_unused;
    wire [31:0] mem_wdata_unused;
    wire [31:0] mem_rdata_unused;
    wire        br_taken_dbg_unused;
    wire [31:0] epc_debug_unused;

    rv32i_soc_top_spi_boot soc_i (
        .clk              (clk_pad),
        .rst_n            (rst_n_pad),
        .boot_en          (boot_en_pad),
        .boot_spi_sclk    (boot_spi_sclk_pad),
        .boot_spi_mosi    (boot_spi_mosi_pad),
        .boot_spi_miso    (boot_spi_miso_pad),
        .boot_spi_cs_n    (boot_spi_cs_n_pad),
        .jtag_irq         (jtag_irq_pad),
        .gpio_in          (gpio_in_pad),
        .gpio_out         (gpio_out_pad),
        .gpio_oe          (gpio_oe_pad),
        .debug_out        (debug_out_pad),
        .spi_sclk         (spi_sclk_pad),
        .spi_mosi         (spi_mosi_pad),
        .spi_miso         (spi_miso_pad),
        .spi_cs_n         (spi_cs_n_pad),
        .pc_debug         (pc_debug_pad),
        .inst_debug       (inst_debug_pad),
        .rf_we            (rf_we_unused),
        .rf_waddr         (rf_waddr_unused),
        .rf_wdata         (rf_wdata_unused),
        .mem_we           (mem_we_unused),
        .mem_re           (mem_re_unused),
        .mem_addr         (mem_addr_unused),
        .mem_wdata        (mem_wdata_unused),
        .mem_rdata        (mem_rdata_unused),
        .br_taken_dbg     (br_taken_dbg_unused),
        .trap_taken       (trap_taken_pad),
        .epc_debug        (epc_debug_unused),
        .timer_irq_dbg    (timer_irq_dbg_pad),
        .loader_done      (loader_done_pad),
        .cpu_rst_dbg      (cpu_rst_dbg_pad)
    );

endmodule
