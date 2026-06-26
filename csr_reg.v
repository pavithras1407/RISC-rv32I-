`timescale 1ns/1fs
// Machine-mode CSR file with standards-oriented Zicsr semantics for the
// implemented machine CSRs. Implemented CSRs:
//   mstatus, mie, mtvec, mepc, mcause, mip
//
// Supported CSR instructions:
//   CSRRW, CSRRS, CSRRC, CSRRWI, CSRRSI, CSRRCI
//
// Notes:
//   - CSR address legality is checked in processor_soc.v so illegal CSR
//     accesses trap before writes are committed.
//   - This block implements direct-mode mtvec redirection only.

module csr_reg (
    input             clk,
    input             rst,

    input      [31:0] addr,
    input      [31:0] wdata,
    input      [31:0] pc,

    input             irq_valid,
    input      [31:0] irq_cause,

    input             exception,
    input      [31:0] exception_cause,

    input             csr_rd,
    input             csr_wr,
    input             is_mret,
    input      [31:0] inst,

    output reg [31:0] rdata,
    output reg [31:0] epc,
    output reg        epc_taken
);

    reg [31:0] csr_mem [0:5];

    wire [11:0] csr_addr;
    wire [ 2:0] csr_funct3;
    wire [ 4:0] csr_rs1;
    wire [31:0] csr_zimm;

    assign csr_addr   = inst[31:20];
    assign csr_funct3 = inst[14:12];
    assign csr_rs1    = inst[19:15];
    assign csr_zimm   = {27'b0, inst[19:15]};

    // CSR interrupt enable bits
    wire global_int_en;
    wire timer_int_en;
    wire ext_int_en;

    wire timer_irq_take;
    wire ext_irq_take;
    wire interrupt_take;

    assign global_int_en = csr_mem[0][3];   // mstatus.MIE
    assign timer_int_en  = csr_mem[1][7];   // mie.MTIE
    assign ext_int_en    = csr_mem[1][11];  // mie.MEIE

    assign timer_irq_take =
        irq_valid &&
        (irq_cause == 32'd7) &&
        global_int_en &&
        timer_int_en;

    assign ext_irq_take =
        irq_valid &&
        (irq_cause == 32'd11) &&
        global_int_en &&
        ext_int_en;

    assign interrupt_take = timer_irq_take | ext_irq_take;

    function [31:0] csr_read_value;
        input [11:0] csr_addr_i;
        begin
            case (csr_addr_i)
                12'h300: csr_read_value = csr_mem[0]; // mstatus
                12'h304: csr_read_value = csr_mem[1]; // mie
                12'h305: csr_read_value = csr_mem[2]; // mtvec
                12'h341: csr_read_value = csr_mem[3]; // mepc
                12'h342: csr_read_value = csr_mem[4]; // mcause
                12'h344: csr_read_value = csr_mem[5]; // mip
                default: csr_read_value = 32'b0;
            endcase
        end
    endfunction

    function csr_write_enable_effective;
        input [2:0] funct3_i;
        input [4:0] rs1_i;
        begin
            case (funct3_i)
                3'b001: csr_write_enable_effective = 1'b1;              // CSRRW
                3'b010: csr_write_enable_effective = (rs1_i != 5'd0);   // CSRRS
                3'b011: csr_write_enable_effective = (rs1_i != 5'd0);   // CSRRC
                3'b101: csr_write_enable_effective = 1'b1;              // CSRRWI
                3'b110: csr_write_enable_effective = (rs1_i != 5'd0);   // CSRRSI, zimm field
                3'b111: csr_write_enable_effective = (rs1_i != 5'd0);   // CSRRCI, zimm field
                default: csr_write_enable_effective = 1'b0;
            endcase
        end
    endfunction

    function [31:0] csr_write_value;
        input [2:0]  funct3_i;
        input [31:0] old_value_i;
        input [31:0] rs1_value_i;
        input [31:0] zimm_value_i;
        begin
            case (funct3_i)
                3'b001: csr_write_value = rs1_value_i;                  // CSRRW
                3'b010: csr_write_value = old_value_i | rs1_value_i;    // CSRRS
                3'b011: csr_write_value = old_value_i & ~rs1_value_i;   // CSRRC
                3'b101: csr_write_value = zimm_value_i;                 // CSRRWI
                3'b110: csr_write_value = old_value_i | zimm_value_i;   // CSRRSI
                3'b111: csr_write_value = old_value_i & ~zimm_value_i;  // CSRRCI
                default: csr_write_value = old_value_i;
            endcase
        end
    endfunction

    task csr_write_commit;
        input [11:0] csr_addr_i;
        input [31:0] csr_value_i;
        begin
            case (csr_addr_i)
                12'h300: csr_mem[0] <= csr_value_i; // mstatus
                12'h304: csr_mem[1] <= csr_value_i; // mie
                12'h305: csr_mem[2] <= csr_value_i; // mtvec
                12'h341: csr_mem[3] <= csr_value_i; // mepc
                12'h342: csr_mem[4] <= csr_value_i; // mcause
                12'h344: csr_mem[5] <= csr_value_i; // mip
                default: csr_mem[0] <= csr_mem[0];
            endcase
        end
    endtask

    // CSR read. CSR instructions return the old CSR value to rd.
    always @(*) begin
        rdata = 32'b0;
        if (csr_rd)
            rdata = csr_read_value(csr_addr);
    end

    // CSR write / exception / interrupt / mret
    always @(posedge clk) begin
        if (rst) begin
            csr_mem[0] <= 32'b0;
            csr_mem[1] <= 32'b0;
            csr_mem[2] <= 32'b0;
            csr_mem[3] <= 32'b0;
            csr_mem[4] <= 32'b0;
            csr_mem[5] <= 32'b0;

            epc        <= 32'b0;
            epc_taken  <= 1'b0;
        end
        else begin
            // Default every cycle
            epc_taken <= 1'b0;
            epc       <= pc;

            // Update mip pending bits from interrupt controller
            if (irq_valid && (irq_cause == 32'd7))
                csr_mem[5][7] <= 1'b1;      // MTIP

            if (irq_valid && (irq_cause == 32'd11))
                csr_mem[5][11] <= 1'b1;     // MEIP

            // CSR write. Exception/interrupt/MRET below have priority and may
            // overwrite trap-related CSRs in the same cycle.
            if (csr_wr && csr_write_enable_effective(csr_funct3, csr_rs1)) begin
                csr_write_commit(
                    csr_addr,
                    csr_write_value(
                        csr_funct3,
                        csr_read_value(csr_addr),
                        wdata,
                        csr_zimm
                    )
                );
            end

            // Priority 1: synchronous exception
            if (exception) begin
                csr_mem[3] <= pc;               // mepc = faulting instruction PC
                csr_mem[4] <= exception_cause;  // mcause = exception cause

                epc        <= csr_mem[2];       // redirect to mtvec (direct mode)
                epc_taken  <= 1'b1;

                // Disable global interrupt while in trap
                csr_mem[0][3] <= 1'b0;
            end

            // Priority 2: interrupt
            else if (interrupt_take) begin
                csr_mem[3] <= pc;                       // mepc = interrupted PC
                csr_mem[4] <= 32'h80000000 | irq_cause; // interrupt mcause

                epc        <= csr_mem[2];               // redirect to mtvec
                epc_taken  <= 1'b1;

                // Disable global interrupt while in ISR
                csr_mem[0][3] <= 1'b0;
            end

            // Priority 3: MRET
            else if (is_mret) begin
                epc_taken <= 1'b1;
                epc       <= csr_mem[3]; // return to mepc

                // Re-enable global interrupt after return
                csr_mem[0][3] <= 1'b1;

                // Clear pending bits after return
                csr_mem[5][7]  <= 1'b0; // MTIP
                csr_mem[5][11] <= 1'b0; // MEIP
            end
        end
    end

endmodule
