// Auto-generated expected data SRAM results.
localparam integer NUM_EXPECTED = 66;
reg [31:0] exp_addr [0:NUM_EXPECTED-1];
reg [31:0] exp_value [0:NUM_EXPECTED-1];
reg [31:0] exp_mask [0:NUM_EXPECTED-1];
initial begin
  exp_addr[0] = 32'h00020100; exp_value[0] = 32'h0000000d; exp_mask[0] = 32'hffffffff; // ADD
  exp_addr[1] = 32'h00020104; exp_value[1] = 32'h00000007; exp_mask[1] = 32'hffffffff; // SUB
  exp_addr[2] = 32'h00020108; exp_value[2] = 32'h00000018; exp_mask[2] = 32'hffffffff; // SLL
  exp_addr[3] = 32'h0002010c; exp_value[3] = 32'h00000001; exp_mask[3] = 32'hffffffff; // SLT signed
  exp_addr[4] = 32'h00020110; exp_value[4] = 32'h00000000; exp_mask[4] = 32'hffffffff; // SLTU unsigned
  exp_addr[5] = 32'h00020114; exp_value[5] = 32'h00000009; exp_mask[5] = 32'hffffffff; // XOR
  exp_addr[6] = 32'h00020118; exp_value[6] = 32'h00000001; exp_mask[6] = 32'hffffffff; // SRL
  exp_addr[7] = 32'h0002011c; exp_value[7] = 32'hffffffff; exp_mask[7] = 32'hffffffff; // SRA
  exp_addr[8] = 32'h00020120; exp_value[8] = 32'h0000000b; exp_mask[8] = 32'hffffffff; // OR
  exp_addr[9] = 32'h00020124; exp_value[9] = 32'h00000002; exp_mask[9] = 32'hffffffff; // AND
  exp_addr[10] = 32'h00020128; exp_value[10] = 32'h00000005; exp_mask[10] = 32'hffffffff; // ADDI
  exp_addr[11] = 32'h0002012c; exp_value[11] = 32'h00000001; exp_mask[11] = 32'hffffffff; // SLTI
  exp_addr[12] = 32'h00020130; exp_value[12] = 32'h00000000; exp_mask[12] = 32'hffffffff; // SLTIU
  exp_addr[13] = 32'h00020134; exp_value[13] = 32'h00000009; exp_mask[13] = 32'hffffffff; // XORI
  exp_addr[14] = 32'h00020138; exp_value[14] = 32'h0000000b; exp_mask[14] = 32'hffffffff; // ORI
  exp_addr[15] = 32'h0002013c; exp_value[15] = 32'h00000002; exp_mask[15] = 32'hffffffff; // ANDI
  exp_addr[16] = 32'h00020140; exp_value[16] = 32'h0000000c; exp_mask[16] = 32'hffffffff; // SLLI
  exp_addr[17] = 32'h00020144; exp_value[17] = 32'h00000008; exp_mask[17] = 32'hffffffff; // SRLI
  exp_addr[18] = 32'h00020148; exp_value[18] = 32'hfffffffc; exp_mask[18] = 32'hffffffff; // SRAI
  exp_addr[19] = 32'h0002014c; exp_value[19] = 32'h12345000; exp_mask[19] = 32'hffffffff; // LUI
  exp_addr[20] = 32'h00020150; exp_value[20] = 32'h00011264; exp_mask[20] = 32'hffffffff; // AUIPC
  exp_addr[21] = 32'h00020154; exp_value[21] = 32'h00000000; exp_mask[21] = 32'hffffffff; // X0 hardwired zero
  exp_addr[22] = 32'h00020158; exp_value[22] = 32'h00000001; exp_mask[22] = 32'hffffffff; // FENCE as safe no-op/barrier
  exp_addr[23] = 32'h0002015c; exp_value[23] = 32'h11223344; exp_mask[23] = 32'hffffffff; // LW/SW
  exp_addr[24] = 32'h00020160; exp_value[24] = 32'h00000033; exp_mask[24] = 32'hffffffff; // LB positive
  exp_addr[25] = 32'h00020164; exp_value[25] = 32'h00000022; exp_mask[25] = 32'hffffffff; // LBU
  exp_addr[26] = 32'h00020168; exp_value[26] = 32'h00001122; exp_mask[26] = 32'hffffffff; // LH positive
  exp_addr[27] = 32'h0002016c; exp_value[27] = 32'h00003344; exp_mask[27] = 32'hffffffff; // LHU
  exp_addr[28] = 32'h00020170; exp_value[28] = 32'hffffffff; exp_mask[28] = 32'hffffffff; // LB sign extend
  exp_addr[29] = 32'h00020174; exp_value[29] = 32'h000000ff; exp_mask[29] = 32'hffffffff; // LBU zero extend
  exp_addr[30] = 32'h00020178; exp_value[30] = 32'hffff8000; exp_mask[30] = 32'hffffffff; // LH sign extend
  exp_addr[31] = 32'h0002017c; exp_value[31] = 32'h00008000; exp_mask[31] = 32'hffffffff; // LHU zero extend
  exp_addr[32] = 32'h00020004; exp_value[32] = 32'h800000ff; exp_mask[32] = 32'hffffffff; // raw SB/SH lane merge at DMEM[1]
  exp_addr[33] = 32'h00020180; exp_value[33] = 32'h00000001; exp_mask[33] = 32'hffffffff; // beq taken path
  exp_addr[34] = 32'h00020180; exp_value[34] = 32'h00000001; exp_mask[34] = 32'hffffffff; // beq taken path
  exp_addr[35] = 32'h00020184; exp_value[35] = 32'h00000001; exp_mask[35] = 32'hffffffff; // bne taken path
  exp_addr[36] = 32'h00020184; exp_value[36] = 32'h00000001; exp_mask[36] = 32'hffffffff; // bne taken path
  exp_addr[37] = 32'h00020188; exp_value[37] = 32'h00000001; exp_mask[37] = 32'hffffffff; // blt taken path
  exp_addr[38] = 32'h00020188; exp_value[38] = 32'h00000001; exp_mask[38] = 32'hffffffff; // blt taken path
  exp_addr[39] = 32'h0002018c; exp_value[39] = 32'h00000001; exp_mask[39] = 32'hffffffff; // bge taken path
  exp_addr[40] = 32'h0002018c; exp_value[40] = 32'h00000001; exp_mask[40] = 32'hffffffff; // bge taken path
  exp_addr[41] = 32'h00020190; exp_value[41] = 32'h00000001; exp_mask[41] = 32'hffffffff; // bltu taken path
  exp_addr[42] = 32'h00020190; exp_value[42] = 32'h00000001; exp_mask[42] = 32'hffffffff; // bltu taken path
  exp_addr[43] = 32'h00020194; exp_value[43] = 32'h00000001; exp_mask[43] = 32'hffffffff; // bgeu taken path
  exp_addr[44] = 32'h00020194; exp_value[44] = 32'h00000001; exp_mask[44] = 32'hffffffff; // bgeu taken path
  exp_addr[45] = 32'h00020198; exp_value[45] = 32'h00000001; exp_mask[45] = 32'hffffffff; // BEQ not taken
  exp_addr[46] = 32'h00020198; exp_value[46] = 32'h00000001; exp_mask[46] = 32'hffffffff; // BEQ not taken
  exp_addr[47] = 32'h0002019c; exp_value[47] = 32'h00000001; exp_mask[47] = 32'hffffffff; // JAL path
  exp_addr[48] = 32'h0002019c; exp_value[48] = 32'h00000001; exp_mask[48] = 32'hffffffff; // JAL path
  exp_addr[49] = 32'h000201a0; exp_value[49] = 32'h000106dc; exp_mask[49] = 32'hffffffff; // JAL link
  exp_addr[50] = 32'h000201a4; exp_value[50] = 32'h00000001; exp_mask[50] = 32'hffffffff; // JALR path
  exp_addr[51] = 32'h000201a4; exp_value[51] = 32'h00000001; exp_mask[51] = 32'hffffffff; // JALR path
  exp_addr[52] = 32'h000201a8; exp_value[52] = 32'h00010750; exp_mask[52] = 32'hffffffff; // JALR link
  exp_addr[53] = 32'h000201ac; exp_value[53] = 32'h00000000; exp_mask[53] = 32'hffffffff; // CSRRWI old
  exp_addr[54] = 32'h000201b0; exp_value[54] = 32'h00000005; exp_mask[54] = 32'hffffffff; // CSRRS read only
  exp_addr[55] = 32'h000201b4; exp_value[55] = 32'h00000005; exp_mask[55] = 32'hffffffff; // CSRRS old
  exp_addr[56] = 32'h000201b8; exp_value[56] = 32'h0000000d; exp_mask[56] = 32'hffffffff; // CSRRS after set
  exp_addr[57] = 32'h000201bc; exp_value[57] = 32'h0000000d; exp_mask[57] = 32'hffffffff; // CSRRC old
  exp_addr[58] = 32'h000201c0; exp_value[58] = 32'h0000000c; exp_mask[58] = 32'hffffffff; // CSRRC after clear
  exp_addr[59] = 32'h000201c4; exp_value[59] = 32'h0000000c; exp_mask[59] = 32'hffffffff; // CSRRSI old
  exp_addr[60] = 32'h000201c8; exp_value[60] = 32'h0000000f; exp_mask[60] = 32'hffffffff; // CSRRSI after
  exp_addr[61] = 32'h000201cc; exp_value[61] = 32'h0000000f; exp_mask[61] = 32'hffffffff; // CSRRCI old
  exp_addr[62] = 32'h000201d0; exp_value[62] = 32'h0000000d; exp_mask[62] = 32'hffffffff; // CSRRCI after
  exp_addr[63] = 32'h000201d4; exp_value[63] = 32'h00000001; exp_mask[63] = 32'hffffffff; // Timer status irq_pending
  exp_addr[64] = 32'h000201d8; exp_value[64] = 32'h00000002; exp_mask[64] = 32'hffffffff; // SPI status done
  exp_addr[65] = 32'h000201dc; exp_value[65] = 32'h0000003c; exp_mask[65] = 32'hffffffff; // SPI RX data
end
