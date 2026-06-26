`timescale 1ns/1fs

module axi4lite_spi_slave
(
    input             clk,
    input             rst,

    //============================================================
    // AXI WRITE ADDRESS
    //============================================================
    input      [31:0] S_AXI_AWADDR,
    input             S_AXI_AWVALID,
    output reg        S_AXI_AWREADY,

    //============================================================
    // AXI WRITE DATA
    //============================================================
    input      [31:0] S_AXI_WDATA,
    input      [ 3:0] S_AXI_WSTRB,
    input             S_AXI_WVALID,
    output reg        S_AXI_WREADY,

    //============================================================
    // AXI WRITE RESPONSE
    //============================================================
    output reg [ 1:0] S_AXI_BRESP,
    output reg        S_AXI_BVALID,
    input             S_AXI_BREADY,

    //============================================================
    // AXI READ ADDRESS
    //============================================================
    input      [31:0] S_AXI_ARADDR,
    input             S_AXI_ARVALID,
    output reg        S_AXI_ARREADY,

    //============================================================
    // AXI READ DATA
    //============================================================
    output reg [31:0] S_AXI_RDATA,
    output reg [ 1:0] S_AXI_RRESP,
    output reg        S_AXI_RVALID,
    input             S_AXI_RREADY,

    //============================================================
    // SPI PINS
    //============================================================
    output            spi_sclk,
    output            spi_mosi,
    input             spi_miso,
output reg spi_irq,
    output            spi_cs_n
);

    //------------------------------------------------------------
    // Register map
    //------------------------------------------------------------

    localparam CTRL_REG   = 8'h00;
    localparam STATUS_REG = 8'h04;
    localparam TX_REG     = 8'h08;
    localparam RX_REG     = 8'h0C;
    localparam CLKDIV_REG = 8'h10;

    //------------------------------------------------------------
    // AXI FSM
    //------------------------------------------------------------

    localparam IDLE       = 2'd0;
    localparam READ_RESP  = 2'd1;
    localparam WRITE_RESP = 2'd2;

    reg [1:0] state;

    //------------------------------------------------------------
    // Registers
    //------------------------------------------------------------

    reg [31:0] ctrl_reg;
    reg [31:0] status_reg;
    reg [31:0] tx_reg;
    reg [31:0] rx_reg;
    reg [31:0] clkdiv_reg;

    //------------------------------------------------------------
    // SPI Signals
    //------------------------------------------------------------

    reg        start_pulse;

    wire [7:0] spi_rx_data;
    wire       spi_busy;
    wire       spi_done;

    //------------------------------------------------------------
    // SPI MASTER
    //------------------------------------------------------------

    spi_master spi_master_i
    (
        .clk      (clk),
        .rst      (rst),

        .start    (start_pulse),
        .tx_data  (tx_reg[7:0]),

        .clk_div  (clkdiv_reg[15:0]),

        .rx_data  (spi_rx_data),
        .busy     (spi_busy),
        .done     (spi_done),

        .spi_sclk (spi_sclk),
        .spi_mosi (spi_mosi),
        .spi_miso (spi_miso),
        .spi_cs_n (spi_cs_n)
    );

    //------------------------------------------------------------
    // AXI + SPI FSM
    //------------------------------------------------------------

    always @(posedge clk)
    begin

        start_pulse <= 1'b0;

        if(rst)
        begin

            state <= IDLE;

            S_AXI_AWREADY <= 1'b0;
            S_AXI_WREADY  <= 1'b0;

            S_AXI_BRESP   <= 2'b00;
            S_AXI_BVALID  <= 1'b0;

            S_AXI_ARREADY <= 1'b0;

            S_AXI_RDATA   <= 32'd0;
            S_AXI_RRESP   <= 2'b00;
            S_AXI_RVALID  <= 1'b0;

            ctrl_reg      <= 32'd0;
            status_reg    <= 32'd0;
            tx_reg        <= 32'd0;
            rx_reg        <= 32'd0;
            spi_irq <= 1'b0;
            clkdiv_reg    <= 32'd10;

        end
        else
        begin

            //----------------------------------------------------
            // SPI STATUS UPDATE
            //----------------------------------------------------

            status_reg[0] <= spi_busy;

            if(spi_done)
            begin
                status_reg[1] <= 1'b1;
                rx_reg <= {24'd0,spi_rx_data};

    spi_irq <= 1'b1;
            end

            //----------------------------------------------------
            // FSM
            //----------------------------------------------------

            case(state)

            //----------------------------------------------------
            // IDLE
            //----------------------------------------------------

            IDLE:
            begin

                S_AXI_BVALID <= 1'b0;
                S_AXI_RVALID <= 1'b0;

                S_AXI_AWREADY <= 1'b1;
                S_AXI_WREADY  <= 1'b1;
                S_AXI_ARREADY <= 1'b1;

                //----------------------------------------------
                // WRITE
                //----------------------------------------------

                if(S_AXI_AWVALID && S_AXI_WVALID)
                begin

                    S_AXI_AWREADY <= 1'b0;
                    S_AXI_WREADY  <= 1'b0;
                    S_AXI_ARREADY <= 1'b0;

                    case(S_AXI_AWADDR[7:0])

                        CTRL_REG:
                        begin
                            ctrl_reg <= S_AXI_WDATA;

                            status_reg[1] <= 1'b0;
                             spi_irq       <= 1'b0;
                            if(S_AXI_WDATA[0])
                                start_pulse <= 1'b1;
                        end

                        TX_REG:
                            tx_reg <= S_AXI_WDATA;

                        CLKDIV_REG:
                            clkdiv_reg <= S_AXI_WDATA;

                        default:
                            ;

                    endcase

                    state <= WRITE_RESP;
                end

                //----------------------------------------------
                // READ
                //----------------------------------------------

                else if(S_AXI_ARVALID)
                begin

                    S_AXI_AWREADY <= 1'b0;
                    S_AXI_WREADY  <= 1'b0;
                    S_AXI_ARREADY <= 1'b0;

                    case(S_AXI_ARADDR[7:0])

                        CTRL_REG:
                            S_AXI_RDATA <= ctrl_reg;

                        STATUS_REG:
                            S_AXI_RDATA <= status_reg;

                        TX_REG:
                            S_AXI_RDATA <= tx_reg;

                        RX_REG:
                            S_AXI_RDATA <= rx_reg;

                        CLKDIV_REG:
                            S_AXI_RDATA <= clkdiv_reg;

                        default:
                            S_AXI_RDATA <= 32'hDEADBEEF;

                    endcase

                    state <= READ_RESP;
                end
            end

            //----------------------------------------------------
            // READ RESPONSE
            //----------------------------------------------------

            READ_RESP:
            begin

                if(!S_AXI_RVALID)
                begin
                    S_AXI_RRESP  <= 2'b00;
                    S_AXI_RVALID <= 1'b1;
                end
                else if(S_AXI_RREADY)
                begin
                    S_AXI_RVALID <= 1'b0;
                    state <= IDLE;
                end

            end

            //----------------------------------------------------
            // WRITE RESPONSE
            //----------------------------------------------------

            WRITE_RESP:
            begin

                if(!S_AXI_BVALID)
                begin
                    S_AXI_BRESP  <= 2'b00;
                    S_AXI_BVALID <= 1'b1;
                end
                else if(S_AXI_BREADY)
                begin
                    S_AXI_BVALID <= 1'b0;
                    state <= IDLE;
                end

            end

            default:
                state <= IDLE;

            endcase
        end
    end

endmodule

