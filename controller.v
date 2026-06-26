`timescale 1ns/1fs
// Main controller / decoder. Global defaults at top keep every output latch-free.

module controller (
    input      [6:0]  opcode,
    input      [2:0]  funct3,
    input      [6:0]  funct7,
    input      [11:0] funct12,
    input             br_taken,

    output reg [3:0]  aluop,
    output reg        rf_en,
    output reg        sel_a,
    output reg        sel_b,
    output reg        rd_en,
    output reg        wr_en,
    output reg [1:0]  wb_sel,
    output reg [2:0]  mem_acc_mode,
    output reg [2:0]  br_type,
    output reg        br_take,
    output reg        csr_rd,
    output reg        csr_wr,
    output reg        is_mret,
    output reg        is_ecall,
    output reg        is_ebreak,
    output reg        illegal_inst
);

    always @(*) begin
        // ---------------- Global safe defaults ----------------
        aluop        = 4'b0000;
        rf_en        = 1'b0;
        sel_a        = 1'b1;
        sel_b        = 1'b0;
        rd_en        = 1'b0;
        wr_en        = 1'b0;
        wb_sel       = 2'b01;
        br_take      = 1'b0;
        mem_acc_mode = 3'b111;
        br_type      = 3'b011;
        csr_rd       = 1'b0;
        csr_wr       = 1'b0;
        is_mret      = 1'b0;
        is_ecall     = 1'b0;
        is_ebreak    = 1'b0;
        illegal_inst = 1'b0;

        case (opcode)

            // =====================================================
            // R-TYPE
            // =====================================================
            7'b0110011: begin
                rf_en        = 1'b1;
                sel_a        = 1'b1;
                sel_b        = 1'b0;
                rd_en        = 1'b0;
                wb_sel       = 2'b01;
                wr_en        = 1'b0;
                br_take      = 1'b0;
                mem_acc_mode = 3'b111;
                br_type      = 3'b011;
                csr_rd       = 1'b0;
                csr_wr       = 1'b0;
                is_mret      = 1'b0;

                case (funct3)
                    3'b000: begin
                        case (funct7)
                            7'b0000000: aluop = 4'b0000; // ADD
                            7'b0100000: aluop = 4'b0001; // SUB
                            default: begin
                                aluop        = 4'b0000;
                                rf_en        = 1'b0;
                                illegal_inst = 1'b1;
                            end
                        endcase
                    end

                    3'b001: begin
                        if (funct7 == 7'b0000000)
                            aluop = 4'b0010; // SLL
                        else begin
                            aluop        = 4'b0000;
                            rf_en        = 1'b0;
                            illegal_inst = 1'b1;
                        end
                    end

                    3'b010: begin
                        if (funct7 == 7'b0000000)
                            aluop = 4'b0011; // SLT
                        else begin
                            aluop        = 4'b0000;
                            rf_en        = 1'b0;
                            illegal_inst = 1'b1;
                        end
                    end

                    3'b011: begin
                        if (funct7 == 7'b0000000)
                            aluop = 4'b0100; // SLTU
                        else begin
                            aluop        = 4'b0000;
                            rf_en        = 1'b0;
                            illegal_inst = 1'b1;
                        end
                    end

                    3'b100: begin
                        if (funct7 == 7'b0000000)
                            aluop = 4'b0101; // XOR
                        else begin
                            aluop        = 4'b0000;
                            rf_en        = 1'b0;
                            illegal_inst = 1'b1;
                        end
                    end

                    3'b101: begin
                        case (funct7)
                            7'b0000000: aluop = 4'b0110; // SRL
                            7'b0100000: aluop = 4'b0111; // SRA
                            default: begin
                                aluop        = 4'b0000;
                                rf_en        = 1'b0;
                                illegal_inst = 1'b1;
                            end
                        endcase
                    end

                    3'b110: begin
                        if (funct7 == 7'b0000000)
                            aluop = 4'b1000; // OR
                        else begin
                            aluop        = 4'b0000;
                            rf_en        = 1'b0;
                            illegal_inst = 1'b1;
                        end
                    end

                    3'b111: begin
                        if (funct7 == 7'b0000000)
                            aluop = 4'b1001; // AND
                        else begin
                            aluop        = 4'b0000;
                            rf_en        = 1'b0;
                            illegal_inst = 1'b1;
                        end
                    end

                    default: begin
                        aluop        = 4'b0000;
                        rf_en        = 1'b0;
                        illegal_inst = 1'b1;
                    end
                endcase
            end

            // =====================================================
            // I-TYPE ALU
            // =====================================================
            7'b0010011: begin
                rf_en        = 1'b1;
                sel_a        = 1'b1;
                sel_b        = 1'b1;
                rd_en        = 1'b0;
                wb_sel       = 2'b01;
                wr_en        = 1'b0;
                br_take      = 1'b0;
                mem_acc_mode = 3'b111;
                br_type      = 3'b011;
                csr_rd       = 1'b0;
                csr_wr       = 1'b0;
                is_mret      = 1'b0;

                case (funct3)
                    3'b000: aluop = 4'b0000; // ADDI
                    3'b010: aluop = 4'b0011; // SLTI
                    3'b011: aluop = 4'b0100; // SLTIU
                    3'b100: aluop = 4'b0101; // XORI
                    3'b110: aluop = 4'b1000; // ORI
                    3'b111: aluop = 4'b1001; // ANDI

                    3'b001: begin
                        if (funct7 == 7'b0000000)
                            aluop = 4'b0010; // SLLI
                        else begin
                            aluop        = 4'b0000;
                            rf_en        = 1'b0;
                            illegal_inst = 1'b1;
                        end
                    end

                    3'b101: begin
                        case (funct7)
                            7'b0000000: aluop = 4'b0110; // SRLI
                            7'b0100000: aluop = 4'b0111; // SRAI
                            default: begin
                                aluop        = 4'b0000;
                                rf_en        = 1'b0;
                                illegal_inst = 1'b1;
                            end
                        endcase
                    end

                    default: begin
                        aluop        = 4'b0000;
                        rf_en        = 1'b0;
                        illegal_inst = 1'b1;
                    end
                endcase
            end

            // =====================================================
            // LOAD
            // =====================================================
            7'b0000011: begin
                rf_en        = 1'b1;
                sel_a        = 1'b1;
                sel_b        = 1'b1;
                rd_en        = 1'b1;
                wb_sel       = 2'b10;
                wr_en        = 1'b0;
                br_take      = 1'b0;
                aluop        = 4'b0000;
                br_type      = 3'b011;
                csr_rd       = 1'b0;
                csr_wr       = 1'b0;
                is_mret      = 1'b0;

                case (funct3)
                    3'b000: mem_acc_mode = 3'b000; // LB
                    3'b001: mem_acc_mode = 3'b001; // LH
                    3'b010: mem_acc_mode = 3'b010; // LW
                    3'b100: mem_acc_mode = 3'b011; // LBU
                    3'b101: mem_acc_mode = 3'b100; // LHU
                    default: begin
                        mem_acc_mode = 3'b111;
                        rf_en        = 1'b0;
                        rd_en        = 1'b0;
                        illegal_inst = 1'b1;
                    end
                endcase
            end

            // =====================================================
            // STORE
            // =====================================================
            7'b0100011: begin
                rf_en        = 1'b0;
                sel_a        = 1'b1;
                sel_b        = 1'b1;
                rd_en        = 1'b0;
                wb_sel       = 2'b01;
                wr_en        = 1'b1;
                br_take      = 1'b0;
                aluop        = 4'b0000;
                br_type      = 3'b011;
                csr_rd       = 1'b0;
                csr_wr       = 1'b0;
                is_mret      = 1'b0;

                case (funct3)
                    3'b000: mem_acc_mode = 3'b000; // SB
                    3'b001: mem_acc_mode = 3'b001; // SH
                    3'b010: mem_acc_mode = 3'b010; // SW
                    default: begin
                        mem_acc_mode = 3'b111;
                        wr_en        = 1'b0;
                        illegal_inst = 1'b1;
                    end
                endcase
            end

            // =====================================================
            // BRANCH
            // =====================================================
            7'b1100011: begin
                rf_en        = 1'b0;
                sel_a        = 1'b0;
                sel_b        = 1'b1;
                rd_en        = 1'b0;
                wb_sel       = 2'b01;
                wr_en        = 1'b0;
                aluop        = 4'b0000;
                br_type      = funct3;
                br_take      = br_taken;
                csr_rd       = 1'b0;
                csr_wr       = 1'b0;
                is_mret      = 1'b0;

                if ((funct3 == 3'b010) || (funct3 == 3'b011)) begin
                    br_take      = 1'b0;
                    illegal_inst = 1'b1;
                end
            end

            // =====================================================
            // LUI
            // =====================================================
            7'b0110111: begin
                rf_en        = 1'b1;
                sel_a        = 1'b0;
                sel_b        = 1'b1;
                rd_en        = 1'b0;
                wb_sel       = 2'b01;
                wr_en        = 1'b0;
                aluop        = 4'b1010;
                br_type      = 3'b011;
                br_take      = 1'b0;
                csr_rd       = 1'b0;
                csr_wr       = 1'b0;
                is_mret      = 1'b0;
            end

            // =====================================================
            // AUIPC
            // =====================================================
            7'b0010111: begin
                rf_en        = 1'b1;
                sel_a        = 1'b0;
                sel_b        = 1'b1;
                rd_en        = 1'b0;
                wb_sel       = 2'b01;
                wr_en        = 1'b0;
                aluop        = 4'b0000;
                br_type      = 3'b011;
                br_take      = 1'b0;
                csr_rd       = 1'b0;
                csr_wr       = 1'b0;
                is_mret      = 1'b0;
            end

            // =====================================================
            // JAL
            // =====================================================
            7'b1101111: begin
                rf_en        = 1'b1;
                sel_a        = 1'b0;
                sel_b        = 1'b1;
                rd_en        = 1'b0;
                wb_sel       = 2'b00;
                wr_en        = 1'b0;
                aluop        = 4'b0000;
                br_type      = 3'b011;
                br_take      = 1'b1;
                csr_rd       = 1'b0;
                csr_wr       = 1'b0;
                is_mret      = 1'b0;
            end

            // =====================================================
            // JALR
            // =====================================================
            7'b1100111: begin
                rf_en        = 1'b1;
                sel_a        = 1'b1;
                sel_b        = 1'b1;
                rd_en        = 1'b0;
                wb_sel       = 2'b00;
                wr_en        = 1'b0;
                aluop        = 4'b0000;
                br_type      = 3'b011;
                br_take      = 1'b1;
                csr_rd       = 1'b0;
                csr_wr       = 1'b0;
                is_mret      = 1'b0;

                if (funct3 != 3'b000) begin
                    rf_en        = 1'b0;
                    br_take      = 1'b0;
                    illegal_inst = 1'b1;
                end
            end

            // =====================================================
            // FENCE
            // =====================================================
            7'b0001111: begin
                aluop        = 4'b0000;
                rf_en        = 1'b0;
                sel_a        = 1'b1;
                sel_b        = 1'b0;
                rd_en        = 1'b0;
                wr_en        = 1'b0;
                wb_sel       = 2'b01;
                br_take      = 1'b0;
                mem_acc_mode = 3'b111;
                br_type      = 3'b011;
                csr_rd       = 1'b0;
                csr_wr       = 1'b0;
                is_mret      = 1'b0;
            end

            // =====================================================
            // SYSTEM / CSR
            // =====================================================
            7'b1110011: begin
                case (funct3)

                    3'b000: begin
                        rf_en        = 1'b0;
                        sel_a        = 1'b1;
                        sel_b        = 1'b0;
                        rd_en        = 1'b0;
                        wb_sel       = 2'b01;
                        wr_en        = 1'b0;
                        br_take      = 1'b0;
                        mem_acc_mode = 3'b111;
                        br_type      = 3'b011;
                        csr_rd       = 1'b0;
                        csr_wr       = 1'b0;
                        is_mret      = 1'b0;

                        case (funct12)
                            12'h302: begin
                                is_mret = 1'b1; // MRET
                            end
                            12'h000: begin
                                is_ecall = 1'b1;   // ECALL
			    end

			    12'h001: begin
    				is_ebreak = 1'b1;  // EBREAK
			    end

                            default: begin
                                is_mret      = 1'b0;
                                illegal_inst = 1'b1;
                            end
                        endcase
                    end

                    3'b001, // CSRRW
                    3'b010, // CSRRS
                    3'b011, // CSRRC
                    3'b101, // CSRRWI
                    3'b110, // CSRRSI
                    3'b111: begin // CSRRCI
                        rf_en        = 1'b1;
                        sel_a        = 1'b1;
                        sel_b        = 1'b0;
                        rd_en        = 1'b0;
                        wb_sel       = 2'b11;
                        wr_en        = 1'b0;
                        br_take      = 1'b0;
                        mem_acc_mode = 3'b111;
                        br_type      = 3'b011;
                        csr_rd       = 1'b1;
                        csr_wr       = 1'b1;
                        is_mret      = 1'b0;
                    end

                    default: begin
                        // funct3=100 is reserved/illegal for SYSTEM in RV32I/Zicsr.
                        rf_en        = 1'b0;
                        sel_a        = 1'b1;
                        sel_b        = 1'b0;
                        rd_en        = 1'b0;
                        wb_sel       = 2'b01;
                        wr_en        = 1'b0;
                        br_take      = 1'b0;
                        mem_acc_mode = 3'b111;
                        br_type      = 3'b011;
                        csr_rd       = 1'b0;
                        csr_wr       = 1'b0;
                        is_mret      = 1'b0;
                        illegal_inst = 1'b1;
                    end
                endcase
            end

            // =====================================================
            // UNKNOWN OPCODE
            // =====================================================
            default: begin
                aluop        = 4'b0000;
                rf_en        = 1'b0;
                sel_a        = 1'b1;
                sel_b        = 1'b0;
                rd_en        = 1'b0;
                wr_en        = 1'b0;
                wb_sel       = 2'b01;
                br_take      = 1'b0;
                mem_acc_mode = 3'b111;
                br_type      = 3'b011;
                csr_rd       = 1'b0;
                csr_wr       = 1'b0;
                is_mret      = 1'b0;
                illegal_inst = 1'b1;
            end

        endcase
    end

endmodule
