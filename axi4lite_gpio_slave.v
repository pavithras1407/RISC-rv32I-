`timescale 1ns/1fs

// ============================================================================
// Module : axi4lite_gpio_slave
// Purpose:
//   Simple memory-mapped GPIO/debug output block for RV32I SoC.
//
// Register map, relative to GPIO_BASE = 0x1000_1000:
//   0x00 GPIO_OUT   output data register
//   0x04 GPIO_OE    output enable register
//   0x08 GPIO_IN    input pin sample, read-only
//   0x0C DEBUG_OUT  debug register for simulation/tapeout observation
// ============================================================================

module axi4lite_gpio_slave #(
    parameter GPIO_WIDTH = 8
)(
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

    input      [GPIO_WIDTH-1:0] gpio_in,
    output     [GPIO_WIDTH-1:0] gpio_out,
    output     [GPIO_WIDTH-1:0] gpio_oe,
    output     [31:0]           debug_out
);

    localparam GPIO_OUT_REG  = 8'h00;
    localparam GPIO_OE_REG   = 8'h04;
    localparam GPIO_IN_REG   = 8'h08;
    localparam DEBUG_OUT_REG = 8'h0C;

    localparam IDLE       = 2'd0;
    localparam READ_RESP  = 2'd1;
    localparam WRITE_RESP = 2'd2;

    reg [1:0] state;

    reg [31:0] gpio_out_reg;
    reg [31:0] gpio_oe_reg;
    reg [31:0] debug_out_reg;

    assign gpio_out  = gpio_out_reg[GPIO_WIDTH-1:0];
    assign gpio_oe   = gpio_oe_reg[GPIO_WIDTH-1:0];
    assign debug_out = debug_out_reg;

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
                GPIO_OUT_REG:  read_reg = gpio_out_reg;
                GPIO_OE_REG:   read_reg = gpio_oe_reg;
                GPIO_IN_REG:   read_reg = {{(32-GPIO_WIDTH){1'b0}}, gpio_in};
                DEBUG_OUT_REG: read_reg = debug_out_reg;
                default:       read_reg = 32'h0000_0000;
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

            gpio_out_reg  <= 32'h0000_0000;
            gpio_oe_reg   <= 32'h0000_0000;
            debug_out_reg <= 32'h0000_0000;
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
                            GPIO_OUT_REG:  gpio_out_reg  <= merge_wstrb(gpio_out_reg,  S_AXI_WDATA, S_AXI_WSTRB);
                            GPIO_OE_REG:   gpio_oe_reg   <= merge_wstrb(gpio_oe_reg,   S_AXI_WDATA, S_AXI_WSTRB);
                            DEBUG_OUT_REG: debug_out_reg <= merge_wstrb(debug_out_reg, S_AXI_WDATA, S_AXI_WSTRB);
                            default:       ;
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
