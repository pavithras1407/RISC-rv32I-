`timescale 1ns/1fs

// ============================================================================
// Module : rv32i_axi_master_wrapper
// Purpose:
//   Converts RV32I core ready/valid memory interface into AXI4-Lite master bus.
//
// Core side:
//   - imem_req/imem_addr -> instruction AXI read
//   - dmem_req/dmem_wr   -> data AXI read/write
//
// AXI side:
//   - Single AXI4-Lite master interface
//
// Priority:
//   1. Data memory request
//   2. Instruction memory request
//
// Notes:
//   - AXI4-Lite supports one transfer at a time.
//   - No burst.
//   - No outstanding transactions.
//   - Ready signals are one-cycle pulses back to core.
// ============================================================================

module rv32i_axi_master_wrapper (
    input             clk,
    input             rst,

    // ============================================================
    // Core instruction-side interface
    // ============================================================
    input             imem_req,
    input      [31:0] imem_addr,
    output reg        imem_ready,
    output reg [31:0] imem_rdata,
    output reg        imem_error,

    // ============================================================
    // Core data-side interface
    // ============================================================
    input             dmem_req,
    input             dmem_wr,
    input      [31:0] dmem_addr,
    input      [ 2:0] dmem_acc_mode,
    input      [31:0] dmem_wdata,
    output reg        dmem_ready,
    output reg [31:0] dmem_rdata,
    output reg        dmem_error,

    // ============================================================
    // AXI4-Lite write address channel
    // ============================================================
    output reg [31:0] M_AXI_AWADDR,
    output reg        M_AXI_AWVALID,
    input             M_AXI_AWREADY,

    // ============================================================
    // AXI4-Lite write data channel
    // ============================================================
    output reg [31:0] M_AXI_WDATA,
    output reg [ 3:0] M_AXI_WSTRB,
    output reg        M_AXI_WVALID,
    input             M_AXI_WREADY,

    // ============================================================
    // AXI4-Lite write response channel
    // ============================================================
    input      [ 1:0] M_AXI_BRESP,
    input             M_AXI_BVALID,
    output reg        M_AXI_BREADY,

    // ============================================================
    // AXI4-Lite read address channel
    // ============================================================
    output reg [31:0] M_AXI_ARADDR,
    output reg        M_AXI_ARVALID,
    input             M_AXI_ARREADY,

    // ============================================================
    // AXI4-Lite read data channel
    // ============================================================
    input      [31:0] M_AXI_RDATA,
    input      [ 1:0] M_AXI_RRESP,
    input             M_AXI_RVALID,
    output reg        M_AXI_RREADY
);

    // ============================================================
    // Address map
    // ============================================================
    parameter IMEM_BASE = 32'h0000_0000;
    parameter DMEM_BASE = 32'h0001_0000;

    // ============================================================
    // FSM states
    // ============================================================
    localparam IDLE      = 3'd0;
    localparam IMEM_AR   = 3'd1;
    localparam IMEM_R    = 3'd2;
    localparam DMEM_AR   = 3'd3;
    localparam DMEM_R    = 3'd4;
    localparam DMEM_AW_W = 3'd5;
    localparam DMEM_B    = 3'd6;
    localparam DMEM_DONE = 3'd7;

    reg [2:0] state;

    reg aw_done;
    reg w_done;

    reg [31:0] latched_addr;
    reg [31:0] latched_wdata;
    reg [ 2:0] latched_acc_mode;

    // ============================================================
    // Convert core local data address to AXI data memory address
    // ============================================================
    function [31:0] dmem_axi_addr;
        input [31:0] addr;
        begin
            if (addr[31:16] == 16'h0000)
                dmem_axi_addr = DMEM_BASE + addr;
            else
                dmem_axi_addr = addr;
        end
    endfunction

    // ============================================================
    // Generate AXI write strobe
    //
    // mem_acc_mode:
    //   3'b000 : BYTE store
    //   3'b001 : HALFWORD store
    //   3'b010 : WORD store
    // ============================================================
    function [3:0] gen_wstrb;
        input [2:0] acc_mode;
        input [1:0] addr_lsb;
        begin
            case (acc_mode)

                // BYTE store
                3'b000: begin
                    case (addr_lsb)
                        2'b00: gen_wstrb = 4'b0001;
                        2'b01: gen_wstrb = 4'b0010;
                        2'b10: gen_wstrb = 4'b0100;
                        2'b11: gen_wstrb = 4'b1000;
                        default: gen_wstrb = 4'b0000;
                    endcase
                end

                // HALFWORD store
                3'b001: begin
                    if (addr_lsb[1] == 1'b0)
                        gen_wstrb = 4'b0011;
                    else
                        gen_wstrb = 4'b1100;
                end

                // WORD store
                3'b010: begin
                    gen_wstrb = 4'b1111;
                end

                default: begin
                    gen_wstrb = 4'b0000;
                end

            endcase
        end
    endfunction

    // ============================================================
    // Format AXI read word for RV32I load instruction
    //
    // mem_acc_mode:
    //   3'b000 : LB
    //   3'b001 : LH
    //   3'b010 : LW
    //   3'b011 : LBU
    //   3'b100 : LHU
    // ============================================================
    function [31:0] format_load_data;
        input [31:0] rword;
        input [2:0]  acc_mode;
        input [1:0]  addr_lsb;

        reg [7:0]  byte_data;
        reg [15:0] half_data;

        begin
            case (addr_lsb)
                2'b00: byte_data = rword[7:0];
                2'b01: byte_data = rword[15:8];
                2'b10: byte_data = rword[23:16];
                2'b11: byte_data = rword[31:24];
                default: byte_data = 8'b0;
            endcase

            if (addr_lsb[1] == 1'b0)
                half_data = rword[15:0];
            else
                half_data = rword[31:16];

            case (acc_mode)
                3'b000: format_load_data = {{24{byte_data[7]}}, byte_data}; // LB
                3'b001: format_load_data = {{16{half_data[15]}}, half_data}; // LH
                3'b010: format_load_data = rword;                            // LW
                3'b011: format_load_data = {24'b0, byte_data};               // LBU
                3'b100: format_load_data = {16'b0, half_data};               // LHU
                default: format_load_data = rword;
            endcase
        end
    endfunction

    // ============================================================
    // Align write data according to byte lane
    // ============================================================
    function [31:0] align_wdata;
        input [31:0] wdata;
        input [2:0]  acc_mode;
        input [1:0]  addr_lsb;
        begin
            case (acc_mode)

                // BYTE store
                3'b000: begin
                    case (addr_lsb)
                        2'b00: align_wdata = {24'b0, wdata[7:0]};
                        2'b01: align_wdata = {16'b0, wdata[7:0], 8'b0};
                        2'b10: align_wdata = {8'b0,  wdata[7:0], 16'b0};
                        2'b11: align_wdata = {wdata[7:0], 24'b0};
                        default: align_wdata = wdata;
                    endcase
                end

                // HALFWORD store
                3'b001: begin
                    if (addr_lsb[1] == 1'b0)
                        align_wdata = {16'b0, wdata[15:0]};
                    else
                        align_wdata = {wdata[15:0], 16'b0};
                end

                // WORD store
                3'b010: begin
                    align_wdata = wdata;
                end

                default: begin
                    align_wdata = wdata;
                end

            endcase
        end
    endfunction

    // ============================================================
    // AXI master FSM
    // ============================================================
    always @(posedge clk) begin
        if (rst) begin
            state <= IDLE;

            imem_ready <= 1'b0;
            imem_rdata <= 32'b0;
            imem_error <= 1'b0;

            dmem_ready <= 1'b0;
            dmem_rdata <= 32'b0;
            dmem_error <= 1'b0;

            M_AXI_AWADDR  <= 32'b0;
            M_AXI_AWVALID <= 1'b0;

            M_AXI_WDATA   <= 32'b0;
            M_AXI_WSTRB   <= 4'b0000;
            M_AXI_WVALID  <= 1'b0;

            M_AXI_BREADY  <= 1'b0;

            M_AXI_ARADDR  <= 32'b0;
            M_AXI_ARVALID <= 1'b0;

            M_AXI_RREADY  <= 1'b0;

            aw_done <= 1'b0;
            w_done  <= 1'b0;

            latched_addr     <= 32'b0;
            latched_wdata    <= 32'b0;
            latched_acc_mode <= 3'b0;
        end
        else begin
            // Default ready/error pulses low every cycle
            imem_ready <= 1'b0;
            imem_error <= 1'b0;
            dmem_ready <= 1'b0;
            dmem_error <= 1'b0;

            case (state)

                // ====================================================
                // IDLE: choose next transaction
                // Priority: data request first, then instruction fetch
                // ====================================================
                IDLE: begin
                    M_AXI_AWVALID <= 1'b0;
                    M_AXI_WVALID  <= 1'b0;
                    M_AXI_BREADY  <= 1'b0;
                    M_AXI_ARVALID <= 1'b0;
                    M_AXI_RREADY  <= 1'b0;

                    aw_done <= 1'b0;
                    w_done  <= 1'b0;

                    if (dmem_req) begin
                        latched_addr     <= dmem_axi_addr(dmem_addr);
                        latched_wdata    <= dmem_wdata;
                        latched_acc_mode <= dmem_acc_mode;

                        if (dmem_wr) begin
                            // Data write
                            M_AXI_AWADDR  <= dmem_axi_addr(dmem_addr);
                            M_AXI_AWVALID <= 1'b1;

                            M_AXI_WDATA   <= align_wdata(dmem_wdata,
                                                          dmem_acc_mode,
                                                          dmem_addr[1:0]);

                            M_AXI_WSTRB   <= gen_wstrb(dmem_acc_mode,
                                                        dmem_addr[1:0]);

                            M_AXI_WVALID  <= 1'b1;

                            state <= DMEM_AW_W;
                        end
                        else begin
                            // Data read
                            M_AXI_ARADDR  <= dmem_axi_addr(dmem_addr);
                            M_AXI_ARVALID <= 1'b1;

                            state <= DMEM_AR;
                        end
                    end
                    else if (imem_req) begin
                        // Instruction read
                        M_AXI_ARADDR  <= IMEM_BASE + imem_addr;
                        M_AXI_ARVALID <= 1'b1;

                        state <= IMEM_AR;
                    end
                    else begin
                        state <= IDLE;
                    end
                end

                // ====================================================
                // Instruction read address phase
                // ====================================================
                IMEM_AR: begin
                    M_AXI_ARVALID <= 1'b1;

                    if (M_AXI_ARREADY) begin
                        M_AXI_ARVALID <= 1'b0;
                        M_AXI_RREADY  <= 1'b1;
                        state <= IMEM_R;
                    end
                end

                // ====================================================
                // Instruction read data phase
                // ====================================================
                IMEM_R: begin
                    M_AXI_RREADY <= 1'b1;

                    if (M_AXI_RVALID) begin
                        imem_rdata  <= M_AXI_RDATA;
                        imem_error  <= |M_AXI_RRESP;
                        imem_ready  <= 1'b1;

                        M_AXI_RREADY <= 1'b0;
                        state <= IDLE;
                    end
                end

                // ====================================================
                // Data read address phase
                // ====================================================
                DMEM_AR: begin
                    M_AXI_ARVALID <= 1'b1;

                    if (M_AXI_ARREADY) begin
                        M_AXI_ARVALID <= 1'b0;
                        M_AXI_RREADY  <= 1'b1;
                        state <= DMEM_R;
                    end
                end

                // ====================================================
                // Data read data phase
                // ====================================================
              DMEM_R: begin
    M_AXI_RREADY <= 1'b1;

    if (M_AXI_RVALID) begin
        dmem_rdata <= format_load_data(M_AXI_RDATA,
                                        latched_acc_mode,
                                        latched_addr[1:0]);

        dmem_error <= |M_AXI_RRESP;
        dmem_ready <= 1'b1;

        M_AXI_RREADY <= 1'b0;
        state <= DMEM_DONE;
    end
end

                // ====================================================
                // Data write address/data phase
                // AWREADY and WREADY may come in different cycles
                // ====================================================
                DMEM_AW_W: begin
                    if (!aw_done)
                        M_AXI_AWVALID <= 1'b1;
                    else
                        M_AXI_AWVALID <= 1'b0;

                    if (!w_done)
                        M_AXI_WVALID <= 1'b1;
                    else
                        M_AXI_WVALID <= 1'b0;

                    if (M_AXI_AWVALID && M_AXI_AWREADY) begin
                        aw_done <= 1'b1;
                        M_AXI_AWVALID <= 1'b0;
                    end

                    if (M_AXI_WVALID && M_AXI_WREADY) begin
                        w_done <= 1'b1;
                        M_AXI_WVALID <= 1'b0;
                    end

                    if ((aw_done || (M_AXI_AWVALID && M_AXI_AWREADY)) &&
                        (w_done  || (M_AXI_WVALID  && M_AXI_WREADY))) begin
                        M_AXI_BREADY <= 1'b1;
                        state <= DMEM_B;
                    end
                end

                // ====================================================
                // Data write response phase
                // ====================================================
               DMEM_B: begin
    M_AXI_BREADY <= 1'b1;

    if (M_AXI_BVALID) begin
        dmem_error <= |M_AXI_BRESP;
        dmem_ready <= 1'b1;

        M_AXI_BREADY <= 1'b0;
        state <= DMEM_DONE;
    end
end
                     
                 // ====================================================
                // Data transaction done
                // ====================================================
                DMEM_DONE: begin
                    M_AXI_AWVALID <= 1'b0;
                    M_AXI_WVALID  <= 1'b0;
                    M_AXI_BREADY  <= 1'b0;
                    M_AXI_ARVALID <= 1'b0;
                    M_AXI_RREADY  <= 1'b0;

                    // dmem_ready was asserted during the previous cycle.
                    // The processor samples it on this clock edge and advances MW.
                    // Drop ready and return to IDLE unconditionally so the same
                    // memory operation is not repeated and back-to-back requests
                    // can be accepted on the following cycle.
                    dmem_ready <= 1'b0;
                    state <= IDLE;
                end

                default: begin
                    state <= IDLE;
                end

            endcase
        end
    end

endmodule
