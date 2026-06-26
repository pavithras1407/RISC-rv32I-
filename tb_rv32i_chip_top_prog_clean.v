`timescale 1ns/1ps

// ============================================================================
// Testbench : tb_rv32i_chip_top_prog_clean
// Purpose   : Stage-2B clean single-block program execution test for RV32I SoC.
// Requires  : v4 AXI handshake fixed processor_soc.v and rv32i_axi_master_wrapper.v
//
// Difference from Stage-2 v5:
//   - No repeated program blocks.
//   - Single program is placed once in Program SRAM.
//   - First three words are NOPs because after Boot ROM jump the current
//     synchronous fetch path starts useful execution after a few latency slots.
//   - Flags any store to address 0x0000_0000 / 0x0000_0004 / 0x0000_000C.
//   - PASS only if GPIO_OUT=A5, GPIO_OE=FF, DEBUG_OUT=12345678 and no bad store.
// ============================================================================

module tb_rv32i_chip_top_prog_clean;

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
    reg bad_zero_write;

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

    // 100 MHz clock, 10 ns period
    initial begin
        clk_pad = 1'b0;
        forever #5 clk_pad = ~clk_pad;
    end

    task preload_single_clean_program;
        begin
            for (i = 0; i < 1024; i = i + 1) begin
                dut.soc_i.program_sram_i.sram_macro.ram.memory[i] = 36'h0_00000013; // NOP
                dut.soc_i.data_sram_i.sram_macro.ram.memory[i]    = 36'h0_00000000;
            end

            // Single clean program block.
            // Program SRAM base = 0x0001_0000.
            // The first 3 words are intentional NOP fetch-latency slots.
            // Real program starts at index 3 / address 0x0001_000C.
            dut.soc_i.program_sram_i.sram_macro.ram.memory[0]  = 36'h0_00000013; // nop / latency slot
            dut.soc_i.program_sram_i.sram_macro.ram.memory[1]  = 36'h0_00000013; // nop / latency slot
            dut.soc_i.program_sram_i.sram_macro.ram.memory[2]  = 36'h0_00000013; // nop / latency slot

            dut.soc_i.program_sram_i.sram_macro.ram.memory[3]  = 36'h0_100010B7; // lui  x1, 0x10001 ; x1=0x10001000
            dut.soc_i.program_sram_i.sram_macro.ram.memory[4]  = 36'h0_00000013; // nop
            dut.soc_i.program_sram_i.sram_macro.ram.memory[5]  = 36'h0_00000013; // nop
            dut.soc_i.program_sram_i.sram_macro.ram.memory[6]  = 36'h0_0A500113; // addi x2, x0, 0x0A5
            dut.soc_i.program_sram_i.sram_macro.ram.memory[7]  = 36'h0_00000013; // nop
            dut.soc_i.program_sram_i.sram_macro.ram.memory[8]  = 36'h0_00000013; // nop
            dut.soc_i.program_sram_i.sram_macro.ram.memory[9]  = 36'h0_0020A023; // sw   x2, 0(x1)   ; GPIO_OUT=A5

            dut.soc_i.program_sram_i.sram_macro.ram.memory[10] = 36'h0_00000013; // nop
            dut.soc_i.program_sram_i.sram_macro.ram.memory[11] = 36'h0_00000013; // nop
            dut.soc_i.program_sram_i.sram_macro.ram.memory[12] = 36'h0_0FF00193; // addi x3, x0, 0x0FF
            dut.soc_i.program_sram_i.sram_macro.ram.memory[13] = 36'h0_00000013; // nop
            dut.soc_i.program_sram_i.sram_macro.ram.memory[14] = 36'h0_00000013; // nop
            dut.soc_i.program_sram_i.sram_macro.ram.memory[15] = 36'h0_0030A223; // sw   x3, 4(x1)   ; GPIO_OE=FF

            dut.soc_i.program_sram_i.sram_macro.ram.memory[16] = 36'h0_00000013; // nop
            dut.soc_i.program_sram_i.sram_macro.ram.memory[17] = 36'h0_00000013; // nop
            dut.soc_i.program_sram_i.sram_macro.ram.memory[18] = 36'h0_12345237; // lui  x4, 0x12345
            dut.soc_i.program_sram_i.sram_macro.ram.memory[19] = 36'h0_00000013; // nop
            dut.soc_i.program_sram_i.sram_macro.ram.memory[20] = 36'h0_00000013; // nop
            dut.soc_i.program_sram_i.sram_macro.ram.memory[21] = 36'h0_67820213; // addi x4, x4, 0x678 ; x4=0x12345678
            dut.soc_i.program_sram_i.sram_macro.ram.memory[22] = 36'h0_00000013; // nop
            dut.soc_i.program_sram_i.sram_macro.ram.memory[23] = 36'h0_00000013; // nop
            dut.soc_i.program_sram_i.sram_macro.ram.memory[24] = 36'h0_0040A623; // sw   x4, 12(x1)  ; DEBUG_OUT=12345678
            dut.soc_i.program_sram_i.sram_macro.ram.memory[25] = 36'h0_00000013; // nop
            dut.soc_i.program_sram_i.sram_macro.ram.memory[26] = 36'h0_00000013; // nop
            dut.soc_i.program_sram_i.sram_macro.ram.memory[27] = 36'h0_0000006F; // jal  x0, 0       ; loop

            $display("[TB] Stage-2B single clean program preload done while reset is active.");
            $display("[TB] IMEM[3]=%h IMEM[6]=%h IMEM[9]=%h IMEM[12]=%h IMEM[15]=%h IMEM[18]=%h IMEM[21]=%h IMEM[24]=%h",
                dut.soc_i.program_sram_i.sram_macro.ram.memory[3],
                dut.soc_i.program_sram_i.sram_macro.ram.memory[6],
                dut.soc_i.program_sram_i.sram_macro.ram.memory[9],
                dut.soc_i.program_sram_i.sram_macro.ram.memory[12],
                dut.soc_i.program_sram_i.sram_macro.ram.memory[15],
                dut.soc_i.program_sram_i.sram_macro.ram.memory[18],
                dut.soc_i.program_sram_i.sram_macro.ram.memory[21],
                dut.soc_i.program_sram_i.sram_macro.ram.memory[24]);
        end
    endtask

    initial begin
        rst_n_pad      = 1'b0;
        jtag_irq_pad   = 1'b0;
        gpio_in_pad    = 8'h00;
        spi_miso_pad   = 1'b0;
        bad_zero_write = 1'b0;

        // Wait until reset synchronizer and SRAM model settle.
        #120;
        preload_single_clean_program;

        #80;
        $display("[TB] Releasing reset now.");
        rst_n_pad = 1'b1;

        // Run until pass or timeout.
        #20000;

        $display("[TB] Final PC        = %h", pc_debug_pad);
        $display("[TB] Final INST      = %h", inst_debug_pad);
        $display("[TB] GPIO OUT        = %h", gpio_out_pad);
        $display("[TB] GPIO OE         = %h", gpio_oe_pad);
        $display("[TB] DEBUG OUT       = %h", debug_out_pad);
        $display("[TB] BAD ZERO WRITE  = %b", bad_zero_write);
        $display("[TB] TRAP TAKEN      = %b", trap_taken_pad);
        $display("[TB] TIMER IRQ DBG   = %b", timer_irq_dbg_pad);

        if (gpio_out_pad === 8'hA5 && gpio_oe_pad === 8'hFF && debug_out_pad === 32'h12345678 && bad_zero_write === 1'b0) begin
            $display("[TB][PASS] Clean single-block boot/program/GPIO test works with no zero-address store.");
        end else begin
            $display("[TB][FAIL] Expected GPIO_OUT=A5 GPIO_OE=FF DEBUG_OUT=12345678 and no zero-address store.");
        end

        $finish;
    end

    always @(posedge clk_pad) begin
        if (rst_n_pad) begin
            if ((pc_debug_pad >= 32'h0001_0000) && (pc_debug_pad <= 32'h0001_0100)) begin
                $display("T=%0t PC=%h INST=%h GPIO=%h OE=%h DBG=%h TRAP=%b",
                         $time, pc_debug_pad, inst_debug_pad, gpio_out_pad,
                         gpio_oe_pad, debug_out_pad, trap_taken_pad);
            end

            if (dut.soc_i.mem_we) begin
                $display("[TB] MEM_WRITE     T=%0t ADDR=%h DATA=%h",
                         $time, dut.soc_i.mem_addr, dut.soc_i.mem_wdata);
                if (dut.soc_i.mem_addr < 32'h0001_0000) begin
                    bad_zero_write <= 1'b1;
                    $display("[TB][BAD_ZERO_WRITE] T=%0t ADDR=%h DATA=%h",
                             $time, dut.soc_i.mem_addr, dut.soc_i.mem_wdata);
                end
            end

            if (dut.soc_i.axi_ic_i.S1_ARVALID && dut.soc_i.axi_ic_i.S1_ARREADY) begin
                $display("[TB] S1_AR         T=%0t ADDR=%h INDEX=%0d",
                         $time,
                         dut.soc_i.axi_ic_i.S1_ARADDR,
                         dut.soc_i.axi_ic_i.S1_ARADDR[11:2]);
            end

            if (dut.soc_i.axi_ic_i.S1_RVALID) begin
                $display("[TB] S1_READ       T=%0t RDATA=%h DIRECT_MEM=%h",
                         $time,
                         dut.soc_i.s1_axi_rdata,
                         dut.soc_i.program_sram_i.sram_macro.ram.memory[dut.soc_i.s1_axi_araddr[11:2]]);
            end

            if (dut.soc_i.axi_ic_i.S4_AWVALID && dut.soc_i.axi_ic_i.S4_WVALID) begin
                $display("[TB] GPIO_AXI_WRITE T=%0t ADDR=%h DATA=%h WSTRB=%b",
                         $time,
                         dut.soc_i.axi_ic_i.S4_AWADDR,
                         dut.soc_i.axi_ic_i.S4_WDATA,
                         dut.soc_i.axi_ic_i.S4_WSTRB);
            end

            if (gpio_out_pad === 8'hA5 && gpio_oe_pad === 8'hFF && debug_out_pad === 32'h12345678 && bad_zero_write === 1'b0) begin
                $display("[TB][PASS_EARLY] T=%0t Clean single-block PASS GPIO_OUT=%h GPIO_OE=%h DEBUG_OUT=%h PC=%h INST=%h",
                         $time, gpio_out_pad, gpio_oe_pad, debug_out_pad, pc_debug_pad, inst_debug_pad);
                #20;
                $finish;
            end
        end
    end

endmodule
