`timescale 1ns/1fs

// ============================================================================
// Testbench : tb_rv32i_chip_top_spi_boot
// Purpose   : Stage-3 SPI boot-loader validation.
//
// Flow:
//   1. Hold reset.
//   2. Release reset with boot_en=1; CPU remains internally held in reset.
//   3. Send SPI WRITE frames to load Program SRAM.
//   4. Send SPI DONE frame.
//   5. CPU reset releases, Boot ROM jumps to Program SRAM.
//   6. Program writes GPIO_OUT=A5, GPIO_OE=FF, DEBUG_OUT=12345678.
// ============================================================================

module tb_rv32i_chip_top_spi_boot;

    reg clk_pad;
    reg rst_n_pad;
    reg boot_en_pad;
    reg boot_spi_sclk_pad;
    reg boot_spi_mosi_pad;
    wire boot_spi_miso_pad;
    reg boot_spi_cs_n_pad;
    wire loader_done_pad;
    wire cpu_rst_dbg_pad;

    reg jtag_irq_pad;
    reg [7:0] gpio_in_pad;
    wire [7:0] gpio_out_pad;
    wire [7:0] gpio_oe_pad;
    wire [31:0] debug_out_pad;

    wire spi_sclk_pad;
    wire spi_mosi_pad;
    reg  spi_miso_pad;
    wire spi_cs_n_pad;

    wire [31:0] pc_debug_pad;
    wire [31:0] inst_debug_pad;
    wire trap_taken_pad;
    wire timer_irq_dbg_pad;

    integer pass_seen;
    integer fail_seen;

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
        forever #5 clk_pad = ~clk_pad;
    end

    task spi_send_frame;
        input [71:0] frame;
        integer i;
        begin
            boot_spi_cs_n_pad = 1'b1;
            boot_spi_sclk_pad = 1'b0;
            boot_spi_mosi_pad = 1'b0;
            #200;
            boot_spi_cs_n_pad = 1'b0;
            #200;
            for (i = 71; i >= 0; i = i - 1) begin
                boot_spi_mosi_pad = frame[i];
                #50;
                boot_spi_sclk_pad = 1'b1;
                #50;
                boot_spi_sclk_pad = 1'b0;
            end
            #200;
            boot_spi_cs_n_pad = 1'b1;
            boot_spi_mosi_pad = 1'b0;
            #2000;
        end
    endtask

    task spi_write_word;
        input [31:0] addr;
        input [31:0] data;
        begin
            spi_send_frame({4'h1, addr, data, 4'hF});
            $display("[TB] SPI_WRITE_SENT T=%0t ADDR=%h DATA=%h", $time, addr, data);
        end
    endtask

    task spi_done;
        begin
            spi_send_frame({4'hF, 32'h0000_0000, 32'h0000_0000, 4'h0});
            $display("[TB] SPI_DONE_SENT  T=%0t", $time);
        end
    endtask

    task load_program_over_spi;
        begin
            // Keep the same synchronous-SRAM alignment used by the clean Stage-2B test.
            // 0x0001_0000 + index*4
            spi_write_word(32'h0001_0000, 32'h0000_0013); // NOP
            spi_write_word(32'h0001_0004, 32'h0000_0013); // NOP
            spi_write_word(32'h0001_0008, 32'h0000_0013); // NOP
            spi_write_word(32'h0001_000C, 32'h1000_10B7); // lui  x1,0x10001
            spi_write_word(32'h0001_0010, 32'h0000_0013); // NOP
            spi_write_word(32'h0001_0014, 32'h0000_0013); // NOP
            spi_write_word(32'h0001_0018, 32'h0A50_0113); // addi x2,x0,0x0A5
            spi_write_word(32'h0001_001C, 32'h0000_0013); // NOP
            spi_write_word(32'h0001_0020, 32'h0000_0013); // NOP
            spi_write_word(32'h0001_0024, 32'h0020_A023); // sw   x2,0(x1)
            spi_write_word(32'h0001_0028, 32'h0000_0013); // NOP
            spi_write_word(32'h0001_002C, 32'h0000_0013); // NOP
            spi_write_word(32'h0001_0030, 32'h0FF0_0193); // addi x3,x0,0x0FF
            spi_write_word(32'h0001_0034, 32'h0000_0013); // NOP
            spi_write_word(32'h0001_0038, 32'h0000_0013); // NOP
            spi_write_word(32'h0001_003C, 32'h0030_A223); // sw   x3,4(x1)
            spi_write_word(32'h0001_0040, 32'h0000_0013); // NOP
            spi_write_word(32'h0001_0044, 32'h0000_0013); // NOP
            spi_write_word(32'h0001_0048, 32'h1234_5237); // lui  x4,0x12345
            spi_write_word(32'h0001_004C, 32'h0000_0013); // NOP
            spi_write_word(32'h0001_0050, 32'h0000_0013); // NOP
            spi_write_word(32'h0001_0054, 32'h6782_0213); // addi x4,x4,0x678
            spi_write_word(32'h0001_0058, 32'h0000_0013); // NOP
            spi_write_word(32'h0001_005C, 32'h0000_0013); // NOP
            spi_write_word(32'h0001_0060, 32'h0040_A623); // sw   x4,12(x1)
            spi_write_word(32'h0001_0064, 32'h0000_006F); // jal x0,0
        end
    endtask

    always @(posedge clk_pad) begin
        if (dut.soc_i.spi_boot_loader_i.M_AXI_AWVALID && dut.soc_i.spi_boot_loader_i.M_AXI_AWREADY &&
            dut.soc_i.spi_boot_loader_i.M_AXI_WVALID  && dut.soc_i.spi_boot_loader_i.M_AXI_WREADY) begin
            $display("[TB] LOADER_AXI_WRITE T=%0t ADDR=%h DATA=%h WSTRB=%b",
                     $time,
                     dut.soc_i.spi_boot_loader_i.M_AXI_AWADDR,
                     dut.soc_i.spi_boot_loader_i.M_AXI_WDATA,
                     dut.soc_i.spi_boot_loader_i.M_AXI_WSTRB);
        end

        if (dut.soc_i.axi_ic_i.S4_AWVALID && dut.soc_i.axi_ic_i.S4_WVALID &&
            dut.soc_i.axi_ic_i.S4_AWREADY && dut.soc_i.axi_ic_i.S4_WREADY) begin
            $display("[TB] GPIO_AXI_WRITE   T=%0t ADDR=%h DATA=%h WSTRB=%b",
                     $time,
                     dut.soc_i.axi_ic_i.S4_AWADDR,
                     dut.soc_i.axi_ic_i.S4_WDATA,
                     dut.soc_i.axi_ic_i.S4_WSTRB);
        end

        if (loader_done_pad && !cpu_rst_dbg_pad) begin
            $display("T=%0t PC=%h INST=%h GPIO=%h OE=%h DBG=%h TRAP=%b LOADER_DONE=%b CPU_RST=%b",
                     $time, pc_debug_pad, inst_debug_pad, gpio_out_pad, gpio_oe_pad,
                     debug_out_pad, trap_taken_pad, loader_done_pad, cpu_rst_dbg_pad);
        end

        if (!pass_seen && gpio_out_pad == 8'hA5 && gpio_oe_pad == 8'hFF && debug_out_pad == 32'h1234_5678) begin
            pass_seen = 1;
            $display("[TB][PASS_EARLY] T=%0t SPI boot PASS GPIO_OUT=%h GPIO_OE=%h DEBUG_OUT=%h PC=%h INST=%h",
                     $time, gpio_out_pad, gpio_oe_pad, debug_out_pad, pc_debug_pad, inst_debug_pad);
            #200;
            $finish;
        end

        if (!fail_seen && loader_done_pad && !cpu_rst_dbg_pad && trap_taken_pad) begin
            fail_seen = 1;
            $display("[TB][FAIL] Trap seen after SPI boot. PC=%h INST=%h", pc_debug_pad, inst_debug_pad);
        end
    end

    initial begin
        pass_seen = 0;
        fail_seen = 0;
        rst_n_pad = 1'b0;
        boot_en_pad = 1'b1;
        boot_spi_sclk_pad = 1'b0;
        boot_spi_mosi_pad = 1'b0;
        boot_spi_cs_n_pad = 1'b1;
        jtag_irq_pad = 1'b0;
        gpio_in_pad = 8'h00;
        spi_miso_pad = 1'b0;

        #200;
        rst_n_pad = 1'b1;
        $display("[TB] Reset released. CPU should remain held by SPI boot loader. loader_done=%b cpu_rst=%b", loader_done_pad, cpu_rst_dbg_pad);
        #1000;

        load_program_over_spi;
        $display("[TB] Program frames sent over SPI. loader_done=%b cpu_rst=%b", loader_done_pad, cpu_rst_dbg_pad);
        spi_done;
        $display("[TB] DONE frame sent. loader_done=%b cpu_rst=%b", loader_done_pad, cpu_rst_dbg_pad);

        #200000;
        if (!pass_seen) begin
            $display("[TB][FAIL] Timeout. GPIO_OUT=%h GPIO_OE=%h DEBUG_OUT=%h PC=%h INST=%h loader_done=%b cpu_rst=%b trap=%b",
                     gpio_out_pad, gpio_oe_pad, debug_out_pad, pc_debug_pad, inst_debug_pad,
                     loader_done_pad, cpu_rst_dbg_pad, trap_taken_pad);
            $finish;
        end
    end

endmodule
