`timescale 1ns/1fs

module processor_top (
    input             clk,
    input             rst,
    input             spi_irq,
    input             jtag_irq,

    // retire-stage monitor / debug outputs (passed through from the core)
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
    output            timer_irq_dbg
);

    // ============================================================
    // Instruction memory ready/valid interface
    // ============================================================
    wire        imem_req;
    wire [31:0] imem_addr;
    wire        imem_ready;
    wire [31:0] imem_rdata;

    // ============================================================
    // Data memory ready/valid interface
    // ============================================================
    wire        dmem_req;
    wire        dmem_wr;
    wire [31:0] dmem_addr;
    wire [ 2:0] dmem_acc_mode;
    wire [31:0] dmem_wdata;
    wire        dmem_ready;
    wire [31:0] dmem_rdata;

    wire        illegal_inst_dbg;

    // ============================================================
    // Temporary SRAM-ready mode
    // For current SRAM simulation, memories are treated as always ready.
    // Later AXI wrapper will generate these ready signals.
    // ============================================================
    assign imem_ready = 1'b1;
    assign dmem_ready = 1'b1;

    // ============================================================
    // External instruction memory
    // ============================================================
    imem_sram_wrap inst_mem_i (
        .clk  (clk),
        .addr (imem_addr),
        .data (imem_rdata)
    );

    // ============================================================
    // External data memory
    // Convert new ready/valid request into old rd_en/wr_en memory controls
    // ============================================================
    data_mem data_mem_i (
        .clk          (clk),
        .rst          (rst),
        .rd_en        (dmem_req & ~dmem_wr),
        .wr_en        (dmem_req &  dmem_wr),
        .addr         (dmem_addr),
        .mem_acc_mode (dmem_acc_mode),
        .wdata        (dmem_wdata),
        .rdata        (dmem_rdata)
    );

    // ============================================================
    // Processor core
    // ============================================================
    processor core (
        .clk           (clk),
        .rst           (rst),
         .spi_irq(spi_irq),
        .jtag_irq      (jtag_irq),

        // instruction memory ready/valid interface
        .imem_req      (imem_req),
        .imem_addr     (imem_addr),
        .imem_ready    (imem_ready),
        .imem_rdata    (imem_rdata),

        // data memory ready/valid interface
        .dmem_req      (dmem_req),
        .dmem_wr       (dmem_wr),
        .dmem_addr     (dmem_addr),
        .dmem_acc_mode (dmem_acc_mode),
        .dmem_wdata    (dmem_wdata),
        .dmem_ready    (dmem_ready),
        .dmem_rdata    (dmem_rdata),

        // debug / monitor outputs
        .pc_debug      (pc_debug),
        .inst_debug    (inst_debug),
        .rf_we         (rf_we),
        .rf_waddr      (rf_waddr),
        .rf_wdata      (rf_wdata),
        .mem_we        (mem_we),
        .mem_re        (mem_re),
        .mem_addr      (mem_addr),
        .mem_wdata     (mem_wdata),
        .mem_rdata     (mem_rdata),
        .br_taken_dbg  (br_taken_dbg),
        .trap_taken    (trap_taken),
        .epc_debug     (epc_debug),
        .timer_irq_dbg (timer_irq_dbg),
        .illegal_inst_dbg (illegal_inst_dbg)
    );

endmodule
