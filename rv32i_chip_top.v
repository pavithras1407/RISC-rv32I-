`timescale 1ns/1fs

// ============================================================================
// Module : rv32i_chip_top
// Purpose:
//   Abstract chip-level wrapper for Stage-1 RV32I SoC.
//
// Notes:
//   - In a real ASIC flow, foundry pad cells and scan ports are added here.
//   - This wrapper intentionally keeps IO simple and synthesizable.
//   - Replace direct ports with pad-cell instances during physical design.
// ============================================================================

module rv32i_chip_top (
    input             clk_pad,
    input             rst_n_pad,

    input             jtag_irq_pad,

    input      [ 7:0] gpio_in_pad,
    output     [ 7:0] gpio_out_pad,
    output     [ 7:0] gpio_oe_pad,
    output     [31:0] debug_out_pad,

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

    rv32i_soc_top soc_i (
        .clk            (clk_pad),
        .rst_n          (rst_n_pad),
        .jtag_irq       (jtag_irq_pad),
        .gpio_in        (gpio_in_pad),
        .gpio_out       (gpio_out_pad),
        .gpio_oe        (gpio_oe_pad),
        .debug_out      (debug_out_pad),
        .spi_sclk       (spi_sclk_pad),
        .spi_mosi       (spi_mosi_pad),
        .spi_miso       (spi_miso_pad),
        .spi_cs_n       (spi_cs_n_pad),
        .pc_debug       (pc_debug_pad),
        .inst_debug     (inst_debug_pad),
        .rf_we          (rf_we_unused),
        .rf_waddr       (rf_waddr_unused),
        .rf_wdata       (rf_wdata_unused),
        .mem_we         (mem_we_unused),
        .mem_re         (mem_re_unused),
        .mem_addr       (mem_addr_unused),
        .mem_wdata      (mem_wdata_unused),
        .mem_rdata      (mem_rdata_unused),
        .br_taken_dbg   (br_taken_dbg_unused),
        .trap_taken     (trap_taken_pad),
        .epc_debug      (epc_debug_unused),
        .timer_irq_dbg  (timer_irq_dbg_pad)
    );

endmodule
