`timescale 1ns/1ps

// Focused SoC test: AUIPC, JAL, JALR, link writeback, x0, DEBUG_OUT.
// No timer, no SPI, no CSR tail. This isolates PC-relative RTL behavior.
module tb_rv32i_auipc_jal_jalr_focus;
    reg         clk_pad;
    reg         rst_n_pad;
    reg         jtag_irq_pad;
    reg  [7:0]  gpio_in_pad;
    wire [7:0]  gpio_out_pad;
    wire [7:0]  gpio_oe_pad;
    wire [31:0] debug_out_pad;
    wire        spi_sclk_pad;
    wire        spi_mosi_pad;
    reg         spi_miso_pad;
    wire        spi_cs_n_pad;
    wire [31:0] pc_debug_pad;
    wire [31:0] inst_debug_pad;
    wire        trap_taken_pad;
    wire        timer_irq_dbg_pad;

    integer i;
    integer errors;
    reg [31:0] got;
    localparam [31:0] PASS_SIG = 32'hC0FF_EE00;

    rv32i_chip_top dut (
        .clk_pad          (clk_pad),
        .rst_n_pad        (rst_n_pad),
        .jtag_irq_pad     (jtag_irq_pad),
        .gpio_in_pad      (gpio_in_pad),
        .gpio_out_pad     (gpio_out_pad),
        .gpio_oe_pad      (gpio_oe_pad),
        .debug_out_pad    (debug_out_pad),
        .spi_sclk_pad     (spi_sclk_pad),
        .spi_mosi_pad     (spi_mosi_pad),
        .spi_miso_pad     (spi_miso_pad),
        .spi_cs_n_pad     (spi_cs_n_pad),
        .pc_debug_pad     (pc_debug_pad),
        .inst_debug_pad   (inst_debug_pad),
        .trap_taken_pad   (trap_taken_pad),
        .timer_irq_dbg_pad(timer_irq_dbg_pad)
    );

    `include "rv32i_auipc_jal_jalr_expected.vh"

    initial begin
        clk_pad = 1'b0;
        forever #5 clk_pad = ~clk_pad;
    end

    task preload_program;
        begin
            for (i = 0; i < 1024; i = i + 1) begin
                dut.soc_i.program_sram_i.sram_macro.ram.memory[i] = 36'h0_00000013;
                dut.soc_i.data_sram_i.sram_macro.ram.memory[i]    = 36'h0_00000000;
            end
            `include "rv32i_auipc_jal_jalr_preload.vh"
            $display("[TB] Focused AUIPC/JAL/JALR program loaded.");
        end
    endtask

    task check_results;
        begin
            errors = 0;
            for (i = 0; i < NUM_EXPECTED; i = i + 1) begin
                got = dut.soc_i.data_sram_i.sram_macro.ram.memory[exp_addr[i][11:2]][31:0];
                if ((got & exp_mask[i]) !== (exp_value[i] & exp_mask[i])) begin
                    $display("[TB][FAIL] RESULT[%0d] ADDR=%h INDEX=%0d EXPECT=%h MASK=%h GOT=%h",
                             i, exp_addr[i], exp_addr[i][11:2], exp_value[i], exp_mask[i], got);
                    errors = errors + 1;
                end else begin
                    $display("[TB][OK]   RESULT[%0d] ADDR=%h VALUE=%h", i, exp_addr[i], got);
                end
            end
            if (debug_out_pad !== PASS_SIG) begin
                $display("[TB][FAIL] DEBUG_OUT expected %h got %h", PASS_SIG, debug_out_pad);
                errors = errors + 1;
            end
            if (trap_taken_pad !== 1'b0) begin
                $display("[TB][FAIL] Unexpected trap_taken_pad=1 PC=%h INST=%h", pc_debug_pad, inst_debug_pad);
                errors = errors + 1;
            end
            $display("[TB] Final PC=%h INST=%h DEBUG_OUT=%h TRAP=%b TIMER_IRQ=%b", pc_debug_pad, inst_debug_pad, debug_out_pad, trap_taken_pad, timer_irq_dbg_pad);
            if (errors == 0)
                $display("[TB][PASS_ALL] Focused AUIPC/JAL/JALR SoC test PASS");
            else
                $display("[TB][FAIL_ALL] Focused AUIPC/JAL/JALR SoC test FAIL errors=%0d", errors);
        end
    endtask

    initial begin
        rst_n_pad    = 1'b0;
        jtag_irq_pad = 1'b0;
        gpio_in_pad  = 8'h00;
        spi_miso_pad = 1'b0;
        #120;
        preload_program;
        #80;
        $display("[TB] Releasing reset.");
        rst_n_pad = 1'b1;

        repeat (30000) begin
            @(posedge clk_pad);
            if (debug_out_pad === PASS_SIG) begin
                $display("[TB] PASS signature observed at T=%0t", $time);
                repeat (20) @(posedge clk_pad);
                check_results;
                $finish;
            end
        end

        $display("[TB][TIMEOUT] PASS signature not seen. PC=%h INST=%h DEBUG=%h TRAP=%b", pc_debug_pad, inst_debug_pad, debug_out_pad, trap_taken_pad);
        check_results;
        $finish;
    end
endmodule
