RV32I SoC A-to-Z README
Architecture, Address Map, Boot Flow, Instruction Support, Signal Descriptions, Block Descriptions, Synthesis and Verification Notes
Final top: rv32i_chip_top_bootrom_spiflash

Prepared as a complete project README/reference document for the final RV32I SoC RTL.

Document Contents
    • Project overview and final file set
    • Top-level architecture and hierarchy
    • Memory map and address decoding
    • Boot ROM, SPI flash boot loader, boot_done and CPU release flow
    • RV32I instruction support and datapath execution flow
    • AXI4-Lite interface flow and channel explanation
    • Module-by-module description from chip top to leaf blocks
    • Signal/port description tables for every final module
    • Synthesis, DFT/scan and verification summary notes
    • Report-ready final statements and viva answers
1. Project Overview
This design is a 32-bit RV32I SoC with a 3-stage pipelined processor core and an AXI4-Lite based memory/peripheral subsystem. The final chip-level design includes Boot ROM, SPI flash hardware boot loading, Program SRAM, Data SRAM, Timer, GPIO/debug, SPI peripheral, interrupt control, reset synchronization, and foundry SRAM macro integration.
Item
Final Design Value
Architecture
RV32I 32-bit base integer processor SoC
Pipeline
3 stages: IF, DE, MW
Final chip top
rv32i_chip_top_bootrom_spiflash
SoC integration top
rv32i_soc_top_bootrom_spiflash
System bus
32-bit AXI4-Lite
Instruction/data memory style
Separate Program SRAM and Data SRAM, memory-mapped through AXI
Boot approach
Boot ROM plus hardware SPI flash boot loader
SRAM implementation
Foundry SRAM macro SPRAM_1024x36, used through synthesis stub/black box
Main external interfaces
Clock, reset, SPI flash pins, GPIO, debug/status outputs, JTAG interrupt input

2. Module Hierarchy
rv32i_chip_top_bootrom_spiflash        (Chip Top / Tapeout Top)
│
└── rv32i_soc_top_bootrom_spiflash     (Complete SoC Top)
    │
    ├── reset_sync
    │
    ├── spi_flash_boot_loader_axi
    │   └── spi_byte_master_cont
    │
    ├── processor_soc                  (RV32I CPU)
    │   │
    │   ├── pc
    │   ├── inst_dec
    │   ├── controller
    │   ├── reg_file
    │   ├── imm_gen
    │   ├── alu
    │   │   └── adder_unit
    │   │       └── rv32i_csla_bec_32_
    │   │           └── csla_bec_block
    │   ├── br_cond
    │   ├── hazard_unit
    │   ├── csr_reg
    │   └── interrupt_controller
    │
    ├── rv32i_axi_master_wrapper
    │
    ├── axi4lite_soc_interconnect
    │
    ├── axi4lite_boot_rom
    │
    ├── axi4lite_sram_slave
    │   └── 4 × SPRAM_1024x36
    │
    ├── axi4lite_gpio_slave
    │
    ├── axi4lite_timer_slave
    │
    └── axi4lite_spi_slave
        └── spi_master


3. Final Synthesis File Set
The following files form the final synthesis file set. Testbenches, simulation-only flash models, preload files, backup files and logs should not be included in the final synthesis file list.
No.
File
1
rv32i_chip_top_bootrom_spiflash.v
2
rv32i_soc_top_bootrom_spiflash.v
3
spi_flash_boot_loader_axi.v
4
spi_byte_master_cont.v
5
reset_sync.v
6
processor_soc.v
7
rv32i_axi_master_wrapper.v
8
axi4lite_soc_interconnect.v
9
axi4lite_boot_rom.v
10
axi4lite_sram_slave.v
11
axi4lite_timer_slave.v
12
axi4lite_gpio_slave.v
13
axi4lite_spi_slave.v
14
spi_master.v
15
synth_stubs/SPRAM_1024x36_stub.v
16
adder_unit.v
17
alu.v
18
br_cond.v
19
controller.v
20
csr_reg.v
21
hazard_unit.v
22
imm_gen.v
23
inst_dec.v
24
interrupt_controller.v
25
mux_2x1.v
26
mux_4x1.v
27
pc.v
28
reg_file.v
29
rv32i_csla_bec_32_.v
30
csla_bec_block.v

Use
Files / Notes
Final top module
rv32i_chip_top_bootrom_spiflash
SRAM for synthesis
Use synth_stubs/SPRAM_1024x36_stub.v as a black-box/macro declaration.
Do not include
tb_*.v, spi_flash_model.v, *.vh preload files, *.log, *.bak, old tops such as rv32i_chip_top.v or rv32i_soc_top.v
Synthesis command concept
read_hdl -language v2001 -f filelist_rv32i_final_synth.f; elaborate rv32i_chip_top_bootrom_spiflash

4. High-Level Architecture and Hierarchy
At the highest level, external pins enter the chip top. The chip top instantiates reset synchronization and the final SoC. Inside the SoC, the processor communicates through an AXI master wrapper to the AXI interconnect. The interconnect routes accesses to Boot ROM, Program SRAM, Data SRAM and peripherals.
rv32i_chip_top_bootrom_spiflash
  |-- reset_sync
  `-- rv32i_soc_top_bootrom_spiflash
       |-- processor_soc
       |-- rv32i_axi_master_wrapper
       |-- axi4lite_soc_interconnect
       |-- axi4lite_boot_rom
       |-- axi4lite_sram_slave  (Program SRAM)
       |-- axi4lite_sram_slave  (Data SRAM)
       |-- axi4lite_timer_slave
       |-- axi4lite_gpio_slave
       |-- axi4lite_spi_slave
       |-- spi_master
       |-- spi_flash_boot_loader_axi
       `-- spi_byte_master_cont
Level
Block
Responsibility
Chip top
rv32i_chip_top_bootrom_spiflash
External pad-level interface and final top-level wrapper.
Reset
reset_sync
Converts asynchronous active-low reset into clean synchronous internal reset.
SoC top
rv32i_soc_top_bootrom_spiflash
Integrates CPU, memory subsystem, boot loader and peripherals.
CPU
processor_soc
Executes RV32I instructions and generates instruction/data memory transactions.
Bus bridge
rv32i_axi_master_wrapper
Converts CPU memory requests into AXI4-Lite protocol.
Bus fabric
axi4lite_soc_interconnect
Decodes address and routes AXI transactions to the selected slave.
Slaves
Boot ROM, SRAM, Timer, GPIO, SPI
Memory-mapped target blocks selected by the interconnect.

5. Address Map
The AXI interconnect decodes the 32-bit memory address and selects the correct slave. Boot ROM starts at address 0x0000_0000. Program SRAM starts at 0x0001_0000. Data SRAM starts at 0x0002_0000. Peripherals are mapped from 0x1000_0000 upward.
Region
Address Range
Size
Implementation
Purpose
Boot ROM
0x0000_0000 - 0x0000_0FFF
4 KiB
axi4lite_boot_rom
Reset/startup ROM; contains trampoline code
Program SRAM
0x0001_0000 - 0x0001_3FFF
16 KiB
axi4lite_sram_slave, 4 x SPRAM_1024x36
Loaded by SPI boot loader; CPU executes application from here
Data SRAM
0x0002_0000 - 0x0002_3FFF
16 KiB
axi4lite_sram_slave, 4 x SPRAM_1024x36
Runtime stack/data memory
Timer
0x1000_0000 - 0x1000_0FFF
4 KiB MMIO
axi4lite_timer_slave
Memory-mapped timer and timer interrupt
GPIO / Debug
0x1000_1000 - 0x1000_1FFF
4 KiB MMIO
axi4lite_gpio_slave
GPIO, output-enable and debug signature registers
SPI
0x1000_2000 - 0x1000_2FFF
4 KiB MMIO
axi4lite_spi_slave + spi_master
CPU-controlled SPI peripheral after boot

Total SRAM is 32 KiB: 16 KiB Program SRAM plus 16 KiB Data SRAM. Each 16 KiB SRAM region is implemented using four SPRAM_1024x36 macros. The lower 32 data bits are used for the processor data path; the remaining bits are reserved/unused depending on the macro wrapper.
6. Boot Concept and Flow
Boot is the start-up process that makes the processor execute a valid program after power-on/reset. SRAM is volatile, so Program SRAM is empty after power-on. The design therefore uses a small Boot ROM and a hardware SPI flash boot loader to copy the application program into Program SRAM before normal execution.
Boot Element
Type
Purpose
Boot ROM
Internal fixed startup memory
Provides valid first instructions at reset vector 0x0000_0000 and redirects CPU to Program SRAM.
SPI Flash
External non-volatile storage
Stores application image even when chip power is off.
SPI Flash Boot Loader
Internal hardware FSM
Reads SPI flash image and writes payload to Program SRAM through AXI4-Lite.
Program SRAM
Internal volatile memory
Holds executable program after boot. CPU runs the application from this address range.
boot_done
Status signal
Indicates hardware boot load completed; used to release CPU from reset/hold.

6.1 Final SPI Flash Boot Sequence
Step
Action
1
External/system reset is asserted. Internal reset is generated through reset_sync.
2
If boot_from_spi_flash is enabled, CPU is held in reset while the hardware boot loader runs.
3
spi_flash_boot_loader_axi owns the external SPI flash pins through spi_byte_master_cont.
4
Loader sends SPI flash READ command 0x03 from flash address 0x000000.
5
Loader reads the boot image header: magic, word count, load address and entry address.
6
Loader copies payload words into Program SRAM at 0x0001_0000 using AXI4-Lite writes.
7
When all words are copied, loader_done/boot_done becomes 1 and loader_busy becomes 0.
8
CPU reset is released. PC reset value is 0x0000_0000, which maps to Boot ROM.
9
Boot ROM executes startup/trampoline code and jumps to Program SRAM at 0x0001_0000.
10
CPU fetches application instructions from Program SRAM and normal execution begins.

6.2 Boot Image Format
Word
Meaning
Required / Expected Value
0
Boot magic
0x32335652 (ASCII RV32)
1
Payload word count
1 to 4096 words
2
Load address
0x00010000
3
Entry address
0x00010000
4+
Program payload
RV32I instruction words, little-endian bytes

6.3 Boot ROM Trampoline Concept
The CPU does not jump to Boot ROM by an instruction at reset. Instead, reset forces PC to 0x0000_0000. Since Boot ROM is mapped at 0x0000_0000, the first instruction fetch automatically comes from Boot ROM. Then Boot ROM jumps to Program SRAM using JALR.
Reset release:
  PC = 0x0000_0000
  0x0000_0000 maps to Boot ROM

Boot ROM concept:
  set stack pointer to top of Data SRAM, for example 0x0002_4000
  load t0 with Program SRAM base, 0x0001_0000
  jalr x0, 0(t0)  ; PC becomes 0x0001_0000
7. RV32I Instruction Support
The processor implements the supported RV32I base integer instruction groups listed below. The implementation is an in-order 3-stage pipeline. It does not implement RV32M, RV32A, RV32C, floating-point, vector, MMU, cache, or out-of-order execution.
Group
Supported Instructions
Main RTL Blocks
Integer arithmetic/logical R-type
ADD, SUB, SLL, SLT, SLTU, XOR, SRL, SRA, OR, AND
controller -> alu -> adder_unit/logic
Integer arithmetic/logical I-type
ADDI, SLTI, SLTIU, XORI, ORI, ANDI, SLLI, SRLI, SRAI
imm_gen + controller + alu
Load instructions
LB, LH, LW, LBU, LHU
processor_soc dmem -> AXI -> Data SRAM; sign/zero extension
Store instructions
SB, SH, SW
processor_soc dmem -> AXI -> Data SRAM; WSTRB byte lanes
Branch instructions
BEQ, BNE, BLT, BGE, BLTU, BGEU
br_cond + controller branch flush
Jump instructions
JAL, JALR
PC redirect; JALR target bit 0 cleared
Upper immediate
LUI, AUIPC
imm_gen + ALU/writeback path
CSR/System
CSRRW, CSRRS, CSRRC, ECALL, EBREAK, MRET
csr_reg + controller/trap handling
FENCE behavior
FENCE treated as safe NOP in this simple in-order/no-cache SoC
controller safe decode

8. Processor Datapath Flow
Instruction flow:
PC -> instruction fetch request -> AXI master -> AXI interconnect -> Boot ROM/Program SRAM
   -> instruction word -> inst_dec -> controller + imm_gen
   -> reg_file read -> ALU / branch / CSR
   -> optional data memory AXI access
   -> writeback to reg_file
   -> next PC selection
Pipeline Stage
Main Work
Important Signals
IF
Program counter and instruction fetch.
pc_out, imem_req, imem_addr, imem_rdata, inst_IF
DE
Decode, register read, immediate generation, ALU/branch decision.
opcode, funct3, funct7, rs1, rs2, rd, imm_val, aluop, br_taken
MW
Memory access, CSR operation and register writeback.
dmem_req, dmem_wr, dmem_addr, dmem_rdata, wb_sel, rf_we, rf_wdata

9. AXI4-Lite System Flow
The processor core uses a simple instruction/data memory interface. The wrapper converts this into AXI4-Lite. The interconnect decodes address ranges and routes the transaction to one of six slaves: Boot ROM, Program SRAM, Data SRAM, Timer, GPIO or SPI.
AXI Channel
Signals
Meaning
Write address
AWADDR, AWVALID, AWREADY
Master sends write address; slave accepts it.
Write data
WDATA, WSTRB, WVALID, WREADY
Master sends write data and byte lane strobes.
Write response
BRESP, BVALID, BREADY
Slave returns OKAY or error response.
Read address
ARADDR, ARVALID, ARREADY
Master sends read address; slave accepts it.
Read data/response
RDATA, RRESP, RVALID, RREADY
Slave returns read data and OKAY/error response.

Address Type
Behavior
Mapped address
Interconnect selects the matching AXI slave and forwards the channel handshakes.
Unmapped address
Interconnect returns AXI SLVERR to prevent silent aliasing.
Instruction fetch
CPU instruction address is read through AR/R channel.
Load
CPU data read is converted to AR/R channel; returned data is sign/zero extended in the core as required.
Store
CPU data write is converted to AW/W/B channels; WSTRB selects byte lanes.

10. Block Descriptions
10.1 rv32i_chip_top_bootrom_spiflash
File: rv32i_chip_top_bootrom_spiflash.v
Final chip-level top. It exposes external pads, instantiates reset synchronization, connects SPI flash pins, GPIO/debug outputs, and the final SoC top.
10.2 rv32i_soc_top_bootrom_spiflash
File: rv32i_soc_top_bootrom_spiflash.v
Final SoC integration top. It connects the RV32I CPU, AXI master wrapper, AXI interconnect, Boot ROM, Program SRAM, Data SRAM, Timer, GPIO, SPI peripheral, SPI flash hardware boot loader, and boot/reset control.
10.3 spi_flash_boot_loader_axi
File: spi_flash_boot_loader_axi.v
Hardware SPI flash preload controller. During boot, it owns the SPI flash interface, reads a flash boot image, verifies the header, and writes program words into Program SRAM using AXI4-Lite writes.
    • Reads SPI flash header and payload.
    • Writes payload to Program SRAM through AXI write channels.
    • Generates loader_done, loader_error, loader_busy and words_loaded status outputs.
10.4 spi_byte_master_cont
File: spi_byte_master_cont.v
Low-level SPI byte transfer engine used by the boot loader. It serializes tx_data to MOSI, samples MISO, produces SCLK using a divider, and reports busy/done.
10.5 reset_sync
File: reset_sync.v
Two-flop reset synchronizer. It asynchronously asserts reset using arst_n/rst_n and synchronously deasserts reset to the internal clock domain.
10.6 processor_soc
File: processor_soc.v
RV32I 32-bit processor core with 3-stage pipeline. It provides instruction/data request interfaces, CSR/trap handling, interrupt support, pipeline forwarding/stall/flush, and debug outputs.
    • Contains the IF/DE/MW pipeline structure.
    • Generates instruction memory and data memory requests.
    • Handles load-use hazard, forwarding, branch flush and trap redirection.
    • Exports debug signals for PC, instruction, register writeback and memory access.
10.7 rv32i_axi_master_wrapper
File: rv32i_axi_master_wrapper.v
Bridge between the simple processor instruction/data memory interface and AXI4-Lite master protocol. It generates AW/W/B/AR/R channel transactions and returns ready/data/error to the CPU.
10.8 axi4lite_soc_interconnect
File: axi4lite_soc_interconnect.v
Single-master AXI4-Lite address decoder and router. It selects Boot ROM, Program SRAM, Data SRAM, Timer, GPIO, or SPI based on the address map and returns slave responses.
10.9 axi4lite_boot_rom
File: axi4lite_boot_rom.v
Read-only AXI4-Lite Boot ROM. It contains a small startup trampoline that sets basic startup values and jumps to Program SRAM at 0x0001_0000.
10.10 axi4lite_sram_slave
File: axi4lite_sram_slave.v
AXI4-Lite SRAM wrapper. It connects AXI read/write transactions to banked foundry SRAM macros and implements byte-lane WSTRB merge logic.
    • Implements AXI4-Lite read/write FSM behavior.
    • Uses WSTRB to merge byte writes into 32-bit words.
    • Maps address bits to SRAM bank and word index for foundry macro access.
10.11 axi4lite_timer_slave
File: axi4lite_timer_slave.v
Memory-mapped timer peripheral. It provides CTRL, COUNT, COMPARE, and STATUS registers and can generate timer_irq.
10.12 axi4lite_gpio_slave
File: axi4lite_gpio_slave.v
Memory-mapped GPIO/debug peripheral. It allows CPU writes to GPIO output/enable registers and exposes debug_out for verification/status signatures.
10.13 axi4lite_spi_slave
File: axi4lite_spi_slave.v
CPU-controlled memory-mapped SPI peripheral. After boot, software accesses it through AXI registers to drive spi_master and receive SPI interrupts.
10.14 spi_master
File: spi_master.v
Low-level SPI master peripheral used by the AXI SPI slave. It generates SCLK, MOSI, CSN and samples MISO for byte transfers.
10.15 SPRAM_1024x36
File: synth_stubs/SPRAM_1024x36_stub.v
Module description not available. This block is part of the final RV32I SoC RTL hierarchy.
10.16 adder_unit
File: adder_unit.v
ADD/SUB front-end for the ALU. For subtraction it inverts B and adds carry-in 1; for addition it passes B and carry-in 0 to the CSLA-BEC adder.
10.17 alu
File: alu.v
Arithmetic Logic Unit. Executes ADD, SUB, shifts, comparisons, XOR, OR, AND, and LUI pass-through. ADD/SUB use the CSLA-BEC adder_unit.
10.18 br_cond
File: br_cond.v
Branch condition comparator. Evaluates BEQ, BNE, BLT, BGE, BLTU, and BGEU conditions using signed and unsigned comparisons.
10.19 controller
File: controller.v
Instruction control decoder. It decodes opcode/funct fields and generates ALU control, operand selects, register write enable, memory controls, branch/jump control, CSR control, trap flags, and illegal instruction flag.
    • Decodes opcode, funct3, funct7 and funct12.
    • Generates control for ALU, register file, memory, writeback, branch/jump, CSR and trap behavior.
10.20 csr_reg
File: csr_reg.v
Machine-mode CSR and trap register block. It stores mstatus/mie/mtvec/mepc/mcause/mip-style state, handles traps/interrupts, and generates EPC redirect for MRET/trap entry.
10.21 hazard_unit
File: hazard_unit.v
Pipeline hazard unit. It generates forwarding selects, load-use stalls, branch flushes, and pipeline bubbles to preserve correct execution.
10.22 imm_gen
File: imm_gen.v
Immediate generator. It extracts and sign-extends RV32I I/S/B/U/J type immediates from the instruction word.
10.23 inst_dec
File: inst_dec.v
Instruction field decoder. It slices the 32-bit instruction into opcode, rd, rs1, rs2, funct3, and funct7 fields.
10.24 interrupt_controller
File: interrupt_controller.v
Simple interrupt priority encoder. It accepts timer, SPI, and JTAG/debug interrupts and outputs irq_valid and irq_cause to the CSR/trap logic.
10.25 mux_2x1
File: mux_2x1.v
32-bit two-input multiplexer used for datapath selection.
10.26 mux_4x1
File: mux_4x1.v
32-bit four-input multiplexer used for writeback/operand selection.
10.27 pc
File: pc.v
Program counter register. It stores the current fetch address and updates to pc_in when enabled.
10.28 reg_file
File: reg_file.v
RV32I integer register file. It implements x0-x31, two read ports, one write port, and x0 hardwired to zero.
10.29 rv32i_csla_bec_32_
File: rv32i_csla_bec_32_.v
32-bit Carry Select Adder with Binary Excess-1 Converter structure. It is used for fast addition/subtraction in the ALU.
10.30 csla_bec_block
File: csla_bec_block.v
4-bit building block used by the 32-bit CSLA-BEC adder.
11. Complete Module Port and Signal Descriptions
This section lists the ports of every final module and gives the direction, width and practical meaning of each signal. Some repeated AXI signal descriptions are grouped by AXI channel semantics.
rv32i_chip_top_bootrom_spiflash
Signal
Dir
Width
Description
clk_pad
input
1
Clock input or generated clock signal for synchronous logic.
rst_n_pad
input
1
Active-low asynchronous/system reset input.
boot_from_spi_flash_pad
input
1
Boot mode enable. Selects SPI flash hardware preload path when asserted.
spi_flash_sclk_pad
output
1
SPI serial clock signal.
spi_flash_mosi_pad
output
1
SPI master-out slave-in serial data signal.
spi_flash_miso_pad
input
1
SPI master-in slave-out serial data signal.
spi_flash_cs_n_pad
output
1
SPI chip-select signal, usually active low.
jtag_irq_pad
input
1
Interrupt request, interrupt status, or interrupt cause-related signal.
gpio_in_pad
input
[ 7:0]
GPIO input/output/output-enable or GPIO/debug bus signal.
gpio_out_pad
output
[ 7:0]
GPIO input/output/output-enable or GPIO/debug bus signal.
gpio_oe_pad
output
[ 7:0]
GPIO input/output/output-enable or GPIO/debug bus signal.
debug_out_pad
output
[31:0]
Debug or status visibility signal exported for verification/observability.
pc_debug_pad
output
[31:0]
Program counter value, next PC input, or PC debug signal.
inst_debug_pad
output
[31:0]
Instruction word or instruction debug/decode-related signal.
trap_taken_pad
output
1
CSR, trap, exception, MRET, ECALL, or EBREAK control/status signal.
timer_irq_dbg_pad
output
1
Interrupt request, interrupt status, or interrupt cause-related signal.
loader_done_pad
output
1
Indicates SPI boot loader completed program loading successfully.
loader_error_pad
output
1
Indicates SPI boot loader detected bad header, response error, or invalid boot image.
loader_busy_pad
output
1
Indicates the corresponding transfer/loader FSM is active.
loader_words_loaded_pad
output
[12:0]
Number of payload words copied into Program SRAM by the boot loader.
cpu_rst_dbg_pad
output
1
Active-high internal reset or reset status signal.

rv32i_soc_top_bootrom_spiflash
Signal
Dir
Width
Description
clk
input
1
Clock input or generated clock signal for synchronous logic.
rst_n
input
1
Active-low asynchronous/system reset input.
boot_from_spi_flash
input
1
Boot mode enable. Selects SPI flash hardware preload path when asserted.
spi_flash_sclk
output
1
SPI serial clock signal.
spi_flash_mosi
output
1
SPI master-out slave-in serial data signal.
spi_flash_miso
input
1
SPI master-in slave-out serial data signal.
spi_flash_cs_n
output
1
SPI chip-select signal, usually active low.
jtag_irq
input
1
Interrupt request, interrupt status, or interrupt cause-related signal.
gpio_in
input
[ 7:0]
GPIO input/output/output-enable or GPIO/debug bus signal.
gpio_out
output
[ 7:0]
GPIO input/output/output-enable or GPIO/debug bus signal.
gpio_oe
output
[ 7:0]
GPIO input/output/output-enable or GPIO/debug bus signal.
debug_out
output
[31:0]
Debug or status visibility signal exported for verification/observability.
pc_debug
output
[31:0]
Program counter value, next PC input, or PC debug signal.
inst_debug
output
[31:0]
Instruction word or instruction debug/decode-related signal.
rf_we
output
1
Register file read/write address, data, enable, or debug signal.
rf_waddr
output
[ 4:0]
Register file read/write address, data, enable, or debug signal.
rf_wdata
output
[31:0]
AXI4-Lite write data channel signal.
mem_we
output
1
Data memory load/store request, address, data, access mode, or debug signal.
mem_re
output
1
Data memory load/store request, address, data, access mode, or debug signal.
mem_addr
output
[31:0]
Data memory load/store request, address, data, access mode, or debug signal.
mem_wdata
output
[31:0]
AXI4-Lite write data channel signal.
mem_rdata
output
[31:0]
AXI4-Lite read data/response channel signal.
br_taken_dbg
output
1
Branch type, branch comparison, or branch taken/debug signal.
trap_taken
output
1
CSR, trap, exception, MRET, ECALL, or EBREAK control/status signal.
epc_debug
output
[31:0]
Program counter value, next PC input, or PC debug signal.
timer_irq_dbg
output
1
Interrupt request, interrupt status, or interrupt cause-related signal.
loader_done
output
1
Indicates SPI boot loader completed program loading successfully.
loader_error
output
1
Indicates SPI boot loader detected bad header, response error, or invalid boot image.
loader_busy
output
1
Indicates the corresponding transfer/loader FSM is active.
loader_words_loaded
output
[12:0]
Number of payload words copied into Program SRAM by the boot loader.
cpu_rst_dbg
output
1
Module-specific signal; see module purpose and connection context.

spi_flash_boot_loader_axi
Signal
Dir
Width
Description
clk
input
1
Clock input or generated clock signal for synchronous logic.
rst
input
1
Active-high internal reset or reset status signal.
boot_en
input
1
Boot mode enable. Selects SPI flash hardware preload path when asserted.
spi_sclk
output
1
SPI serial clock signal.
spi_mosi
output
1
SPI master-out slave-in serial data signal.
spi_miso
input
1
SPI master-in slave-out serial data signal.
spi_cs_n
output
1
SPI chip-select signal, usually active low.
loader_done
output
1
Indicates SPI boot loader completed program loading successfully.
loader_error
output
1
Indicates SPI boot loader detected bad header, response error, or invalid boot image.
loader_busy
output
1
Indicates the corresponding transfer/loader FSM is active.
words_loaded
output
[12:0]
Number of payload words copied into Program SRAM by the boot loader.
M_AXI_AWADDR
output
[31:0]
AXI4-Lite write address channel signal.
M_AXI_AWVALID
output
1
AXI4-Lite write address channel signal.
M_AXI_AWREADY
input
1
AXI4-Lite write address channel signal.
M_AXI_WDATA
output
[31:0]
AXI4-Lite write data channel signal.
M_AXI_WSTRB
output
[ 3:0]
AXI4-Lite write data channel signal.
M_AXI_WVALID
output
1
AXI4-Lite write data channel signal.
M_AXI_WREADY
input
1
AXI4-Lite write data channel signal.
M_AXI_BRESP
input
[ 1:0]
AXI4-Lite write response channel signal.
M_AXI_BVALID
input
1
AXI4-Lite write response channel signal.
M_AXI_BREADY
output
1
AXI4-Lite write response channel signal.

spi_byte_master_cont
Signal
Dir
Width
Description
clk
input
1
Clock input or generated clock signal for synchronous logic.
rst
input
1
Active-high internal reset or reset status signal.
start
input
1
Module-specific signal; see module purpose and connection context.
tx_data
input
[ 7:0]
Data bus signal.
clk_div
input
[15:0]
Module-specific signal; see module purpose and connection context.
rx_data
output
[ 7:0]
Data bus signal.
busy
output
1
Indicates the corresponding transfer/loader FSM is active.
done
output
1
Module-specific signal; see module purpose and connection context.
spi_sclk
output
1
SPI serial clock signal.
spi_mosi
output
1
SPI master-out slave-in serial data signal.
spi_miso
input
1
SPI master-in slave-out serial data signal.

reset_sync
Signal
Dir
Width
Description
clk
input
1
Clock input or generated clock signal for synchronous logic.
arst_n
input
1
Active-low asynchronous/system reset input.
srst
output
1
Active-high internal reset or reset status signal.

processor_soc
Signal
Dir
Width
Description
clk
input
1
Clock input or generated clock signal for synchronous logic.
rst
input
1
Active-high internal reset or reset status signal.
timer_irq
input
1
Interrupt request, interrupt status, or interrupt cause-related signal.
spi_irq
input
1
Interrupt request, interrupt status, or interrupt cause-related signal.
jtag_irq
input
1
Interrupt request, interrupt status, or interrupt cause-related signal.
imem_req
output
1
Instruction memory request/address/data/ready/error signal between CPU and AXI wrapper.
imem_addr
output
[31:0]
Instruction memory request/address/data/ready/error signal between CPU and AXI wrapper.
imem_ready
input
1
Instruction memory request/address/data/ready/error signal between CPU and AXI wrapper.
imem_rdata
input
[31:0]
AXI4-Lite read data/response channel signal.
imem_error
input
1
Instruction memory request/address/data/ready/error signal between CPU and AXI wrapper.
dmem_req
output
1
Data memory load/store request, address, data, access mode, or debug signal.
dmem_wr
output
1
Data memory load/store request, address, data, access mode, or debug signal.
dmem_addr
output
[31:0]
Data memory load/store request, address, data, access mode, or debug signal.
dmem_acc_mode
output
[ 2:0]
Data memory load/store request, address, data, access mode, or debug signal.
dmem_wdata
output
[31:0]
AXI4-Lite write data channel signal.
dmem_ready
input
1
Data memory load/store request, address, data, access mode, or debug signal.
dmem_rdata
input
[31:0]
AXI4-Lite read data/response channel signal.
dmem_error
input
1
Data memory load/store request, address, data, access mode, or debug signal.
pc_debug
output
[31:0]
Program counter value, next PC input, or PC debug signal.
inst_debug
output
[31:0]
Instruction word or instruction debug/decode-related signal.
rf_we
output
1
Register file read/write address, data, enable, or debug signal.
rf_waddr
output
[ 4:0]
Register file read/write address, data, enable, or debug signal.
rf_wdata
output
[31:0]
AXI4-Lite write data channel signal.
mem_we
output
1
Data memory load/store request, address, data, access mode, or debug signal.
mem_re
output
1
Data memory load/store request, address, data, access mode, or debug signal.
mem_addr
output
[31:0]
Data memory load/store request, address, data, access mode, or debug signal.
mem_wdata
output
[31:0]
AXI4-Lite write data channel signal.
mem_rdata
output
[31:0]
AXI4-Lite read data/response channel signal.
br_taken_dbg
output
1
Branch type, branch comparison, or branch taken/debug signal.
trap_taken
output
1
CSR, trap, exception, MRET, ECALL, or EBREAK control/status signal.
epc_debug
output
[31:0]
Program counter value, next PC input, or PC debug signal.
timer_irq_dbg
output
1
Interrupt request, interrupt status, or interrupt cause-related signal.
illegal_inst_dbg
output
1
Instruction word or instruction debug/decode-related signal.

rv32i_axi_master_wrapper
Signal
Dir
Width
Description
clk
input
1
Clock input or generated clock signal for synchronous logic.
rst
input
1
Active-high internal reset or reset status signal.
imem_req
input
1
Instruction memory request/address/data/ready/error signal between CPU and AXI wrapper.
imem_addr
input
[31:0]
Instruction memory request/address/data/ready/error signal between CPU and AXI wrapper.
imem_ready
output
1
Instruction memory request/address/data/ready/error signal between CPU and AXI wrapper.
imem_rdata
output
[31:0]
AXI4-Lite read data/response channel signal.
imem_error
output
1
Instruction memory request/address/data/ready/error signal between CPU and AXI wrapper.
dmem_req
input
1
Data memory load/store request, address, data, access mode, or debug signal.
dmem_wr
input
1
Data memory load/store request, address, data, access mode, or debug signal.
dmem_addr
input
[31:0]
Data memory load/store request, address, data, access mode, or debug signal.
dmem_acc_mode
input
[ 2:0]
Data memory load/store request, address, data, access mode, or debug signal.
dmem_wdata
input
[31:0]
AXI4-Lite write data channel signal.
dmem_ready
output
1
Data memory load/store request, address, data, access mode, or debug signal.
dmem_rdata
output
[31:0]
AXI4-Lite read data/response channel signal.
dmem_error
output
1
Data memory load/store request, address, data, access mode, or debug signal.
M_AXI_AWADDR
output
[31:0]
AXI4-Lite write address channel signal.
M_AXI_AWVALID
output
1
AXI4-Lite write address channel signal.
M_AXI_AWREADY
input
1
AXI4-Lite write address channel signal.
M_AXI_WDATA
output
[31:0]
AXI4-Lite write data channel signal.
M_AXI_WSTRB
output
[ 3:0]
AXI4-Lite write data channel signal.
M_AXI_WVALID
output
1
AXI4-Lite write data channel signal.
M_AXI_WREADY
input
1
AXI4-Lite write data channel signal.
M_AXI_BRESP
input
[ 1:0]
AXI4-Lite write response channel signal.
M_AXI_BVALID
input
1
AXI4-Lite write response channel signal.
M_AXI_BREADY
output
1
AXI4-Lite write response channel signal.
M_AXI_ARADDR
output
[31:0]
AXI4-Lite read address channel signal.
M_AXI_ARVALID
output
1
AXI4-Lite read address channel signal.
M_AXI_ARREADY
input
1
AXI4-Lite read address channel signal.
M_AXI_RDATA
input
[31:0]
AXI4-Lite read data/response channel signal.
M_AXI_RRESP
input
[ 1:0]
AXI4-Lite read data/response channel signal.
M_AXI_RVALID
input
1
AXI4-Lite read data/response channel signal.
M_AXI_RREADY
output
1
AXI4-Lite read data/response channel signal.

axi4lite_soc_interconnect
Signal
Dir
Width
Description
clk
input
1
Clock input or generated clock signal for synchronous logic.
rst
input
1
Active-high internal reset or reset status signal.
M_AWADDR
input
[31:0]
AXI4-Lite write address channel signal.
M_AWVALID
input
1
AXI4-Lite write address channel signal.
M_AWREADY
output
1
AXI4-Lite write address channel signal.
M_WDATA
input
[31:0]
AXI4-Lite write data channel signal.
M_WSTRB
input
[ 3:0]
AXI4-Lite write data channel signal.
M_WVALID
input
1
AXI4-Lite write data channel signal.
M_WREADY
output
1
AXI4-Lite write data channel signal.
M_BRESP
output
[ 1:0]
AXI4-Lite write response channel signal.
M_BVALID
output
1
AXI4-Lite write response channel signal.
M_BREADY
input
1
AXI4-Lite write response channel signal.
M_ARADDR
input
[31:0]
AXI4-Lite read address channel signal.
M_ARVALID
input
1
AXI4-Lite read address channel signal.
M_ARREADY
output
1
AXI4-Lite read address channel signal.
M_RDATA
output
[31:0]
AXI4-Lite read data/response channel signal.
M_RRESP
output
[ 1:0]
AXI4-Lite read data/response channel signal.
M_RVALID
output
1
AXI4-Lite read data/response channel signal.
M_RREADY
input
1
AXI4-Lite read data/response channel signal.
S0_AWADDR
output
[31:0]
AXI4-Lite write address channel signal.
S0_AWVALID
output
1
AXI4-Lite write address channel signal.
S0_AWREADY
input
1
AXI4-Lite write address channel signal.
S0_WDATA
output
[31:0]
AXI4-Lite write data channel signal.
S0_WSTRB
output
[ 3:0]
AXI4-Lite write data channel signal.
S0_WVALID
output
1
AXI4-Lite write data channel signal.
S0_WREADY
input
1
AXI4-Lite write data channel signal.
S0_BRESP
input
[ 1:0]
AXI4-Lite write response channel signal.
S0_BVALID
input
1
AXI4-Lite write response channel signal.
S0_BREADY
output
1
AXI4-Lite write response channel signal.
S0_ARADDR
output
[31:0]
AXI4-Lite read address channel signal.
S0_ARVALID
output
1
AXI4-Lite read address channel signal.
S0_ARREADY
input
1
AXI4-Lite read address channel signal.
S0_RDATA
input
[31:0]
AXI4-Lite read data/response channel signal.
S0_RRESP
input
[ 1:0]
AXI4-Lite read data/response channel signal.
S0_RVALID
input
1
AXI4-Lite read data/response channel signal.
S0_RREADY
output
1
AXI4-Lite read data/response channel signal.
S1_AWADDR
output
[31:0]
AXI4-Lite write address channel signal.
S1_AWVALID
output
1
AXI4-Lite write address channel signal.
S1_AWREADY
input
1
AXI4-Lite write address channel signal.
S1_WDATA
output
[31:0]
AXI4-Lite write data channel signal.
S1_WSTRB
output
[ 3:0]
AXI4-Lite write data channel signal.
S1_WVALID
output
1
AXI4-Lite write data channel signal.
S1_WREADY
input
1
AXI4-Lite write data channel signal.
S1_BRESP
input
[ 1:0]
AXI4-Lite write response channel signal.
S1_BVALID
input
1
AXI4-Lite write response channel signal.
S1_BREADY
output
1
AXI4-Lite write response channel signal.
S1_ARADDR
output
[31:0]
AXI4-Lite read address channel signal.
S1_ARVALID
output
1
AXI4-Lite read address channel signal.
S1_ARREADY
input
1
AXI4-Lite read address channel signal.
S1_RDATA
input
[31:0]
AXI4-Lite read data/response channel signal.
S1_RRESP
input
[ 1:0]
AXI4-Lite read data/response channel signal.
S1_RVALID
input
1
AXI4-Lite read data/response channel signal.
S1_RREADY
output
1
AXI4-Lite read data/response channel signal.
S2_AWADDR
output
[31:0]
AXI4-Lite write address channel signal.
S2_AWVALID
output
1
AXI4-Lite write address channel signal.
S2_AWREADY
input
1
AXI4-Lite write address channel signal.
S2_WDATA
output
[31:0]
AXI4-Lite write data channel signal.
S2_WSTRB
output
[ 3:0]
AXI4-Lite write data channel signal.
S2_WVALID
output
1
AXI4-Lite write data channel signal.
S2_WREADY
input
1
AXI4-Lite write data channel signal.
S2_BRESP
input
[ 1:0]
AXI4-Lite write response channel signal.
S2_BVALID
input
1
AXI4-Lite write response channel signal.
S2_BREADY
output
1
AXI4-Lite write response channel signal.
S2_ARADDR
output
[31:0]
AXI4-Lite read address channel signal.
S2_ARVALID
output
1
AXI4-Lite read address channel signal.
S2_ARREADY
input
1
AXI4-Lite read address channel signal.
S2_RDATA
input
[31:0]
AXI4-Lite read data/response channel signal.
S2_RRESP
input
[ 1:0]
AXI4-Lite read data/response channel signal.
S2_RVALID
input
1
AXI4-Lite read data/response channel signal.
S2_RREADY
output
1
AXI4-Lite read data/response channel signal.
S3_AWADDR
output
[31:0]
AXI4-Lite write address channel signal.
S3_AWVALID
output
1
AXI4-Lite write address channel signal.
S3_AWREADY
input
1
AXI4-Lite write address channel signal.
S3_WDATA
output
[31:0]
AXI4-Lite write data channel signal.
S3_WSTRB
output
[ 3:0]
AXI4-Lite write data channel signal.
S3_WVALID
output
1
AXI4-Lite write data channel signal.
S3_WREADY
input
1
AXI4-Lite write data channel signal.
S3_BRESP
input
[ 1:0]
AXI4-Lite write response channel signal.
S3_BVALID
input
1
AXI4-Lite write response channel signal.
S3_BREADY
output
1
AXI4-Lite write response channel signal.
S3_ARADDR
output
[31:0]
AXI4-Lite read address channel signal.
S3_ARVALID
output
1
AXI4-Lite read address channel signal.
S3_ARREADY
input
1
AXI4-Lite read address channel signal.
S3_RDATA
input
[31:0]
AXI4-Lite read data/response channel signal.
S3_RRESP
input
[ 1:0]
AXI4-Lite read data/response channel signal.
S3_RVALID
input
1
AXI4-Lite read data/response channel signal.
S3_RREADY
output
1
AXI4-Lite read data/response channel signal.
S4_AWADDR
output
[31:0]
AXI4-Lite write address channel signal.
S4_AWVALID
output
1
AXI4-Lite write address channel signal.
S4_AWREADY
input
1
AXI4-Lite write address channel signal.
S4_WDATA
output
[31:0]
AXI4-Lite write data channel signal.
S4_WSTRB
output
[ 3:0]
AXI4-Lite write data channel signal.
S4_WVALID
output
1
AXI4-Lite write data channel signal.
S4_WREADY
input
1
AXI4-Lite write data channel signal.
S4_BRESP
input
[ 1:0]
AXI4-Lite write response channel signal.
S4_BVALID
input
1
AXI4-Lite write response channel signal.
S4_BREADY
output
1
AXI4-Lite write response channel signal.
S4_ARADDR
output
[31:0]
AXI4-Lite read address channel signal.
S4_ARVALID
output
1
AXI4-Lite read address channel signal.
S4_ARREADY
input
1
AXI4-Lite read address channel signal.
S4_RDATA
input
[31:0]
AXI4-Lite read data/response channel signal.
S4_RRESP
input
[ 1:0]
AXI4-Lite read data/response channel signal.
S4_RVALID
input
1
AXI4-Lite read data/response channel signal.
S4_RREADY
output
1
AXI4-Lite read data/response channel signal.
S5_AWADDR
output
[31:0]
AXI4-Lite write address channel signal.
S5_AWVALID
output
1
AXI4-Lite write address channel signal.
S5_AWREADY
input
1
AXI4-Lite write address channel signal.
S5_WDATA
output
[31:0]
AXI4-Lite write data channel signal.
S5_WSTRB
output
[ 3:0]
AXI4-Lite write data channel signal.
S5_WVALID
output
1
AXI4-Lite write data channel signal.
S5_WREADY
input
1
AXI4-Lite write data channel signal.
S5_BRESP
input
[ 1:0]
AXI4-Lite write response channel signal.
S5_BVALID
input
1
AXI4-Lite write response channel signal.
S5_BREADY
output
1
AXI4-Lite write response channel signal.
S5_ARADDR
output
[31:0]
AXI4-Lite read address channel signal.
S5_ARVALID
output
1
AXI4-Lite read address channel signal.
S5_ARREADY
input
1
AXI4-Lite read address channel signal.
S5_RDATA
input
[31:0]
AXI4-Lite read data/response channel signal.
S5_RRESP
input
[ 1:0]
AXI4-Lite read data/response channel signal.
S5_RVALID
input
1
AXI4-Lite read data/response channel signal.
S5_RREADY
output
1
AXI4-Lite read data/response channel signal.

axi4lite_boot_rom
Signal
Dir
Width
Description
clk
input
1
Clock input or generated clock signal for synchronous logic.
rst
input
1
Active-high internal reset or reset status signal.
S_AXI_AWADDR
input
[31:0]
AXI4-Lite write address channel signal.
S_AXI_AWVALID
input
1
AXI4-Lite write address channel signal.
S_AXI_AWREADY
output
1
AXI4-Lite write address channel signal.
S_AXI_WDATA
input
[31:0]
AXI4-Lite write data channel signal.
S_AXI_WSTRB
input
[ 3:0]
AXI4-Lite write data channel signal.
S_AXI_WVALID
input
1
AXI4-Lite write data channel signal.
S_AXI_WREADY
output
1
AXI4-Lite write data channel signal.
S_AXI_BRESP
output
[ 1:0]
AXI4-Lite write response channel signal.
S_AXI_BVALID
output
1
AXI4-Lite write response channel signal.
S_AXI_BREADY
input
1
AXI4-Lite write response channel signal.
S_AXI_ARADDR
input
[31:0]
AXI4-Lite read address channel signal.
S_AXI_ARVALID
input
1
AXI4-Lite read address channel signal.
S_AXI_ARREADY
output
1
AXI4-Lite read address channel signal.
S_AXI_RDATA
output
[31:0]
AXI4-Lite read data/response channel signal.
S_AXI_RRESP
output
[ 1:0]
AXI4-Lite read data/response channel signal.
S_AXI_RVALID
output
1
AXI4-Lite read data/response channel signal.
S_AXI_RREADY
input
1
AXI4-Lite read data/response channel signal.

axi4lite_sram_slave
Signal
Dir
Width
Description
clk
input
1
Clock input or generated clock signal for synchronous logic.
rst
input
1
Active-high internal reset or reset status signal.
S_AXI_AWADDR
input
[31:0]
AXI4-Lite write address channel signal.
S_AXI_AWVALID
input
1
AXI4-Lite write address channel signal.
S_AXI_AWREADY
output
1
AXI4-Lite write address channel signal.
S_AXI_WDATA
input
[31:0]
AXI4-Lite write data channel signal.
S_AXI_WSTRB
input
[ 3:0]
AXI4-Lite write data channel signal.
S_AXI_WVALID
input
1
AXI4-Lite write data channel signal.
S_AXI_WREADY
output
1
AXI4-Lite write data channel signal.
S_AXI_BRESP
output
[ 1:0]
AXI4-Lite write response channel signal.
S_AXI_BVALID
output
1
AXI4-Lite write response channel signal.
S_AXI_BREADY
input
1
AXI4-Lite write response channel signal.
S_AXI_ARADDR
input
[31:0]
AXI4-Lite read address channel signal.
S_AXI_ARVALID
input
1
AXI4-Lite read address channel signal.
S_AXI_ARREADY
output
1
AXI4-Lite read address channel signal.
S_AXI_RDATA
output
[31:0]
AXI4-Lite read data/response channel signal.
S_AXI_RRESP
output
[ 1:0]
AXI4-Lite read data/response channel signal.
S_AXI_RVALID
output
1
AXI4-Lite read data/response channel signal.
S_AXI_RREADY
input
1
AXI4-Lite read data/response channel signal.

axi4lite_timer_slave
Signal
Dir
Width
Description
clk
input
1
Clock input or generated clock signal for synchronous logic.
rst
input
1
Active-high internal reset or reset status signal.
S_AXI_AWADDR
input
[31:0]
AXI4-Lite write address channel signal.
S_AXI_AWVALID
input
1
AXI4-Lite write address channel signal.
S_AXI_AWREADY
output
1
AXI4-Lite write address channel signal.
S_AXI_WDATA
input
[31:0]
AXI4-Lite write data channel signal.
S_AXI_WSTRB
input
[ 3:0]
AXI4-Lite write data channel signal.
S_AXI_WVALID
input
1
AXI4-Lite write data channel signal.
S_AXI_WREADY
output
1
AXI4-Lite write data channel signal.
S_AXI_BRESP
output
[ 1:0]
AXI4-Lite write response channel signal.
S_AXI_BVALID
output
1
AXI4-Lite write response channel signal.
S_AXI_BREADY
input
1
AXI4-Lite write response channel signal.
S_AXI_ARADDR
input
[31:0]
AXI4-Lite read address channel signal.
S_AXI_ARVALID
input
1
AXI4-Lite read address channel signal.
S_AXI_ARREADY
output
1
AXI4-Lite read address channel signal.
S_AXI_RDATA
output
[31:0]
AXI4-Lite read data/response channel signal.
S_AXI_RRESP
output
[ 1:0]
AXI4-Lite read data/response channel signal.
S_AXI_RVALID
output
1
AXI4-Lite read data/response channel signal.
S_AXI_RREADY
input
1
AXI4-Lite read data/response channel signal.
timer_irq
output
1
Interrupt request, interrupt status, or interrupt cause-related signal.

axi4lite_gpio_slave
Signal
Dir
Width
Description
clk
input
1
Clock input or generated clock signal for synchronous logic.
rst
input
1
Active-high internal reset or reset status signal.
S_AXI_AWADDR
input
[31:0]
AXI4-Lite write address channel signal.
S_AXI_AWVALID
input
1
AXI4-Lite write address channel signal.
S_AXI_AWREADY
output
1
AXI4-Lite write address channel signal.
S_AXI_WDATA
input
[31:0]
AXI4-Lite write data channel signal.
S_AXI_WSTRB
input
[ 3:0]
AXI4-Lite write data channel signal.
S_AXI_WVALID
input
1
AXI4-Lite write data channel signal.
S_AXI_WREADY
output
1
AXI4-Lite write data channel signal.
S_AXI_BRESP
output
[ 1:0]
AXI4-Lite write response channel signal.
S_AXI_BVALID
output
1
AXI4-Lite write response channel signal.
S_AXI_BREADY
input
1
AXI4-Lite write response channel signal.
S_AXI_ARADDR
input
[31:0]
AXI4-Lite read address channel signal.
S_AXI_ARVALID
input
1
AXI4-Lite read address channel signal.
S_AXI_ARREADY
output
1
AXI4-Lite read address channel signal.
S_AXI_RDATA
output
[31:0]
AXI4-Lite read data/response channel signal.
S_AXI_RRESP
output
[ 1:0]
AXI4-Lite read data/response channel signal.
S_AXI_RVALID
output
1
AXI4-Lite read data/response channel signal.
S_AXI_RREADY
input
1
AXI4-Lite read data/response channel signal.
gpio_in
input
[GPIO_WIDTH-1:0]
GPIO input/output/output-enable or GPIO/debug bus signal.
gpio_out
output
[GPIO_WIDTH-1:0]
GPIO input/output/output-enable or GPIO/debug bus signal.
gpio_oe
output
[GPIO_WIDTH-1:0]
GPIO input/output/output-enable or GPIO/debug bus signal.
debug_out
output
[31:0]
Debug or status visibility signal exported for verification/observability.

axi4lite_spi_slave
Signal
Dir
Width
Description
clk
input
1
Clock input or generated clock signal for synchronous logic.
rst
input
1
Active-high internal reset or reset status signal.
S_AXI_AWADDR
input
[31:0]
AXI4-Lite write address channel signal.
S_AXI_AWVALID
input
1
AXI4-Lite write address channel signal.
S_AXI_AWREADY
output
1
AXI4-Lite write address channel signal.
S_AXI_WDATA
input
[31:0]
AXI4-Lite write data channel signal.
S_AXI_WSTRB
input
[ 3:0]
AXI4-Lite write data channel signal.
S_AXI_WVALID
input
1
AXI4-Lite write data channel signal.
S_AXI_WREADY
output
1
AXI4-Lite write data channel signal.
S_AXI_BRESP
output
[ 1:0]
AXI4-Lite write response channel signal.
S_AXI_BVALID
output
1
AXI4-Lite write response channel signal.
S_AXI_BREADY
input
1
AXI4-Lite write response channel signal.
S_AXI_ARADDR
input
[31:0]
AXI4-Lite read address channel signal.
S_AXI_ARVALID
input
1
AXI4-Lite read address channel signal.
S_AXI_ARREADY
output
1
AXI4-Lite read address channel signal.
S_AXI_RDATA
output
[31:0]
AXI4-Lite read data/response channel signal.
S_AXI_RRESP
output
[ 1:0]
AXI4-Lite read data/response channel signal.
S_AXI_RVALID
output
1
AXI4-Lite read data/response channel signal.
S_AXI_RREADY
input
1
AXI4-Lite read data/response channel signal.
spi_sclk
output
1
SPI serial clock signal.
spi_mosi
output
1
SPI master-out slave-in serial data signal.
spi_miso
input
1
SPI master-in slave-out serial data signal.
spi_irq
output
1
Interrupt request, interrupt status, or interrupt cause-related signal.
spi_cs_n
output
1
SPI chip-select signal, usually active low.

spi_master
Signal
Dir
Width
Description
clk
input
1
Clock input or generated clock signal for synchronous logic.
rst
input
1
Active-high internal reset or reset status signal.
start
input
1
Module-specific signal; see module purpose and connection context.
tx_data
input
[7:0]
Data bus signal.
clk_div
input
[15:0]
Module-specific signal; see module purpose and connection context.
rx_data
output
[7:0]
Data bus signal.
busy
output
1
Indicates the corresponding transfer/loader FSM is active.
done
output
1
Module-specific signal; see module purpose and connection context.
spi_sclk
output
1
SPI serial clock signal.
spi_mosi
output
1
SPI master-out slave-in serial data signal.
spi_miso
input
1
SPI master-in slave-out serial data signal.
spi_cs_n
output
1
SPI chip-select signal, usually active low.

SPRAM_1024x36
Signal
Dir
Width
Description
A
input
[9:0]
Adder/ALU operand, carry, result, or subtract control signal.
D
input
[35:0]
Module-specific signal; see module purpose and connection context.
Q
output
[35:0]
Module-specific signal; see module purpose and connection context.
CLK
input
1
Clock input or generated clock signal for synchronous logic.
CEN
input
1
Enable/control signal.
WEN
input
1
Enable/control signal.

adder_unit
Signal
Dir
Width
Description
a
input
[31:0]
Adder/ALU operand, carry, result, or subtract control signal.
b
input
[31:0]
Adder/ALU operand, carry, result, or subtract control signal.
sub
input
1
Adder/ALU operand, carry, result, or subtract control signal.
result
output
[31:0]
Adder/ALU operand, carry, result, or subtract control signal.

alu
Signal
Dir
Width
Description
aluop
input
[ 3:0]
ALU operation select, ALU operand, or ALU result signal.
opr_a
input
[31:0]
ALU operation select, ALU operand, or ALU result signal.
opr_b
input
[31:0]
ALU operation select, ALU operand, or ALU result signal.
opr_res
output
[31:0]
ALU operation select, ALU operand, or ALU result signal.

br_cond
Signal
Dir
Width
Description
rdata1
input
[31:0]
Register file read/write address, data, enable, or debug signal.
rdata2
input
[31:0]
Register file read/write address, data, enable, or debug signal.
br_type
input
[ 2:0]
Branch type, branch comparison, or branch taken/debug signal.
br_taken
output
1
Branch type, branch comparison, or branch taken/debug signal.

controller
Signal
Dir
Width
Description
opcode
input
[6:0]
Program counter value, next PC input, or PC debug signal.
funct3
input
[2:0]
Module-specific signal; see module purpose and connection context.
funct7
input
[6:0]
Module-specific signal; see module purpose and connection context.
funct12
input
[11:0]
Module-specific signal; see module purpose and connection context.
br_taken
input
1
Branch type, branch comparison, or branch taken/debug signal.
aluop
output
[3:0]
ALU operation select, ALU operand, or ALU result signal.
rf_en
output
1
Register file read/write address, data, enable, or debug signal.
sel_a
output
1
Multiplexer/control select signal.
sel_b
output
1
Multiplexer/control select signal.
rd_en
output
1
Enable/control signal.
wr_en
output
1
Enable/control signal.
wb_sel
output
[1:0]
Multiplexer/control select signal.
mem_acc_mode
output
[2:0]
Data memory load/store request, address, data, access mode, or debug signal.
br_type
output
[2:0]
Branch type, branch comparison, or branch taken/debug signal.
br_take
output
1
Branch type, branch comparison, or branch taken/debug signal.
csr_rd
output
1
CSR, trap, exception, MRET, ECALL, or EBREAK control/status signal.
csr_wr
output
1
CSR, trap, exception, MRET, ECALL, or EBREAK control/status signal.
is_mret
output
1
CSR, trap, exception, MRET, ECALL, or EBREAK control/status signal.
is_ecall
output
1
CSR, trap, exception, MRET, ECALL, or EBREAK control/status signal.
is_ebreak
output
1
CSR, trap, exception, MRET, ECALL, or EBREAK control/status signal.
illegal_inst
output
1
Instruction word or instruction debug/decode-related signal.

csr_reg
Signal
Dir
Width
Description
clk
input
1
Clock input or generated clock signal for synchronous logic.
rst
input
1
Active-high internal reset or reset status signal.
addr
input
[31:0]
Address bus signal.
wdata
input
[31:0]
Register file read/write address, data, enable, or debug signal.
pc
input
[31:0]
Program counter value, next PC input, or PC debug signal.
irq_valid
input
1
Interrupt request, interrupt status, or interrupt cause-related signal.
irq_cause
input
[31:0]
Interrupt request, interrupt status, or interrupt cause-related signal.
exception
input
1
CSR, trap, exception, MRET, ECALL, or EBREAK control/status signal.
exception_cause
input
[31:0]
CSR, trap, exception, MRET, ECALL, or EBREAK control/status signal.
csr_rd
input
1
CSR, trap, exception, MRET, ECALL, or EBREAK control/status signal.
csr_wr
input
1
CSR, trap, exception, MRET, ECALL, or EBREAK control/status signal.
is_mret
input
1
CSR, trap, exception, MRET, ECALL, or EBREAK control/status signal.
inst
input
[31:0]
Instruction word or instruction debug/decode-related signal.
rdata
output
[31:0]
Data bus signal.
epc
output
[31:0]
Program counter value, next PC input, or PC debug signal.
epc_taken
output
1
Program counter value, next PC input, or PC debug signal.

hazard_unit
Signal
Dir
Width
Description
rs1_DE
input
[4:0]
Module-specific signal; see module purpose and connection context.
rs2_DE
input
[4:0]
Module-specific signal; see module purpose and connection context.
rd_MW
input
[4:0]
Module-specific signal; see module purpose and connection context.
rf_en_MW
input
1
Register file read/write address, data, enable, or debug signal.
load_valid_WB
input
1
Handshake valid signal.
forward_a
output
1
Module-specific signal; see module purpose and connection context.
forward_b
output
1
Module-specific signal; see module purpose and connection context.
inst_IF
input
[31:0]
Instruction word or instruction debug/decode-related signal.
rd_DE
input
[4:0]
Module-specific signal; see module purpose and connection context.
wb_sel_DE
input
[1:0]
Multiplexer/control select signal.
br_taken
input
1
Branch type, branch comparison, or branch taken/debug signal.
stall_IF
output
1
Module-specific signal; see module purpose and connection context.
flush_DE
output
1
Module-specific signal; see module purpose and connection context.

imm_gen
Signal
Dir
Width
Description
inst
input
[31:0]
Instruction word or instruction debug/decode-related signal.
imm_val
output
[31:0]
Module-specific signal; see module purpose and connection context.

inst_dec
Signal
Dir
Width
Description
inst
input
[31:0]
Instruction word or instruction debug/decode-related signal.
rs1
output
[ 4:0]
Register file read/write address, data, enable, or debug signal.
rs2
output
[ 4:0]
Register file read/write address, data, enable, or debug signal.
rd
output
[ 4:0]
Register file read/write address, data, enable, or debug signal.
opcode
output
[ 6:0]
Program counter value, next PC input, or PC debug signal.
funct3
output
[ 2:0]
Module-specific signal; see module purpose and connection context.
funct7
output
[ 6:0]
Module-specific signal; see module purpose and connection context.

interrupt_controller
Signal
Dir
Width
Description
timer_irq
input
1
Interrupt request, interrupt status, or interrupt cause-related signal.
spi_irq
input
1
Interrupt request, interrupt status, or interrupt cause-related signal.
jtag_irq
input
1
Interrupt request, interrupt status, or interrupt cause-related signal.
irq_valid
output
1
Interrupt request, interrupt status, or interrupt cause-related signal.
irq_cause
output
[31:0]
Interrupt request, interrupt status, or interrupt cause-related signal.

mux_2x1
Signal
Dir
Width
Description
in_0
input
[31:0]
Module-specific signal; see module purpose and connection context.
in_1
input
[31:0]
Module-specific signal; see module purpose and connection context.
select_line
input
1
Multiplexer/control select signal.
out
output
[31:0]
Module-specific signal; see module purpose and connection context.

mux_4x1
Signal
Dir
Width
Description
in_0
input
[31:0]
Module-specific signal; see module purpose and connection context.
in_1
input
[31:0]
Module-specific signal; see module purpose and connection context.
in_2
input
[31:0]
Module-specific signal; see module purpose and connection context.
in_3
input
[31:0]
Module-specific signal; see module purpose and connection context.
select_line
input
[ 1:0]
Multiplexer/control select signal.
out
output
[31:0]
Module-specific signal; see module purpose and connection context.

pc
Signal
Dir
Width
Description
clk
input
1
Clock input or generated clock signal for synchronous logic.
rst
input
1
Active-high internal reset or reset status signal.
en
input
1
Enable/control signal.
pc_in
input
[31:0]
Program counter value, next PC input, or PC debug signal.
pc_out
output
[31:0]
Program counter value, next PC input, or PC debug signal.

reg_file
Signal
Dir
Width
Description
clk
input
1
Clock input or generated clock signal for synchronous logic.
rst
input
1
Active-high internal reset or reset status signal.
rf_en
input
1
Register file read/write address, data, enable, or debug signal.
rs1
input
[ 4:0]
Register file read/write address, data, enable, or debug signal.
rs2
input
[ 4:0]
Register file read/write address, data, enable, or debug signal.
rd
input
[ 4:0]
Register file read/write address, data, enable, or debug signal.
wdata
input
[31:0]
Register file read/write address, data, enable, or debug signal.
rdata1
output
[31:0]
Register file read/write address, data, enable, or debug signal.
rdata2
output
[31:0]
Register file read/write address, data, enable, or debug signal.

rv32i_csla_bec_32_
Signal
Dir
Width
Description
a
input
[31:0]
Adder/ALU operand, carry, result, or subtract control signal.
b
input
[31:0]
Adder/ALU operand, carry, result, or subtract control signal.
cin
input
1
Adder/ALU operand, carry, result, or subtract control signal.
sum
output
[31:0]
Adder/ALU operand, carry, result, or subtract control signal.
cout
output
1
Adder/ALU operand, carry, result, or subtract control signal.

csla_bec_block
Signal
Dir
Width
Description
a
input
[3:0]
Adder/ALU operand, carry, result, or subtract control signal.
b
input
[3:0]
Adder/ALU operand, carry, result, or subtract control signal.
cin
input
1
Adder/ALU operand, carry, result, or subtract control signal.
sum
output
[3:0]
Adder/ALU operand, carry, result, or subtract control signal.
cout
output
1
Adder/ALU operand, carry, result, or subtract control signal.

12. Key Internal Control and Debug Signals
Signal / Group
Meaning
pc_debug
Current or visible program counter value used for debug and testbench observation.
inst_debug
Current or visible instruction word used for debug and trace.
rf_we, rf_waddr, rf_wdata
Register file writeback enable, destination register and write data.
mem_we, mem_re, mem_addr, mem_wdata, mem_rdata
Memory access debug signals for store/load visibility.
br_taken_dbg
Branch taken indication exported for debug.
trap_taken
Trap/exception/interrupt entry indication.
epc_debug
Exception program counter/debug EPC value.
timer_irq_dbg
Timer interrupt debug visibility.
illegal_inst_dbg
Illegal instruction detection debug output from the CPU.
loader_done, loader_error, loader_busy, loader_words_loaded
SPI flash loader status signals for boot progress observation.
cpu_rst_dbg
Shows whether CPU is being held in reset by the boot/reset control logic.
boot_from_spi_flash
Mode select: hardware SPI flash boot path enabled when asserted.

13. Memory Access, Byte Lanes and Data Format
The processor-visible memory data path is 32 bits. Stores use byte lane strobes. Loads return 32-bit data and the core performs sign-extension or zero-extension according to instruction type.
Access
Byte lanes / behavior
SB
Writes one selected byte using WSTRB according to address[1:0].
SH
Writes two adjacent bytes. Address should be halfword aligned.
SW
Writes all four bytes. Address should be word aligned.
LB
Reads one byte and sign-extends to 32 bits.
LBU
Reads one byte and zero-extends to 32 bits.
LH
Reads one halfword and sign-extends to 32 bits.
LHU
Reads one halfword and zero-extends to 32 bits.
LW
Reads full 32-bit word.

Address[1:0]
Little-endian byte lane
00
bits [7:0]
01
bits [15:8]
10
bits [23:16]
11
bits [31:24]

14. Reset, Clock and SDC Notes
The design uses an external clock and active-low reset. reset_sync asynchronously asserts reset and synchronously deasserts the internal reset. For synthesis constraints, false-path the asynchronous reset input to registers, but do not false-path the synchronized reset output used inside the SoC.
Correct reset_sync SDC idea:
create_clock -name clk -period 10.0 [get_ports clk]
set_false_path -from [get_ports arst_n] -to [all_registers]

For reset_sync alone, do not apply input delay to arst_n as a normal data input.
For full SoC, constrain normal data inputs separately from clock/reset.
15. Synthesis and DFT Notes
Topic
Recommendation / Status
Top for final synthesis
rv32i_chip_top_bootrom_spiflash
SRAM synthesis handling
Use SPRAM_1024x36 synthesis stub as black box/macro. Do not synthesize behavioral SRAM into standard cells.
Normal synthesis flow
read_hdl, elaborate, read_sdc, check_design, syn_generic, syn_map, syn_opt, report_area, report_power, report_timing, write_hdl.
Module-level synthesis
Useful for learning area/timing contribution of individual blocks such as ALU, reg_file, CSR, AXI, timer, etc.
Final top synthesis
Only the full top synthesis report is the final design-level area/timing/power report.
Scan insertion
For basic scan flow, disable clock gating unless scan-aware clock gates/test enable are inserted.
Power report interpretation
Processor/core reports may not include black-box SRAM macro power or post-CTS clock tree power.

16. Verification Summary and Test Coverage
The design has been verified through directed SoC-level simulations for boot, AXI memory access, CSR/trap behavior, ECALL/EBREAK, GPIO/debug signatures, SPI boot and SRAM byte-lane access. Official RISC-V architectural-test closure should be stated separately and not overclaimed unless all official tests are fully closed.
Feature
Verification Focus
Boot ROM path
CPU starts from Boot ROM address and jumps to Program SRAM.
SPI flash boot path
Boot image copied from SPI flash model to Program SRAM; boot_done observed.
AXI SRAM
Read/write, WSTRB byte lane write, halfword/word access.
GPIO/debug
CPU writes pass/fail/status signature to memory-mapped debug/GPIO registers.
Timer interrupt
Timer register programming and interrupt/debug visibility.
CSR/system
Zicsr semantics, ECALL/EBREAK trap causes, MRET return behavior.
ALU/instruction flow
R/I/U/B/J/load/store instruction groups covered by directed tests.

17. Report-Ready Final Description
The final design is a 32-bit RV32I SoC using a 3-stage pipelined processor core and an AXI4-Lite interconnect. The SoC includes Boot ROM, Program SRAM, Data SRAM, Timer, GPIO/debug, SPI peripheral, interrupt controller and a hardware SPI flash boot loader. Program SRAM and Data SRAM are implemented using foundry-provided SPRAM_1024x36 SRAM macros through synthesis stubs. On reset, the hardware boot loader can copy the application from external SPI flash into Program SRAM. After boot_done is asserted, the CPU starts at Boot ROM and jumps to the loaded program at 0x0001_0000. The design supports RV32I integer instructions, load/store operations, branches, jumps, CSR operations, ECALL/EBREAK trap handling, MRET and interrupt support.
18. Module Dependency Summary
Module
Depends on / Connected to
alu
adder_unit -> rv32i_csla_bec_32_ -> csla_bec_block
processor_soc
pc, inst_dec, imm_gen, controller, reg_file, alu, br_cond, csr_reg, hazard_unit, interrupt_controller
rv32i_axi_master_wrapper
processor_soc simple memory ports and AXI interconnect master ports
axi4lite_soc_interconnect
Boot ROM, Program SRAM, Data SRAM, Timer, GPIO, SPI slaves
rv32i_soc_top_bootrom_spiflash
All SoC blocks and boot/reset sequencing
rv32i_chip_top_bootrom_spiflash
reset_sync and SoC top with external pads
