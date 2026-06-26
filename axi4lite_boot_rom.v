`timescale 1ns/1fs

// ============================================================================
// Module : axi4lite_boot_rom
// Purpose:
//   Read-only AXI4-Lite Boot ROM for tapeout-style RV32I SoC.
//
// Address range expected by SoC interconnect:
//   0x0000_0000 - 0x0000_0FFF
//
// Boot code used here:
//   lui  sp, 0x00021      // stack pointer = 0x0002_1000, top of 4KB data SRAM
//   lui  t0, 0x00010      // t0 = 0x0001_0000, program SRAM base
//   jalr x0, 0(t0)        // jump to program SRAM
//   nop
//
// Notes:
//   - Writes return SLVERR because this is ROM.
//   - For final tapeout, replace/extend the ROM contents with a real bootloader.
// ============================================================================

module axi4lite_boot_rom (
    input             clk,
    input             rst,

    input      [31:0] S_AXI_AWADDR,
    input             S_AXI_AWVALID,
    output reg        S_AXI_AWREADY,

    input      [31:0] S_AXI_WDATA,
    input      [ 3:0] S_AXI_WSTRB,
    input             S_AXI_WVALID,
    output reg        S_AXI_WREADY,

    output reg [ 1:0] S_AXI_BRESP,
    output reg        S_AXI_BVALID,
    input             S_AXI_BREADY,

    input      [31:0] S_AXI_ARADDR,
    input             S_AXI_ARVALID,
    output reg        S_AXI_ARREADY,

    output reg [31:0] S_AXI_RDATA,
    output reg [ 1:0] S_AXI_RRESP,
    output reg        S_AXI_RVALID,
    input             S_AXI_RREADY
);

    localparam IDLE       = 2'd0;
    localparam READ_RESP  = 2'd1;
    localparam WRITE_RESP = 2'd2;

    reg [1:0] state;

    function [31:0] rom_word;
        input [9:0] word_addr;
        begin
            case (word_addr)
                10'd0: rom_word = 32'h0002_1137; // lui sp, 0x00021
                10'd1: rom_word = 32'h0001_02b7; // lui t0, 0x00010
                10'd2: rom_word = 32'h0002_8067; // jalr x0, 0(t0)
                10'd3: rom_word = 32'h0000_0013; // nop
                default: rom_word = 32'h0000_0013; // nop
            endcase
        end
    endfunction

    always @(posedge clk) begin
        if (rst) begin
            state <= IDLE;

            S_AXI_AWREADY <= 1'b0;
            S_AXI_WREADY  <= 1'b0;
            S_AXI_BRESP   <= 2'b00;
            S_AXI_BVALID  <= 1'b0;

            S_AXI_ARREADY <= 1'b0;
            S_AXI_RDATA   <= 32'b0;
            S_AXI_RRESP   <= 2'b00;
            S_AXI_RVALID  <= 1'b0;
        end
        else begin
            case (state)
                IDLE: begin
                    S_AXI_BVALID  <= 1'b0;
                    S_AXI_RVALID  <= 1'b0;
                    S_AXI_AWREADY <= 1'b1;
                    S_AXI_WREADY  <= 1'b1;
                    S_AXI_ARREADY <= 1'b1;

                    if (S_AXI_ARVALID) begin
                        S_AXI_ARREADY <= 1'b0;
                        S_AXI_AWREADY <= 1'b0;
                        S_AXI_WREADY  <= 1'b0;

                        S_AXI_RDATA  <= rom_word(S_AXI_ARADDR[11:2]);
                        S_AXI_RRESP  <= 2'b00; // OKAY
                        S_AXI_RVALID <= 1'b1;
                        state <= READ_RESP;
                    end
                    else if (S_AXI_AWVALID && S_AXI_WVALID) begin
                        S_AXI_ARREADY <= 1'b0;
                        S_AXI_AWREADY <= 1'b0;
                        S_AXI_WREADY  <= 1'b0;

                        S_AXI_BRESP  <= 2'b10; // SLVERR: ROM write not allowed
                        S_AXI_BVALID <= 1'b1;
                        state <= WRITE_RESP;
                    end
                end

                READ_RESP: begin
                    S_AXI_ARREADY <= 1'b0;
                    if (S_AXI_RREADY) begin
                        S_AXI_RVALID <= 1'b0;
                        state <= IDLE;
                    end
                end

                WRITE_RESP: begin
                    S_AXI_AWREADY <= 1'b0;
                    S_AXI_WREADY  <= 1'b0;
                    if (S_AXI_BREADY) begin
                        S_AXI_BVALID <= 1'b0;
                        state <= IDLE;
                    end
                end

                default: state <= IDLE;
            endcase
        end
    end

endmodule
