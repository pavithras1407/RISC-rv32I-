`timescale 1ns/1ps

// ============================================================================
// Testbench : tb_rv32i_store_axi_window
// Purpose   : Directed store/AXI stress test for RV32I SoC v1.
//
// Why this exists:
//   The large full functional test timed out near PC=0x00010690 at a store
//   instruction around result offsets 0x198/0x19C. This TB isolates that class
//   of behavior without the rest of the large program.
//
// What it checks:
//   1) Boot ROM -> Program SRAM execution path still works.
//   2) Back-to-back SW instructions to Data SRAM result offsets 0x190..0x1DC.
//   3) AXI write response handshake completes for every store.
//   4) CPU does not get stuck with dmem_req waiting forever.
//   5) Final pass signature writes DEBUG_OUT = 32'hC0FFEE00.
//
// Expected:
//   [TB][PASS_ALL] Store/AXI result-window functionality PASS
// ============================================================================

module tb_rv32i_store_axi_window;

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
    integer off;
    integer errors;
    integer store_resp_count;
    integer same_pc_count;
    reg [31:0] last_pc;
    reg [31:0] data_word;

    rv32i_chip_top_spi_boot dut (
        .clk_pad              (clk_pad),
        .rst_n_pad            (rst_n_pad),
        .boot_en_pad          (boot_en_pad),
        .boot_spi_sclk_pad    (boot_spi_sclk_pad),
        .boot_spi_mosi_pad    (boot_spi_mosi_pad),
        .boot_spi_miso_pad    (boot_spi_miso_pad),
        .boot_spi_cs_n_pad    (boot_spi_cs_n_pad),
        .loader_done_pad      (loader_done_pad),
        .cpu_rst_dbg_pad      (cpu_rst_dbg_pad),
        .jtag_irq_pad         (jtag_irq_pad),
        .gpio_in_pad          (gpio_in_pad),
        .gpio_out_pad         (gpio_out_pad),
        .gpio_oe_pad          (gpio_oe_pad),
        .debug_out_pad        (debug_out_pad),
        .spi_sclk_pad         (spi_sclk_pad),
        .spi_mosi_pad         (spi_mosi_pad),
        .spi_miso_pad         (spi_miso_pad),
        .spi_cs_n_pad         (spi_cs_n_pad),
        .pc_debug_pad         (pc_debug_pad),
        .inst_debug_pad       (inst_debug_pad),
        .trap_taken_pad       (trap_taken_pad),
        .timer_irq_dbg_pad    (timer_irq_dbg_pad)
    );

    initial begin
        clk_pad = 1'b0;
        forever #5 clk_pad = ~clk_pad; // 100 MHz
    end

    task put_imem;
        input integer idx;
        input [31:0] word;
        begin
            dut.soc_i.program_sram_i.sram_macro.ram.memory[idx] = {4'h0, word};
        end
    endtask

    task clear_memories;
        begin
            for (i = 0; i < 1024; i = i + 1) begin
                dut.soc_i.program_sram_i.sram_macro.ram.memory[i] = 36'h0_00000013;
                dut.soc_i.data_sram_i.sram_macro.ram.memory[i]    = 36'h0_00000000;
            end

            // Mark the target result window with visible bad values.
            for (off = 32'h190; off <= 32'h1dc; off = off + 4) begin
                dut.soc_i.data_sram_i.sram_macro.ram.memory[off[11:2]] = {4'h0, (32'hBAD00000 + off)};
            end
        end
    endtask

    task preload_store_window_program;
        begin
            put_imem(  0, 32'h00000013); // latency NOP
            put_imem(  1, 32'h00000013); // latency NOP
            put_imem(  2, 32'h00000013); // latency NOP
            put_imem(  3, 32'h000200B7); // lui x1,0x00020 ; x1=0x00020000 Data SRAM mapped base
            put_imem(  4, 32'h00000013); // 
            put_imem(  5, 32'h00000013); // 
            put_imem(  6, 32'h00100113); // addi x2,x0,1 ; store value
            put_imem(  7, 32'h00000013); // 
            put_imem(  8, 32'h00000013); // 
            put_imem(  9, 32'h1820A823); // sw x2,0x190(x1) ; result window
            put_imem( 10, 32'h1820AA23); // sw x2,0x194(x1) ; result window
            put_imem( 11, 32'h1820AC23); // sw x2,0x198(x1) ; result window
            put_imem( 12, 32'h1820AE23); // sw x2,0x19c(x1) ; result window
            put_imem( 13, 32'h1A20A023); // sw x2,0x1a0(x1) ; result window
            put_imem( 14, 32'h1A20A223); // sw x2,0x1a4(x1) ; result window
            put_imem( 15, 32'h1A20A423); // sw x2,0x1a8(x1) ; result window
            put_imem( 16, 32'h1A20A623); // sw x2,0x1ac(x1) ; result window
            put_imem( 17, 32'h1A20A823); // sw x2,0x1b0(x1) ; result window
            put_imem( 18, 32'h1A20AA23); // sw x2,0x1b4(x1) ; result window
            put_imem( 19, 32'h1A20AC23); // sw x2,0x1b8(x1) ; result window
            put_imem( 20, 32'h1A20AE23); // sw x2,0x1bc(x1) ; result window
            put_imem( 21, 32'h1C20A023); // sw x2,0x1c0(x1) ; result window
            put_imem( 22, 32'h1C20A223); // sw x2,0x1c4(x1) ; result window
            put_imem( 23, 32'h1C20A423); // sw x2,0x1c8(x1) ; result window
            put_imem( 24, 32'h1C20A623); // sw x2,0x1cc(x1) ; result window
            put_imem( 25, 32'h1C20A823); // sw x2,0x1d0(x1) ; result window
            put_imem( 26, 32'h1C20AA23); // sw x2,0x1d4(x1) ; result window
            put_imem( 27, 32'h1C20AC23); // sw x2,0x1d8(x1) ; result window
            put_imem( 28, 32'h1C20AE23); // sw x2,0x1dc(x1) ; result window
            put_imem( 29, 32'h00000013); // 
            put_imem( 30, 32'h00000013); // 
            put_imem( 31, 32'h100011B7); // lui x3,0x10001 ; GPIO base
            put_imem( 32, 32'h00000013); // 
            put_imem( 33, 32'h00000013); // 
            put_imem( 34, 32'hC0FFF237); // lui x4,0xC0FFF
            put_imem( 35, 32'h00000013); // 
            put_imem( 36, 32'h00000013); // 
            put_imem( 37, 32'hE0020213); // addi x4,x4,-512 ; x4=C0FFEE00
            put_imem( 38, 32'h00000013); // 
            put_imem( 39, 32'h00000013); // 
            put_imem( 40, 32'h0041A623); // sw x4,12(x3) ; DEBUG_OUT=C0FFEE00
            put_imem( 41, 32'h00000013); // 
            put_imem( 42, 32'h00000013); // 
            put_imem( 43, 32'h0000006F); // jal x0,0 ; loop
            $display("[TB] Store/AXI window program loaded. Instruction count=%0d", 44);
            $display("[TB] Store window offsets: 0x190..0x1DC, expected value=1");
        end
    endtask

    task check_result_window;
        begin
            errors = 0;
            for (off = 32'h190; off <= 32'h1dc; off = off + 4) begin
                data_word = dut.soc_i.data_sram_i.sram_macro.ram.memory[off[11:2]][31:0];
                if (data_word !== 32'h00000001) begin
                    $display("[TB][FAIL] DATA_WINDOW offset=0x%03h index=%0d expected=00000001 got=%h",
                             off, off[11:2], data_word);
                    errors = errors + 1;
                end
                else begin
                    $display("[TB][OK]   DATA_WINDOW offset=0x%03h index=%0d value=%h",
                             off, off[11:2], data_word);
                end
            end

            if (store_resp_count < 20) begin
                $display("[TB][FAIL] Expected at least 20 Data SRAM write responses, got %0d", store_resp_count);
                errors = errors + 1;
            end

            if (debug_out_pad !== 32'hC0FFEE00) begin
                $display("[TB][FAIL] DEBUG_OUT expected C0FFEE00 got %h", debug_out_pad);
                errors = errors + 1;
            end

            if (trap_taken_pad !== 1'b0) begin
                $display("[TB][FAIL] Unexpected trap_taken at final check");
                errors = errors + 1;
            end

            if (errors == 0) begin
                $display("[TB][PASS_ALL] Store/AXI result-window functionality PASS. store_resp_count=%0d DEBUG_OUT=%h PC=%h INST=%h",
                         store_resp_count, debug_out_pad, pc_debug_pad, inst_debug_pad);
            end
            else begin
                $display("[TB][FAIL_ALL] Store/AXI result-window functionality FAIL errors=%0d store_resp_count=%0d DEBUG_OUT=%h PC=%h INST=%h",
                         errors, store_resp_count, debug_out_pad, pc_debug_pad, inst_debug_pad);
            end
        end
    endtask

    initial begin
        rst_n_pad         = 1'b0;
        boot_en_pad       = 1'b0; // bypass SPI loader; still compiles final SPI-boot chip top
        boot_spi_sclk_pad = 1'b0;
        boot_spi_mosi_pad = 1'b0;
        boot_spi_cs_n_pad = 1'b1;
        jtag_irq_pad      = 1'b0;
        gpio_in_pad       = 8'h00;
        spi_miso_pad      = 1'b0;
        errors            = 0;
        store_resp_count  = 0;
        same_pc_count     = 0;
        last_pc           = 32'hFFFF_FFFF;

        #120;
        clear_memories;
        preload_store_window_program;

        #80;
        $display("[TB] Releasing reset.");
        rst_n_pad = 1'b1;

        #200000;
        $display("[TB][TIMEOUT] PASS signature not seen. PC=%h INST=%h DEBUG=%h TRAP=%b store_resp_count=%0d",
                 pc_debug_pad, inst_debug_pad, debug_out_pad, trap_taken_pad, store_resp_count);
        check_result_window;
        $finish;
    end

    always @(posedge clk_pad) begin
        if (rst_n_pad) begin
            // Count completed Data SRAM write responses. This is cleaner than
            // core mem_we because mem_we can remain high while the core is stalled.
            if (dut.soc_i.axi_ic_i.S2_BVALID && dut.soc_i.axi_ic_i.S2_BREADY) begin
                store_resp_count <= store_resp_count + 1;
                $display("[TB] S2_WRITE_RESP T=%0t COUNT=%0d BRESP=%b LAST_AWADDR=%h WDATA=%h WSTRB=%b",
                         $time, store_resp_count + 1,
                         dut.soc_i.axi_ic_i.S2_BRESP,
                         dut.soc_i.axi_ic_i.S2_AWADDR,
                         dut.soc_i.axi_ic_i.S2_WDATA,
                         dut.soc_i.axi_ic_i.S2_WSTRB);
            end

            if (dut.soc_i.mem_we) begin
                $display("[TB] CORE_MEM_WRITE T=%0t PC=%h INST=%h ADDR=%h DATA=%h dmem_req=%b dmem_ready=%b",
                         $time, pc_debug_pad, inst_debug_pad,
                         dut.soc_i.mem_addr, dut.soc_i.mem_wdata,
                         dut.soc_i.dmem_req, dut.soc_i.dmem_ready);
            end

            // Detailed AXI state only around the store program region or when waiting.
            if ((pc_debug_pad >= 32'h00010020 && pc_debug_pad <= 32'h000100B0) ||
                (dut.soc_i.dmem_req && !dut.soc_i.dmem_ready)) begin
                $display("[DBG_STORE_AXI] T=%0t PC=%h INST=%h state=%0d dmem_req=%b dmem_wr=%b dmem_ready=%b dmem_addr=%h dmem_wdata=%h AWVALID=%b AWREADY=%b WVALID=%b WREADY=%b BVALID=%b BREADY=%b BRESP=%b",
                         $time, pc_debug_pad, inst_debug_pad,
                         dut.soc_i.axi_master_i.state,
                         dut.soc_i.dmem_req, dut.soc_i.dmem_wr, dut.soc_i.dmem_ready,
                         dut.soc_i.dmem_addr, dut.soc_i.dmem_wdata,
                         dut.soc_i.m_axi_awvalid, dut.soc_i.m_axi_awready,
                         dut.soc_i.m_axi_wvalid,  dut.soc_i.m_axi_wready,
                         dut.soc_i.m_axi_bvalid,  dut.soc_i.m_axi_bready,
                         dut.soc_i.m_axi_bresp);
            end

            // Stuck-PC detector, useful when the test times out.
            if (pc_debug_pad == last_pc)
                same_pc_count <= same_pc_count + 1;
            else begin
                same_pc_count <= 0;
                last_pc <= pc_debug_pad;
            end

            if (same_pc_count == 100) begin
                $display("[TB][STUCK_PC_WARN] T=%0t PC=%h INST=%h state=%0d dmem_req=%b dmem_ready=%b m_axi_bvalid=%b m_axi_bready=%b",
                         $time, pc_debug_pad, inst_debug_pad,
                         dut.soc_i.axi_master_i.state,
                         dut.soc_i.dmem_req, dut.soc_i.dmem_ready,
                         dut.soc_i.m_axi_bvalid, dut.soc_i.m_axi_bready);
            end

            if (debug_out_pad === 32'hC0FFEE00) begin
                $display("[TB] PASS signature observed at T=%0t", $time);
                #20;
                check_result_window;
                $finish;
            end
        end
    end

endmodule
