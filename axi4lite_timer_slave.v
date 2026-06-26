`timescale 1ns/1fs

// ============================================================================
// Module : axi4lite_timer_slave
// Purpose:
//   Memory-mapped timer for RV32I SoC.
//
// Register map, relative to TIMER_BASE = 0x1000_0000:
//   0x00 CTRL    [0] enable, [1] irq_enable
//   0x04 COUNT   current counter value
//   0x08 COMPARE interrupt generated when COUNT >= COMPARE and COMPARE != 0
//   0x0C STATUS  [0] irq_pending. Write 1 to clear.
//
// irq output:
//   irq = STATUS[0] & CTRL[1]
// ============================================================================

module axi4lite_timer_slave (
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
    input             S_AXI_RREADY,

    output            timer_irq
);

    localparam CTRL_REG    = 8'h00;
    localparam COUNT_REG   = 8'h04;
    localparam COMPARE_REG = 8'h08;
    localparam STATUS_REG  = 8'h0C;

    localparam IDLE       = 2'd0;
    localparam READ_RESP  = 2'd1;
    localparam WRITE_RESP = 2'd2;

    reg [1:0] state;

    reg [31:0] ctrl_reg;
    reg [31:0] count_reg;
    reg [31:0] compare_reg;
    reg [31:0] status_reg;

    assign timer_irq = status_reg[0] & ctrl_reg[1];

    function [31:0] merge_wstrb;
        input [31:0] old_word;
        input [31:0] new_word;
        input [3:0]  strb;
        begin
            merge_wstrb = old_word;
            if (strb[0]) merge_wstrb[ 7: 0] = new_word[ 7: 0];
            if (strb[1]) merge_wstrb[15: 8] = new_word[15: 8];
            if (strb[2]) merge_wstrb[23:16] = new_word[23:16];
            if (strb[3]) merge_wstrb[31:24] = new_word[31:24];
        end
    endfunction

    function [31:0] read_reg;
        input [7:0] addr;
        begin
            case (addr)
                CTRL_REG:    read_reg = ctrl_reg;
                COUNT_REG:   read_reg = count_reg;
                COMPARE_REG: read_reg = compare_reg;
                STATUS_REG:  read_reg = status_reg;
                default:     read_reg = 32'h0000_0000;
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

            ctrl_reg    <= 32'h0000_0000;
            count_reg   <= 32'h0000_0000;
            compare_reg <= 32'h0000_0064;
            status_reg  <= 32'h0000_0000;
        end
        else begin
            // Timer counting logic
            if (ctrl_reg[0]) begin
                if ((compare_reg != 32'b0) && (count_reg >= compare_reg)) begin
                    count_reg  <= 32'b0;
                    status_reg[0] <= 1'b1;
                end
                else begin
                    count_reg <= count_reg + 32'd1;
                end
            end

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

                        S_AXI_RDATA  <= read_reg(S_AXI_ARADDR[7:0]);
                        S_AXI_RRESP  <= 2'b00;
                        S_AXI_RVALID <= 1'b1;
                        state <= READ_RESP;
                    end
                    else if (S_AXI_AWVALID && S_AXI_WVALID) begin
                        S_AXI_ARREADY <= 1'b0;
                        S_AXI_AWREADY <= 1'b0;
                        S_AXI_WREADY  <= 1'b0;

                        case (S_AXI_AWADDR[7:0])
                            CTRL_REG: begin
                                ctrl_reg <= merge_wstrb(ctrl_reg, S_AXI_WDATA, S_AXI_WSTRB);
                            end
                            COUNT_REG: begin
                                count_reg <= merge_wstrb(count_reg, S_AXI_WDATA, S_AXI_WSTRB);
                            end
                            COMPARE_REG: begin
                                compare_reg <= merge_wstrb(compare_reg, S_AXI_WDATA, S_AXI_WSTRB);
                            end
                            STATUS_REG: begin
                                // Write 1 to clear irq_pending.
                                if (S_AXI_WDATA[0])
                                    status_reg[0] <= 1'b0;
                            end
                            default: begin
                                 S_AXI_BRESP <= 2'b00;
                            end
                        endcase

                        S_AXI_BRESP  <= 2'b00;
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
