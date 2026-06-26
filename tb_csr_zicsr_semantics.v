`timescale 1ns/1fs

module tb_csr_zicsr_semantics;
    reg clk;
    reg rst;
    reg [31:0] addr;
    reg [31:0] wdata;
    reg [31:0] pc;
    reg irq_valid;
    reg [31:0] irq_cause;
    reg exception;
    reg [31:0] exception_cause;
    reg csr_rd;
    reg csr_wr;
    reg is_mret;
    reg [31:0] inst;

    wire [31:0] rdata;
    wire [31:0] epc;
    wire epc_taken;

    csr_reg dut (
        .clk(clk), .rst(rst),
        .addr(addr), .wdata(wdata), .pc(pc),
        .irq_valid(irq_valid), .irq_cause(irq_cause),
        .exception(exception), .exception_cause(exception_cause),
        .csr_rd(csr_rd), .csr_wr(csr_wr), .is_mret(is_mret), .inst(inst),
        .rdata(rdata), .epc(epc), .epc_taken(epc_taken)
    );

    initial clk = 1'b0;
    always #5 clk = ~clk;

    function [31:0] csr_inst;
        input [11:0] csr;
        input [4:0]  rs1_or_zimm;
        input [2:0]  funct3;
        input [4:0]  rd;
        begin
            csr_inst = {csr, rs1_or_zimm, funct3, rd, 7'b1110011};
        end
    endfunction

    task csr_op;
        input [31:0] inst_i;
        input [31:0] wdata_i;
        begin
            @(negedge clk);
            inst   = inst_i;
            wdata  = wdata_i;
            csr_rd = 1'b1;
            csr_wr = 1'b1;
            @(posedge clk);
            @(negedge clk);
            csr_rd = 1'b0;
            csr_wr = 1'b0;
        end
    endtask

    task csr_read_check;
        input [11:0] csr_i;
        input [31:0] expected_i;
        begin
            @(negedge clk);
            inst   = csr_inst(csr_i, 5'd0, 3'b010, 5'd1); // CSRRS rd, csr, x0: read only
            csr_rd = 1'b1;
            csr_wr = 1'b1;
            #1;
            if (rdata !== expected_i) begin
                $display("[TB][FAIL] CSR %h expected %h got %h", csr_i, expected_i, rdata);
                $finish;
            end
            @(posedge clk);
            @(negedge clk);
            csr_rd = 1'b0;
            csr_wr = 1'b0;
        end
    endtask

    initial begin
        rst = 1'b1;
        addr = 32'b0;
        wdata = 32'b0;
        pc = 32'h0000_0100;
        irq_valid = 1'b0;
        irq_cause = 32'b0;
        exception = 1'b0;
        exception_cause = 32'b0;
        csr_rd = 1'b0;
        csr_wr = 1'b0;
        is_mret = 1'b0;
        inst = 32'h00000013;

        repeat (4) @(posedge clk);
        rst = 1'b0;
        repeat (2) @(posedge clk);

        // CSRRWI mstatus, zimm=5 => mstatus = 5
        csr_op(csr_inst(12'h300, 5'd5, 3'b101, 5'd1), 32'h0);
        csr_read_check(12'h300, 32'h0000_0005);

        // CSRRS mstatus, rs1 value 8 => mstatus = 5 | 8 = D
        csr_op(csr_inst(12'h300, 5'd2, 3'b010, 5'd1), 32'h0000_0008);
        csr_read_check(12'h300, 32'h0000_000D);

        // CSRRC mstatus, rs1 value 1 => mstatus = D & ~1 = C
        csr_op(csr_inst(12'h300, 5'd3, 3'b011, 5'd1), 32'h0000_0001);
        csr_read_check(12'h300, 32'h0000_000C);

        // CSRRSI mstatus, zimm=3 => mstatus = C | 3 = F
        csr_op(csr_inst(12'h300, 5'd3, 3'b110, 5'd1), 32'h0);
        csr_read_check(12'h300, 32'h0000_000F);

        // CSRRCI mstatus, zimm=2 => mstatus = F & ~2 = D
        csr_op(csr_inst(12'h300, 5'd2, 3'b111, 5'd1), 32'h0);
        csr_read_check(12'h300, 32'h0000_000D);

        // CSRRS with rs1=x0 is read-only; mstatus must remain D.
        csr_op(csr_inst(12'h300, 5'd0, 3'b010, 5'd1), 32'hFFFF_FFFF);
        csr_read_check(12'h300, 32'h0000_000D);

        $display("[TB][PASS] Zicsr CSR semantics PASS");
        $finish;
    end
endmodule
