`timescale 1ns/1ps

// ============================================================================
// Testbench : tb_rv32i_chip_top_ecall_ebreak
// Purpose   : Directed ECALL/EBREAK trap test for final RV32I SoC top.
// Top used  : rv32i_chip_top_spi_boot with boot_en_pad=0
//             This keeps the final chip-level top in the compile, but bypasses
//             SPI loading so Program SRAM can be preloaded directly for a fast
//             exception/trap check.
//
// Test flow per case:
//   1. Preload Program SRAM with small program while reset is active.
//   2. Program sets mtvec = 0x0001_0080.
//   3. Program executes ECALL or EBREAK.
//   4. Trap redirects to handler at mtvec.
//   5. Handler reads mcause and writes it to GPIO DEBUG register.
//   6. PASS when DEBUG_OUT equals expected mcause.
//
// Expected causes:
//   ECALL from M-mode : mcause = 11
//   EBREAK           : mcause = 3
// ============================================================================

module tb_rv32i_chip_top_ecall_ebreak;

    reg         clk_pad;
    reg         rst_n_pad;

    reg         boot_en_pad;
    reg         boot_spi_sclk_pad;
    reg         boot_spi_mosi_pad;
    wire        boot_spi_miso_pad;
    reg         boot_spi_cs_n_pad;
    wire        loader_done_pad;
    wire        cpu_rst_dbg_pad;

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
    reg saw_trap;
    reg bad_zero_write;

    rv32i_chip_top_spi_boot dut (
        .clk_pad             (clk_pad),
        .rst_n_pad           (rst_n_pad),
        .boot_en_pad         (boot_en_pad),
        .boot_spi_sclk_pad   (boot_spi_sclk_pad),
        .boot_spi_mosi_pad   (boot_spi_mosi_pad),
        .boot_spi_miso_pad   (boot_spi_miso_pad),
        .boot_spi_cs_n_pad   (boot_spi_cs_n_pad),
        .loader_done_pad     (loader_done_pad),
        .cpu_rst_dbg_pad     (cpu_rst_dbg_pad),
        .jtag_irq_pad        (jtag_irq_pad),
        .gpio_in_pad         (gpio_in_pad),
        .gpio_out_pad        (gpio_out_pad),
        .gpio_oe_pad         (gpio_oe_pad),
        .debug_out_pad       (debug_out_pad),
        .spi_sclk_pad        (spi_sclk_pad),
        .spi_mosi_pad        (spi_mosi_pad),
        .spi_miso_pad        (spi_miso_pad),
        .spi_cs_n_pad        (spi_cs_n_pad),
        .pc_debug_pad        (pc_debug_pad),
        .inst_debug_pad      (inst_debug_pad),
        .trap_taken_pad      (trap_taken_pad),
        .timer_irq_dbg_pad   (timer_irq_dbg_pad)
    );

    initial begin
        clk_pad = 1'b0;
        forever #5 clk_pad = ~clk_pad;
    end

    task clear_memories;
        begin
            for (i = 0; i < 1024; i = i + 1) begin
                dut.soc_i.program_sram_i.sram_macro.ram.memory[i] = 36'h0_00000013; // NOP
                dut.soc_i.data_sram_i.sram_macro.ram.memory[i]    = 36'h0_00000000;
            end
        end
    endtask

    task preload_exception_program;
        input [31:0] trap_inst;
        begin
            clear_memories;

            // Program SRAM base = 0x0001_0000.
            // First 3 words are intentional startup NOP/fetch-latency slots.
            dut.soc_i.program_sram_i.sram_macro.ram.memory[0]  = 36'h0_00000013;
            dut.soc_i.program_sram_i.sram_macro.ram.memory[1]  = 36'h0_00000013;
            dut.soc_i.program_sram_i.sram_macro.ram.memory[2]  = 36'h0_00000013;

            // Main program.
            dut.soc_i.program_sram_i.sram_macro.ram.memory[3]  = 36'h0_100010B7; // lui   x1, 0x10001 ; GPIO base 0x10001000
            dut.soc_i.program_sram_i.sram_macro.ram.memory[4]  = 36'h0_00000013;
            dut.soc_i.program_sram_i.sram_macro.ram.memory[5]  = 36'h0_00000013;

            dut.soc_i.program_sram_i.sram_macro.ram.memory[6]  = 36'h0_000102B7; // lui   x5, 0x00010 ; x5=0x00010000
            dut.soc_i.program_sram_i.sram_macro.ram.memory[7]  = 36'h0_00000013;
            dut.soc_i.program_sram_i.sram_macro.ram.memory[8]  = 36'h0_00000013;

            dut.soc_i.program_sram_i.sram_macro.ram.memory[9]  = 36'h0_08028293; // addi  x5, x5, 0x080 ; x5=0x00010080
            dut.soc_i.program_sram_i.sram_macro.ram.memory[10] = 36'h0_00000013;
            dut.soc_i.program_sram_i.sram_macro.ram.memory[11] = 36'h0_00000013;

            dut.soc_i.program_sram_i.sram_macro.ram.memory[12] = 36'h0_30529073; // csrrw x0, mtvec, x5
            dut.soc_i.program_sram_i.sram_macro.ram.memory[13] = 36'h0_00000013;
            dut.soc_i.program_sram_i.sram_macro.ram.memory[14] = 36'h0_00000013;

            dut.soc_i.program_sram_i.sram_macro.ram.memory[15] = {4'h0, trap_inst}; // ECALL or EBREAK
            dut.soc_i.program_sram_i.sram_macro.ram.memory[16] = 36'h0_00000013;
            dut.soc_i.program_sram_i.sram_macro.ram.memory[17] = 36'h0_00000013;
            dut.soc_i.program_sram_i.sram_macro.ram.memory[18] = 36'h0_0000006F; // should not be reached; loop if trap fails

            // Trap vector starts exactly at 0x0001_0080 => Program SRAM index 32.
            // After the processor PC/redirect fix, the first instruction at
            // the trap target must execute. Do not keep artificial delay slots
            // here; RISC-V has no architectural branch/trap delay slot.
            dut.soc_i.program_sram_i.sram_macro.ram.memory[32] = 36'h0_34202373; // csrrs x6, mcause, x0 ; read mcause
            dut.soc_i.program_sram_i.sram_macro.ram.memory[33] = 36'h0_00000013;
            dut.soc_i.program_sram_i.sram_macro.ram.memory[34] = 36'h0_00000013;

            dut.soc_i.program_sram_i.sram_macro.ram.memory[35] = 36'h0_0060A623; // sw    x6, 12(x1) ; DEBUG_OUT=mcause
            dut.soc_i.program_sram_i.sram_macro.ram.memory[36] = 36'h0_00000013;
            dut.soc_i.program_sram_i.sram_macro.ram.memory[37] = 36'h0_00000013;

            dut.soc_i.program_sram_i.sram_macro.ram.memory[38] = 36'h0_0060A023; // sw    x6, 0(x1) ; GPIO_OUT=mcause[7:0]
            dut.soc_i.program_sram_i.sram_macro.ram.memory[39] = 36'h0_00000013;
            dut.soc_i.program_sram_i.sram_macro.ram.memory[40] = 36'h0_00000013;

            dut.soc_i.program_sram_i.sram_macro.ram.memory[41] = 36'h0_0000006F; // loop
        end
    endtask

    task run_case;
        input [31:0] trap_inst;
        input [31:0] expected_mcause;
        input [127:0] case_name;
        integer cycles;
        begin
            $display("\n[TB] Starting %0s test. Expected mcause=%0d", case_name, expected_mcause);

            rst_n_pad      = 1'b0;
            saw_trap       = 1'b0;
            bad_zero_write = 1'b0;

            #120;
            preload_exception_program(trap_inst);
            #80;
            rst_n_pad = 1'b1;

            cycles = 0;
            while (cycles < 4000) begin
                @(posedge clk_pad);
                cycles = cycles + 1;

                if (debug_out_pad === expected_mcause && saw_trap && !bad_zero_write) begin
                    $display("[TB][PASS] %0s trap PASS: mcause/debug=%h gpio_out=%h pc=%h inst=%h",
                             case_name, debug_out_pad, gpio_out_pad, pc_debug_pad, inst_debug_pad);
                    cycles = 4000;
                end
            end

            if (!(debug_out_pad === expected_mcause && saw_trap && !bad_zero_write)) begin
                $display("[TB][FAIL] %0s trap FAIL", case_name);
                $display("[TB] debug_out=%h expected=%h saw_trap=%b bad_zero_write=%b pc=%h inst=%h trap=%b",
                         debug_out_pad, expected_mcause, saw_trap, bad_zero_write,
                         pc_debug_pad, inst_debug_pad, trap_taken_pad);
                $finish;
            end

            // Hold reset low between cases so GPIO/CSR/core registers clear.
            rst_n_pad = 1'b0;
            #200;
        end
    endtask

    initial begin
        boot_en_pad       = 1'b0; // bypass SPI loader; direct preload for fast final-top exception test
        boot_spi_sclk_pad = 1'b0;
        boot_spi_mosi_pad = 1'b0;
        boot_spi_cs_n_pad = 1'b1;
        jtag_irq_pad      = 1'b0;
        gpio_in_pad       = 8'h00;
        spi_miso_pad      = 1'b0;
        rst_n_pad         = 1'b0;

        run_case(32'h00000073, 32'd11, "ECALL");
        run_case(32'h00100073, 32'd3,  "EBREAK");

        $display("\n[TB][PASS_ALL] ECALL and EBREAK final SoC trap tests PASS");
        #100;
        $finish;
    end

    always @(posedge clk_pad) begin
        if (rst_n_pad) begin
            if (trap_taken_pad) begin
                saw_trap <= 1'b1;
                $display("[TB] TRAP_TAKEN T=%0t PC=%h INST=%h EPC/MTVEC=%h MCAUSE=%h",
                         $time, pc_debug_pad, inst_debug_pad,
                         dut.soc_i.core.csr_reg_i.epc,
                         dut.soc_i.core.csr_reg_i.csr_mem[4]);
            end

            if (dut.soc_i.mem_we) begin
                $display("[TB] MEM_WRITE  T=%0t ADDR=%h DATA=%h",
                         $time, dut.soc_i.mem_addr, dut.soc_i.mem_wdata);
                if (dut.soc_i.mem_addr < 32'h0001_0000) begin
                    bad_zero_write <= 1'b1;
                    $display("[TB][BAD_ZERO_WRITE] T=%0t ADDR=%h DATA=%h",
                             $time, dut.soc_i.mem_addr, dut.soc_i.mem_wdata);
                end
            end

            if (dut.soc_i.axi_ic_i.S4_AWVALID && dut.soc_i.axi_ic_i.S4_WVALID) begin
                $display("[TB] GPIO_AXI_WRITE T=%0t ADDR=%h DATA=%h WSTRB=%b",
                         $time,
                         dut.soc_i.axi_ic_i.S4_AWADDR,
                         dut.soc_i.axi_ic_i.S4_WDATA,
                         dut.soc_i.axi_ic_i.S4_WSTRB);
            end
        end
    end

endmodule
