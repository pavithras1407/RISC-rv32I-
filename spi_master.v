`timescale 1ns/1fs

module spi_master
(
    input  wire        clk,
    input  wire        rst,

    input  wire        start,
    input  wire [7:0]  tx_data,

    input  wire [15:0] clk_div,

    output reg  [7:0]  rx_data,
    output reg         busy,
    output reg         done,

    output reg         spi_sclk,
    output reg         spi_mosi,
    input  wire        spi_miso,
    output reg         spi_cs_n
);

    reg [7:0] shift_tx;
    reg [7:0] shift_rx;

    reg [3:0]  bit_cnt;
    reg [15:0] clk_cnt;

    localparam IDLE  = 2'd0;
    localparam TRANS = 2'd1;
    localparam DONE_ST = 2'd2;

    reg [1:0] state;

    always @(posedge clk or posedge rst)
    begin
        if(rst)
        begin
            state     <= IDLE;

            spi_cs_n  <= 1'b1;
            spi_sclk  <= 1'b0;
            spi_mosi  <= 1'b0;

            busy      <= 1'b0;
            done      <= 1'b0;

            shift_tx  <= 8'h00;
            shift_rx  <= 8'h00;

            bit_cnt   <= 4'd0;
            clk_cnt   <= 16'd0;

            rx_data   <= 8'h00;
        end
        else
        begin
            done <= 1'b0;

            case(state)

            //--------------------------------------------------
            // IDLE
            //--------------------------------------------------
            IDLE:
            begin
                spi_cs_n <= 1'b1;
                spi_sclk <= 1'b0;
                busy     <= 1'b0;

                if(start)
                begin
                    spi_cs_n <= 1'b0;
                    busy     <= 1'b1;

                    shift_tx <= tx_data;
                    shift_rx <= 8'h00;

                    bit_cnt  <= 4'd7;
                    clk_cnt  <= 16'd0;

                    spi_mosi <= tx_data[7];

                    state <= TRANS;
                end
            end

            //--------------------------------------------------
            // TRANSFER
            // SPI MODE-0
            // Sample on rising edge
            // Shift on falling edge
            //--------------------------------------------------
          TRANS:
begin
    if(clk_cnt == (clk_div - 1))
    begin
        clk_cnt <= 16'd0;

        spi_sclk <= ~spi_sclk;

        //------------------------------------------
        // Rising edge -> Sample MISO
        //------------------------------------------
        if(spi_sclk == 1'b0)
        begin
            shift_rx[bit_cnt] <= spi_miso;

            if(bit_cnt == 0)
            begin
                rx_data <= {shift_rx[7:1], spi_miso};
                state   <= DONE_ST;
            end
        end

        //------------------------------------------
        // Falling edge -> Shift MOSI
        //------------------------------------------
        else
        begin
            if(bit_cnt != 0)
            begin
                bit_cnt <= bit_cnt - 1'b1;

                shift_tx <= {shift_tx[6:0],1'b0};

                spi_mosi <= shift_tx[6];
            end
        end
    end
    else
    begin
        clk_cnt <= clk_cnt + 1'b1;
    end
end

            //--------------------------------------------------
            // DONE
            //--------------------------------------------------
            DONE_ST:
            begin
                spi_cs_n <= 1'b1;
                spi_sclk <= 1'b0;

                busy <= 1'b0;
                done <= 1'b1;

                state <= IDLE;
            end

            //--------------------------------------------------
            default:
            begin
                state <= IDLE;
            end

            endcase
        end
    end


endmodule
