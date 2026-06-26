`timescale 1ns/1fs
// =====================================================================
//  SoC-integrated 3-stage pipelined RV32I processor  (Verilog-2001, Genus-synthesizable)
//  Stages : IF  |  DE (decode+execute)  |  MW (mem+writeback)
//  ALU add/sub use the CSLA-BEC adder_unit.
//

// =====================================================================

module processor_soc (
    input             clk,
    input             rst,
    input             timer_irq,
    input             spi_irq,
    input             jtag_irq,

    // ---------------- instruction-memory interface external SRAM wrapper ----------------
output        imem_req,
output [31:0] imem_addr,
input         imem_ready,
input  [31:0] imem_rdata,
input         imem_error,

    // ---------------- data-memory interface external SRAM wrapper ----------------
output        dmem_req,
output        dmem_wr,
output [31:0] dmem_addr,
output [ 2:0] dmem_acc_mode,
output [31:0] dmem_wdata,
input         dmem_ready,
input  [31:0] dmem_rdata,
input         dmem_error,

    // ---------------- retire-stage monitor / debug outputs ----------------
    output     [31:0] pc_debug,
    output     [31:0] inst_debug,
    output            rf_we,
    output     [ 4:0] rf_waddr,
    output     [31:0] rf_wdata,
    output            mem_we,
    output            mem_re,
    output     [31:0] mem_addr,
    output     [31:0] mem_wdata,
    output     [31:0] mem_rdata,
    output            br_taken_dbg,
    output            trap_taken,
    output     [31:0] epc_debug,
    output            timer_irq_dbg,
    output            illegal_inst_dbg
);   // interrupt sources: memory-mapped timer + SPI/JTAG
    wire timer_interrupt;
    assign timer_interrupt = timer_irq;
    wire        irq_valid;
    wire [31:0] irq_cause;
    // ---------------- PC ----------------
    wire [31:0] pc_out_IF;
    reg  [31:0] pc_out_DE;
    reg  [31:0] pc_out_MW;
    wire [31:0] new_pc;
    reg [31:0] pc_imem_reg;

    // ---------------- instruction ----------------
    wire [31:0] inst_IF;
    reg  [31:0] inst_DE;
    reg  [31:0] inst_MW;

    reg  [ 4:0] waddr;

    // ---------------- decoded fields ----------------
    wire [ 4:0] rs1_DE;
    wire [ 4:0] rs2_DE;
    wire [ 4:0] rd_DE;   wire [4:0] rd_MW;   // rd_MW derived from inst_MW (not pipelined)
    wire [ 6:0] opcode;
    wire [ 2:0] funct3;
    wire [ 6:0] funct7;
    wire        is_jalr_DE;

    // ---------------- datapath values ----------------
    wire [31:0] rdata1_DE;  reg [31:0] rdata1_MW;
    wire [31:0] rdata2_DE;  reg [31:0] rdata2_MW;
    reg  [31:0] store_wdata_MW;
    reg        load_valid_WB;
    reg [4:0]  load_rd_WB;
    reg [31:0] load_data_WB;
    reg        mem_load_valid_d;
    reg [4:0]  mem_load_rd_d;
    reg        mem_load_valid_d2;
    reg [4:0]  mem_load_rd_d2;
    wire       rf_en_final;
    wire [31:0] opr_a;
    wire [31:0] opr_b;
    reg  [31:0] opr_res_IF;
    wire [31:0] opr_res_DE;
    reg  [31:0] opr_res_MW;
    wire [31:0] imm_val_DE;
    reg  [31:0] wdata_DE;
    wire [31:0] wdata_MW;
    wire [31:0] rdata;
assign rdata = dmem_rdata;
    wire        br_taken;
    wire [ 3:0] aluop;

    // ---------------- control signals ----------------
    wire        rf_en_DE;  reg rf_en_MW;
    wire        sel_a;
    wire        sel_b;
    wire        rd_en_DE;  reg rd_en_MW;
    wire        wr_en_DE;  reg wr_en_MW;
    wire [ 1:0] wb_sel_DE; reg [1:0] wb_sel_MW;
    wire [ 2:0] mem_acc_mode_DE; reg [2:0] mem_acc_mode_MW;
    wire [ 2:0] br_type;
    wire        br_take_DE;
    reg         br_take_IF;
    wire        csr_rd_DE; reg csr_rd_MW;
    wire        csr_wr_DE; reg csr_wr_MW;
    wire        is_mret_DE;    reg is_mret_MW;
wire        is_ecall_DE;   reg is_ecall_MW;
wire        is_ebreak_DE;  reg is_ebreak_MW;

    wire [31:0] csr_rdata;
    reg illegal_inst_MW;
    wire        mem_half_access_MW;
wire        mem_word_access_MW;
wire        mem_misaligned_MW;
wire        load_misaligned_MW;
wire        store_misaligned_MW;
wire        mem_exception_MW;
wire [31:0] exception_cause_MW;
wire        csr_access_MW;
wire        csr_valid_funct3_MW;
wire        csr_implemented_addr_MW;
wire        csr_illegal_access_MW;
wire        instr_addr_misaligned_DE;
reg         instr_addr_misaligned_MW;
reg         imem_error_DE;
reg         imem_error_MW;
wire        dmem_load_access_fault_MW;
wire        dmem_store_access_fault_MW;
wire        dmem_access_fault_MW;
wire        exception_block_wb_MW;

    // ---------------- trap / epc ----------------
    reg  [31:0] epc_IF;
    wire [31:0] epc_MW;
    reg         epc_taken_IF;
    wire        epc_taken_MW;
    wire [31:0] epc_pc;
    wire illegal_inst_DE;

    // ---------------- hazard ----------------
    reg  [31:0] forward_opr_a;
    reg  [31:0] forward_opr_b;
    wire        forward_a;
    wire        forward_b;
    wire        stall_IF;
    wire        flush_DE;
    reg [31:0] hold_inst_IF;
reg [31:0] hold_pc_IF;
reg        hold_valid;
reg        branch_flush_d; 
reg        exception_flush_d;
wire exception_redirect_MW;
wire imem_wait;
wire dmem_wait;
wire data_wait;
wire fetch_valid;
wire pc_en;
wire [31:0] pc_fetch_tag;

// ---------------------------------------------------------------------
// AXI/SoC handshake control
// ---------------------------------------------------------------------
// The AXI instruction bus returns imem_ready as a pulse only when a real
// instruction word is available. Therefore PC must advance only on a valid
// instruction fetch. If imem_ready is low, insert a NOP bubble instead of
// executing/storing stale instructions.
//
// During an active data transaction, hold the current MW memory operation
// until dmem_ready becomes high. When dmem_ready is high, allow MW to
// advance normally; the AXI wrapper provides a clean one-cycle ready pulse.
assign fetch_valid = imem_ready;
assign imem_wait   = imem_req && !imem_ready;
assign dmem_wait   = dmem_req && !dmem_ready;
assign data_wait   = dmem_wait;

wire fetch_stall;
assign fetch_stall =
    (stall_IF | hold_valid | data_wait | ~fetch_valid) &
    ~(br_take_DE | branch_flush_d |
      exception_redirect_MW | epc_taken_MW | exception_flush_d);

// ---------------------------------------------------------------------
// PC / instruction alignment fix for AXI/synchronous instruction fetch
// ---------------------------------------------------------------------
// In this SoC fetch path, the instruction returned with imem_ready belongs
// to the address issued one word earlier. Therefore the PC tag carried with
// inst_DE must be pc_out_IF - 4. This keeps AUIPC, JAL target calculation,
// and JAL/JALR link writeback aligned to the instruction being executed.
assign pc_fetch_tag = (pc_out_IF < 32'd4) ? 32'b0 : (pc_out_IF - 32'd4);

// br_take_DE must update the PC to the branch/jump target immediately.
// branch_flush_d is only the delayed flush cycle for the stale instruction
// return; during that cycle, hold PC at the redirected target. Otherwise
// the first instruction at the branch/JAL/JALR target is fetched and flushed,
// causing the core to start at target+4.
assign pc_en = (~fetch_stall) & (~branch_flush_d) & (~exception_flush_d);
    // =================== Timer interrupt source ===================
    // SoC version: timer interrupt comes from memory-mapped timer peripheral.
    // The fixed internal timer is removed for tapeout-style SoC integration.

    interrupt_controller interrupt_controller_i (
    .timer_irq (timer_interrupt),
     .spi_irq(spi_irq),
    .jtag_irq  (jtag_irq),

    .irq_valid (irq_valid),
    .irq_cause (irq_cause)
);

    // =================== Instruction Fetch ===================
    mux_2x1 mux_2x1_pc (
        .in_0        (pc_out_IF + 32'd4),
        .in_1        (opr_res_IF),
        .select_line (br_take_IF),
        .out         (new_pc)
    );

    mux_2x1 mux_2x1_epc (
        .in_0        (new_pc),
        .in_1        (epc_IF),
        .select_line (epc_taken_IF),
        .out         (epc_pc)
    );

   pc pc_i (
    .clk    (clk),
    .rst    (rst),
    .en (pc_en),
    .pc_in  (epc_pc),
    .pc_out (pc_out_IF)
);
     

// delay PC to match synchronous SRAM output instruction
always @(posedge clk) begin
    if (rst)
        pc_imem_reg <= 32'b0;
    else if (pc_en)
        pc_imem_reg <= pc_out_IF;
end
always @(posedge clk) begin
    if (rst) begin
        hold_inst_IF <= 32'h00000013;
        hold_pc_IF   <= 32'b0;
        hold_valid   <= 1'b0;
    end
    else begin
        if (br_take_DE || branch_flush_d ||
            exception_redirect_MW || epc_taken_MW || exception_flush_d) begin
            hold_inst_IF <= 32'h00000013;
            hold_pc_IF   <= 32'b0;
            hold_valid   <= 1'b0;
        end
        else if (stall_IF && !hold_valid) begin
            hold_inst_IF <= inst_IF;
            // Hold the same PC tag that belongs to the returned instruction.
            hold_pc_IF   <= pc_fetch_tag;
            hold_valid   <= 1'b1;
        end
        else if (hold_valid && load_valid_WB) begin
            hold_valid <= 1'b0;
        end
    end
end
always @(posedge clk) begin
    if (rst) begin
        branch_flush_d    <= 1'b0;
        exception_flush_d <= 1'b0;
    end
    else begin
        branch_flush_d    <= br_take_DE;
        exception_flush_d <= exception_redirect_MW | epc_taken_MW;
    end
end
    // Instruction memory is EXTERNAL: drive the fetch address out, take the
    // instruction word in. (No inst_mem instance inside the core.)
 // Single-master AXI correctness rule:
 // Do not issue/fetch a new instruction while a data-memory transaction is
 // active in MW. Earlier versions kept imem_req high during store/load waits;
 // an imem_ready pulse could then arrive while IF/DE was frozen by data_wait,
 // causing the next dense instruction to be dropped. Gating fetch during dmem
 // operations avoids lost instruction returns. This may insert bubbles after
 // load/store, but normal RV32I software no longer needs NOP padding.
 assign imem_req  = ~dmem_req;
assign imem_addr = pc_out_IF;
assign inst_IF   = imem_ready ? (imem_error ? 32'h00000013 : imem_rdata) : 32'h00000013;

    // IF <-> DE pipeline buffer
// IF <-> DE pipeline buffer
always @(posedge clk) begin
    if (rst) begin
        pc_out_DE     <= 32'b0;
        inst_DE       <= 32'h00000013;
        imem_error_DE <= 1'b0;
    end
    else if (br_take_DE || branch_flush_d ||
             exception_redirect_MW || epc_taken_MW || exception_flush_d) begin
        pc_out_DE     <= 32'b0;
        inst_DE       <= 32'h00000013;
        imem_error_DE <= 1'b0;
    end
    else if (data_wait) begin
        // Keep the next decoded instruction while a data transaction is active.
        pc_out_DE     <= pc_out_DE;
        inst_DE       <= inst_DE;
        imem_error_DE <= imem_error_DE;
    end
    else if (stall_IF && !load_valid_WB) begin
        pc_out_DE     <= 32'b0;
        inst_DE       <= 32'h00000013;
        imem_error_DE <= 1'b0;
    end
    else if (hold_valid && load_valid_WB) begin
        pc_out_DE     <= hold_pc_IF;
        inst_DE       <= hold_inst_IF;
        imem_error_DE <= 1'b0;
    end
    else if (fetch_valid) begin
        // Tag the returned instruction with the instruction PC, not the
        // already-advanced fetch PC. This is required for AUIPC/JAL/JALR.
        pc_out_DE     <= pc_fetch_tag;
        inst_DE       <= inst_IF;
        imem_error_DE <= imem_error;
    end
    else begin
        // No valid instruction this cycle: inject a bubble instead of
        // advancing with a fake NOP at a skipped PC.
        pc_out_DE     <= 32'b0;
        inst_DE       <= 32'h00000013;
        imem_error_DE <= 1'b0;
    end
end
    // =================== Decode-Execute ===================
    inst_dec inst_dec_i (
        .inst   (inst_DE),
        .rs1    (rs1_DE),
        .rs2    (rs2_DE),
        .rd     (rd_DE),
        .opcode (opcode),
        .funct3 (funct3),
        .funct7 (funct7)
    );
assign is_jalr_DE = (opcode == 7'b1100111) && (funct3 == 3'b000);
assign rf_en_final =
    rf_en_MW &
    ~rd_en_MW &
    ~exception_block_wb_MW &
    (rd_MW != 5'd0);

    reg_file reg_file_i (
        .clk    (clk),
        .rst    (rst),
        .rf_en (rf_en_final |
        (load_valid_WB && (load_rd_WB != 5'd0))),
        .rs1    (rs1_DE),
        .rs2    (rs2_DE),
        .rd     (load_valid_WB ? load_rd_WB : waddr),
        .wdata  (load_valid_WB ? load_data_WB : wdata_DE),
        .rdata1 (rdata1_DE),
        .rdata2 (rdata2_DE)
    );

    controller controller_i (
        .opcode       (opcode),
        .funct3       (funct3),
        .funct7       (funct7),
.funct12      (inst_DE[31:20]),
.br_taken     (br_taken),
        .aluop        (aluop),
        .rf_en        (rf_en_DE),
        .sel_a        (sel_a),
        .sel_b        (sel_b),
        .rd_en        (rd_en_DE),
        .wr_en        (wr_en_DE),
        .wb_sel       (wb_sel_DE),
        .mem_acc_mode (mem_acc_mode_DE),
        .br_type      (br_type),
        .br_take      (br_take_DE),
        .csr_rd       (csr_rd_DE),
        .csr_wr       (csr_wr_DE),
      .is_mret      (is_mret_DE),
.is_ecall     (is_ecall_DE),
.is_ebreak    (is_ebreak_DE),
.illegal_inst (illegal_inst_DE)
    );

    imm_gen imm_gen_i (
        .inst    (inst_DE),
        .imm_val (imm_val_DE)
    );

    // forwarding muxes : forward the REAL writeback value (wdata_MW), so a
    // dependent instruction right after a load / JAL / JALR / CSR gets the
    // correct value (loaded data / pc+4 / csr data), not just the ALU result.
    // forward_a/forward_b are already gated on rf_en_MW inside hazard_unit.
  always @(*) begin
    if (load_valid_WB && (rs1_DE == load_rd_WB) && (rs1_DE != 5'b0))
        forward_opr_a = load_data_WB;
    else if (forward_a && !rd_en_MW)
        forward_opr_a = wdata_MW;
    else
        forward_opr_a = rdata1_DE;
end

always @(*) begin
    if (load_valid_WB && (rs2_DE == load_rd_WB) && (rs2_DE != 5'b0))
        forward_opr_b = load_data_WB;
    else if (forward_b && !rd_en_MW)
        forward_opr_b = wdata_MW;
    else
        forward_opr_b = rdata2_DE;
end

    mux_2x1 mux_2x1_alu_opr_a (
        .in_0        (pc_out_DE),
        .in_1        (forward_opr_a),
        .select_line (sel_a),
        .out         (opr_a)
    );

    mux_2x1 mux_2x1_alu_opr_b (
        .in_0        (forward_opr_b),
        .in_1        (imm_val_DE),
        .select_line (sel_b),
        .out         (opr_b)
    );

    alu alu_i (
        .aluop   (aluop),
        .opr_a   (opr_a),
        .opr_b   (opr_b),
        .opr_res (opr_res_DE)
    );

    // Branch comparator must use the FORWARDED operands (not the raw register
    // reads): with a posedge-write register file, a branch that depends on the
    // immediately-preceding instruction would otherwise compare stale data.
    br_cond br_cond_i (
        .rdata1   (forward_opr_a),
        .rdata2   (forward_opr_b),
        .br_type  (br_type),
        .br_taken (br_taken)
    );

always @(*) begin
    br_take_IF = br_take_DE;

    if (is_jalr_DE)
        opr_res_IF = opr_res_DE & 32'hFFFF_FFFE;
    else
        opr_res_IF = opr_res_DE;
end

// RV32I without the compressed extension has 4-byte instruction alignment.
// Any taken branch/JAL/JALR target with target[1:0] != 2'b00 traps.
assign instr_addr_misaligned_DE = br_take_DE && (opr_res_IF[1:0] != 2'b00);
    // DE <-> MW pipeline buffer
   always @(posedge clk) begin
    if (rst) begin
        pc_out_MW       <= 32'b0;
        inst_MW         <= 32'h00000013;
        opr_res_MW      <= 32'b0;
        rdata1_MW       <= 32'b0;
        rdata2_MW       <= 32'b0;
        rf_en_MW        <= 1'b0;
        rd_en_MW        <= 1'b0;
        wr_en_MW        <= 1'b0;
        mem_acc_mode_MW <= 3'b0;
        csr_rd_MW       <= 1'b0;
        csr_wr_MW       <= 1'b0;
        is_mret_MW      <= 1'b0;
        wb_sel_MW       <= 2'b0;
        store_wdata_MW  <= 32'b0;
        illegal_inst_MW <= 1'b0;
        instr_addr_misaligned_MW <= 1'b0;
        imem_error_MW <= 1'b0;
        is_ecall_MW  <= 1'b0;
        is_ebreak_MW <= 1'b0;

    end
 else if (exception_redirect_MW || epc_taken_MW || exception_flush_d) begin
    pc_out_MW       <= 32'b0;
    inst_MW         <= 32'h00000013;
    opr_res_MW      <= 32'b0;
    rdata1_MW       <= 32'b0;
    rdata2_MW       <= 32'b0;
    store_wdata_MW  <= 32'b0;
    rf_en_MW        <= 1'b0;
    rd_en_MW        <= 1'b0;
    wr_en_MW        <= 1'b0;
    mem_acc_mode_MW <= 3'b0;
    csr_rd_MW       <= 1'b0;
    csr_wr_MW       <= 1'b0;
    is_mret_MW      <= 1'b0;
    wb_sel_MW       <= 2'b0;
    illegal_inst_MW <= 1'b0;
    instr_addr_misaligned_MW <= 1'b0;
    imem_error_MW <= 1'b0;
    is_ecall_MW  <= 1'b0;
    is_ebreak_MW <= 1'b0;
end
else if (data_wait) begin
    pc_out_MW       <= pc_out_MW;
    inst_MW         <= inst_MW;
    opr_res_MW      <= opr_res_MW;
    rdata1_MW       <= rdata1_MW;
    rdata2_MW       <= rdata2_MW;
    store_wdata_MW  <= store_wdata_MW;
    rf_en_MW        <= rf_en_MW;
    rd_en_MW        <= rd_en_MW;
    wr_en_MW        <= wr_en_MW;
    mem_acc_mode_MW <= mem_acc_mode_MW;
    csr_rd_MW       <= csr_rd_MW;
    csr_wr_MW       <= csr_wr_MW;
    is_mret_MW      <= is_mret_MW;
    wb_sel_MW       <= wb_sel_MW;
    illegal_inst_MW <= illegal_inst_MW;
    instr_addr_misaligned_MW <= instr_addr_misaligned_MW;
    imem_error_MW <= imem_error_MW;
    is_ecall_MW  <= is_ecall_MW;
    is_ebreak_MW <= is_ebreak_MW;
end
else begin
    pc_out_MW       <= pc_out_DE;
    inst_MW         <= inst_DE;
    opr_res_MW      <= opr_res_DE;
    rdata1_MW       <= forward_opr_a;
    rdata2_MW       <= rdata2_DE;
    store_wdata_MW  <= forward_opr_b;
    rf_en_MW        <= rf_en_DE;
    rd_en_MW        <= rd_en_DE;
    wr_en_MW        <= wr_en_DE;
    mem_acc_mode_MW <= mem_acc_mode_DE;
    csr_rd_MW       <= csr_rd_DE;
    csr_wr_MW       <= csr_wr_DE;
    is_mret_MW      <= is_mret_DE;
    wb_sel_MW       <= wb_sel_DE;
    illegal_inst_MW <= illegal_inst_DE;
    instr_addr_misaligned_MW <= instr_addr_misaligned_DE;
    imem_error_MW <= imem_error_DE;
    is_ecall_MW  <= is_ecall_DE;
    is_ebreak_MW <= is_ebreak_DE;
end
end
    // =================== Memory-Writeback ===================
 always @(posedge clk) begin
    if (rst) begin
        mem_load_valid_d  <= 1'b0;
        mem_load_rd_d     <= 5'b0;
        mem_load_valid_d2 <= 1'b0;
        mem_load_rd_d2    <= 5'b0;

        load_valid_WB     <= 1'b0;
        load_rd_WB        <= 5'b0;
        load_data_WB      <= 32'b0;
    end
    else begin
       mem_load_valid_d  <= rd_en_MW & ~load_misaligned_MW & dmem_ready & ~dmem_error;
        mem_load_rd_d     <= rd_MW;

        mem_load_valid_d2 <= mem_load_valid_d;
        mem_load_rd_d2    <= mem_load_rd_d;

        load_valid_WB     <= mem_load_valid_d2;
        load_rd_WB        <= mem_load_rd_d2;
        load_data_WB      <= rdata;
    end
end
    assign mem_half_access_MW =
    (mem_acc_mode_MW == 3'b001) ||   // HALFWORD
    (mem_acc_mode_MW == 3'b100);     // HALFWORD_UNSIGNED

assign mem_word_access_MW =
    (mem_acc_mode_MW == 3'b010);     // WORD

assign mem_misaligned_MW =
    (mem_half_access_MW && opr_res_MW[0]) ||
    (mem_word_access_MW && |opr_res_MW[1:0]);

assign load_misaligned_MW  = rd_en_MW & mem_misaligned_MW;
assign store_misaligned_MW = wr_en_MW & mem_misaligned_MW;

assign mem_exception_MW = load_misaligned_MW | store_misaligned_MW;

assign csr_access_MW =
    (inst_MW[6:0] == 7'b1110011) &&
    (inst_MW[14:12] != 3'b000);

assign csr_valid_funct3_MW =
    (inst_MW[14:12] == 3'b001) ||
    (inst_MW[14:12] == 3'b010) ||
    (inst_MW[14:12] == 3'b011) ||
    (inst_MW[14:12] == 3'b101) ||
    (inst_MW[14:12] == 3'b110) ||
    (inst_MW[14:12] == 3'b111);

assign csr_implemented_addr_MW =
    (inst_MW[31:20] == 12'h300) ||
    (inst_MW[31:20] == 12'h304) ||
    (inst_MW[31:20] == 12'h305) ||
    (inst_MW[31:20] == 12'h341) ||
    (inst_MW[31:20] == 12'h342) ||
    (inst_MW[31:20] == 12'h344);

assign csr_illegal_access_MW =
    csr_access_MW &&
    (!csr_valid_funct3_MW || !csr_implemented_addr_MW);

assign dmem_load_access_fault_MW  = rd_en_MW & dmem_ready & dmem_error;
assign dmem_store_access_fault_MW = wr_en_MW & dmem_ready & dmem_error;
assign dmem_access_fault_MW = dmem_load_access_fault_MW | dmem_store_access_fault_MW;

assign exception_redirect_MW =
    imem_error_MW |
    instr_addr_misaligned_MW |
    illegal_inst_MW |
    csr_illegal_access_MW |
    mem_exception_MW |
    dmem_access_fault_MW |
    is_ecall_MW |
    is_ebreak_MW;

assign exception_block_wb_MW =
    imem_error_MW |
    instr_addr_misaligned_MW |
    illegal_inst_MW |
    csr_illegal_access_MW |
    mem_exception_MW |
    dmem_access_fault_MW |
    is_ecall_MW |
    is_ebreak_MW;

assign exception_cause_MW =
    instr_addr_misaligned_MW ? 32'd0  :
    imem_error_MW           ? 32'd1  :
    (illegal_inst_MW | csr_illegal_access_MW) ? 32'd2 :
    is_ebreak_MW            ? 32'd3  :
    load_misaligned_MW      ? 32'd4  :
    dmem_load_access_fault_MW ? 32'd5 :
    store_misaligned_MW     ? 32'd6  :
    dmem_store_access_fault_MW ? 32'd7 :
    is_ecall_MW             ? 32'd11 :
                              32'd0;
  csr_reg csr_reg_i (
    .clk             (clk),
    .rst             (rst),

    .addr            (opr_res_MW),
    .wdata           (rdata1_MW),
    .pc              (pc_out_MW),

    .irq_valid       (irq_valid),
    .irq_cause       (irq_cause),

    .exception       (exception_redirect_MW),
    .exception_cause (exception_cause_MW),

    .csr_rd          (csr_rd_MW),
    .csr_wr          (csr_wr_MW & ~exception_block_wb_MW),
    .is_mret         (is_mret_MW),
    .inst            (inst_MW),

    .rdata           (csr_rdata),
    .epc             (epc_MW),
    .epc_taken       (epc_taken_MW)
);

    mux_4x1 wb_mux (
        .in_0        (pc_out_MW + 32'd4),
        .in_1        (opr_res_MW),
        .in_2        (rdata),
        .in_3        (csr_rdata),
        .select_line (wb_sel_MW),
        .out         (wdata_MW)
    );

    // feedback to IF (epc)
    always @(*) begin
        epc_IF       = epc_MW;
        epc_taken_IF = epc_taken_MW;
    end

    // feedback to DE (writeback)
    always @(*) begin
        waddr    = inst_MW[11:7];
        wdata_DE = wdata_MW;
    end

    // =================== Hazard Unit ===================
        hazard_unit hazard_unit_i (
        .rs1_DE    (rs1_DE),
        .rs2_DE    (rs2_DE),
        .rd_MW     (rd_MW),
        .rf_en_MW  (rf_en_MW),
        .load_valid_WB(load_valid_WB),
        .forward_a (forward_a),
        .forward_b (forward_b),
        .inst_IF   (inst_IF),
        .rd_DE     (rd_DE),
        .wb_sel_DE (wb_sel_DE),
        .br_taken  (br_take_DE),
        .stall_IF  (stall_IF),
        .flush_DE  (flush_DE)
    );
    // =================== Retire-stage monitor / debug bus ===================
assign pc_debug   = pc_out_MW;
assign inst_debug = inst_MW;

assign rd_MW     = inst_MW[11:7];
assign rf_we =
    rf_en_final |
    (load_valid_WB && (load_rd_WB != 5'd0));

assign rf_waddr = load_valid_WB ? load_rd_WB : waddr;
assign rf_wdata = load_valid_WB ? load_data_WB : wdata_DE;

// ready/valid data memory request interface
assign dmem_req =
    (rd_en_MW | wr_en_MW) &
    ~exception_block_wb_MW;

assign dmem_wr =
    wr_en_MW &
    ~exception_block_wb_MW;

assign dmem_addr      = opr_res_MW;
assign dmem_acc_mode  = mem_acc_mode_MW;
assign dmem_wdata     = store_wdata_MW;

// debug mirrors
assign mem_we    = dmem_req & dmem_wr;
assign mem_re    = dmem_req & ~dmem_wr;
assign mem_addr  = dmem_addr;
assign mem_wdata = dmem_wdata;
assign mem_rdata = dmem_rdata;

assign br_taken_dbg     = br_take_DE;
assign trap_taken       = epc_taken_MW;
assign epc_debug        = epc_MW;
assign timer_irq_dbg    = timer_interrupt;
assign illegal_inst_dbg = illegal_inst_MW | csr_illegal_access_MW;
endmodule
