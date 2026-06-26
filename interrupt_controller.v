`timescale 1ns/1fs

module interrupt_controller (
    input  wire        timer_irq,
    input  wire        spi_irq,
    input  wire        jtag_irq,

    output reg         irq_valid,
    output reg [31:0]  irq_cause
);

    always @(*) begin
        irq_valid = 1'b0;
        irq_cause = 32'd0;

        // Priority 1: JTAG/debug external interrupt
        // Priority 2: SPI external interrupt
        // Priority 3: Timer interrupt
        if (jtag_irq) begin
            irq_valid = 1'b1;
            irq_cause = 32'd11;   // Machine external interrupt
        end
        else if (spi_irq) begin
            irq_valid = 1'b1;
            irq_cause = 32'd11;   // Machine external interrupt
        end
        else if (timer_irq) begin
            irq_valid = 1'b1;
            irq_cause = 32'd7;    // Machine timer interrupt
        end
    end

endmodule
