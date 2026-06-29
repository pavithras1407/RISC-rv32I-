# RV32I SoC – 32-bit RISC-V Processor in Verilog HDL
## Overview
This repository contains the RTL implementation of a 32-bit RISC-V RV32I System-on-Chip (SoC) developed in Verilog HDL. The design implements a 3-stage pipelined processor compliant with the RISC-V RV32I Base Integer Instruction Set Architecture (ISA) and integrates an AXI4-Lite based SoC architecture with on-chip memory and peripherals.

The processor is designed using a modular RTL architecture to facilitate verification, synthesis, and future feature expansion. The repository also includes verification testbenches, simulation scripts, and SoC-level validation programs.


# Processor Specifications

 Parameter | Description |
|-----------|-------------|
| ISA | RISC-V RV32I |
| Data Width | 32-bit |
| Address Width | 32-bit |
| Pipeline | 3-stage |
| RTL Language | Verilog HDL |
| Privilege Mode | Machine Mode (M-Mode) |
| CSR Support | Zicsr Instructions |
| Bus Interface | AXI4-Lite Master |
| Endianness | Little Endian |

---

# Pipeline Architecture

The processor implements a 3-stage pipeline:

```
                +------------------------+
                |  Instruction Fetch     |
                |          (IF)          |
                +-----------+------------+
                            |
                            ▼
                +------------------------+
                | Decode & Execute (DE)  |
                +-----------+------------+
                            |
                            ▼
                +------------------------+
                | Memory & Write Back    |
                |          (MW)          |
                +------------------------+

### Instruction Fetch (IF)

- Program Counter (PC)
- Instruction Memory Access
- Sequential PC Generation
- Branch Target Selection
- Jump Target Selection
- Exception/Interrupt PC Redirection

### Decode & Execute (DE)

- Instruction Decode
- Immediate Generation
- Register File Read
- ALU Operations
- Branch Condition Evaluation
- Address Generation
- CSR Instruction Execution
- Hazard Detection
- Data Forwarding

### Memory & Write Back (MW)

- Load Operations
- Store Operations
- AXI Memory Transactions
- CSR Write-back
- Register File Write-back

---

# Processor Functional Units

The processor consists of the following functional blocks:

- Program Counter (PC)
- Instruction Decoder
- Control Unit
- Immediate Generator
- Register File
- Arithmetic Logic Unit (ALU)
- Branch Condition Logic
- Hazard Detection Unit
- Data Forwarding Logic
- CSR Register File
- Interrupt Controller
- Memory Access Unit
- AXI Master Interface

---

# Supported RV32I Instruction Set

## Arithmetic Instructions

- ADD
- SUB

## Logical Instructions

- AND
- OR
- XOR

## Shift Instructions

- SLL
- SRL
- SRA

## Comparison Instructions

- SLT
- SLTU

---

## Immediate Instructions

- ADDI
- ANDI
- ORI
- XORI
- SLTI
- SLTIU
- SLLI
- SRLI
- SRAI

---

## Load Instructions

- LB
- LH
- LW
- LBU
- LHU

---

## Store Instructions

- SB
- SH
- SW

---

## Branch Instructions

- BEQ
- BNE
- BLT
- BGE
- BLTU
- BGEU

---

## Jump Instructions

- JAL
- JALR

---

## Upper Immediate Instructions

- LUI
- AUIPC

---

## System Instructions

- ECALL
- EBREAK
- MRET

---

## CSR Instructions (Zicsr)

- CSRRW
- CSRRS
- CSRRC
- CSRRWI
- CSRRSI
- CSRRCI

---

# CSR Support

The processor implements Machine-mode Control and Status Registers (CSRs), including:

- mstatus
- mie
- mip
- mtvec
- mepc
- mcause

Supported features:

- CSR Read
- CSR Write
- Atomic Read-Modify-Write
- Trap Handling
- Interrupt Enable/Disable
- Machine Exception Return (MRET)

---

# Exception and Interrupt Support

## Exceptions

- Illegal Instruction
- ECALL
- EBREAK

## Interrupts

- Machine Timer Interrupt
- Machine External Interrupt (platform dependent)
- Machine Software Interrupt (platform dependent)

---

# Hazard Management

The processor includes hardware support for pipeline hazard management.

Implemented features include:

- Read-after-Write (RAW) Hazard Detection
- Data Forwarding
- Pipeline Stall Generation
- Branch Pipeline Flush

---

# Memory System

Supported memory operations:

- Byte Access
- Half-word Access
- Word Access

Features:

- Sign Extension
- Zero Extension
- Address Alignment Checking
- Instruction Memory Interface
- Data Memory Interface

---

# AXI4-Lite Interface

The processor communicates with peripherals through an AXI4-Lite Master Interface.

Supported AXI channels:

- Write Address (AW)
- Write Data (W)
- Write Response (B)
- Read Address (AR)
- Read Data (R)

---

# SoC Architecture

The processor is integrated into an AXI4-Lite based SoC consisting of:

- Boot ROM
- SRAM Controller
- GPIO Peripheral
- Timer Peripheral
- SPI Peripheral
- AXI4-Lite Interconnect

---

# SPI Boot Support

The SoC supports SPI-based boot loading.

Boot sequence:

```
Reset
   │
   ▼
Boot ROM
   │
   ▼
SPI Boot Loader
   │
   ▼
SRAM
   │
   ▼
Processor Execution

---

# RTL Modules

## Processor Core

| Module | Function |
|---------|----------|
| processor.v | Processor datapath |
| processor_soc.v | SoC processor integration |
| processor_top.v | Processor wrapper |
| processor_top_axi.v | AXI-enabled processor wrapper |

### Datapath

| Module | Function |
|---------|----------|
| pc.v | Program Counter |
| inst_dec.v | Instruction Decoder |
| controller.v | Control Unit |
| imm_gen.v | Immediate Generator |
| reg_file.v | Register File |
| alu.v | Arithmetic Logic Unit |
| adder_unit.v | Address Generator |
| br_cond.v | Branch Condition Logic |
| hazard_unit.v | Hazard Detection & Forwarding |

### CSR and Interrupts

| Module | Function |
|---------|----------|
| csr_reg.v | Machine CSR Register File |
| interrupt_controller.v | Interrupt Controller |

### AXI Infrastructure

| Module | Function |
|---------|----------|
| rv32i_axi_master_wrapper.v | AXI4-Lite Master Interface |
| axi4lite_soc_interconnect.v | AXI Interconnect |

### Memory & Peripherals

| Module | Function |
|---------|----------|
| axi4lite_boot_rom.v | Boot ROM |
| axi4lite_sram_slave.v | SRAM Interface |
| axi4lite_gpio_slave.v | GPIO Peripheral |
| axi4lite_timer_slave.v | Timer Peripheral |
| axi4lite_spi_slave.v | SPI Peripheral |

### SPI

| Module | Function |
|---------|----------|
| spi_master.v | SPI Master Controller |
| spi_boot_loader.v | SPI Boot Loader |

### Utility Modules

| Module | Function |
|---------|----------|
| mux_2x1.v | 2:1 Multiplexer |
| mux_4x1.v | 4:1 Multiplexer |
| csla_bec_block.v | Carry Select Adder Block |
| rv32i_csla_bec_32_.v | 32-bit Carry Select Adder |
| reset_sync.v | Reset Synchronizer |
| SPRAM_1024x36.v | Single-Port SRAM Model |

---

# Verification

The repository includes dedicated RTL testbenches for validating processor and SoC functionality.

### Processor Verification

- CSR semantics verification
- ECALL/EBREAK handling
- AUIPC/JAL/JALR execution
- Hazard and pipeline behavior

### AXI Verification

- AXI protocol validation
- AXI error flag testing
- Store transaction verification

### SoC Verification

- Full SoC functional verification
- SPI boot validation
- Boot ROM execution
- Peripheral integration testing

Simulation logs, preload files, instruction listings, and automated run scripts are included to reproduce verification results.

---

# Repository Organization



├── RTL Source Files
├── AXI Infrastructure
├── SPI Boot Loader
├── Testbenches
├── Simulation Scripts
├── Verification Programs
├── Instruction Memory Images
├── Expected Output Files
└── Documentation


---

# Design Highlights

- Modular RTL implementation
- Synthesizable Verilog HDL
- 3-stage pipelined datapath
- RV32I ISA compliant
- Machine-mode CSR implementation
- Hazard detection and forwarding
- AXI4-Lite based SoC architecture
- Integrated Boot ROM, SRAM, GPIO, Timer, and SPI
- Comprehensive verification environment

---

