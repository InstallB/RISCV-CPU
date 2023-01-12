`define ROB_SIZE 32
`define ROB_SIZE_LOG 5
`define RS_SIZE 32
`define RS_SIZE_LOG 5
`define SLB_SIZE 32
`define SLB_SIZE_LOG 5
`define ICACHE_SIZE 256
`define ICACHE_SIZE_LOG 8

`define OP_SIZE 38
`define OP_SIZE_LOG 6

`define NOP 0
`define LUI 1
`define AUIPC 2
`define JAL 3
`define JALR 4

`define BEQ 5
`define BNE 6
`define BLT 7
`define BGE 8
`define BLTU 9
`define BGEU 10
// 'B' type

`define LB 11
`define LH 12
`define LW 13
`define LBU 14
`define LHU 15
// 'L' type

`define SB 16
`define SH 17
`define SW 18
// 'S' type

`define ADDI 19
`define SLTI 20
`define SLTIU 21
`define XORI 22
`define ORI 23
`define ANDI 24
`define SLLI 25
`define SRLI 26
`define SRAI 27

`define ADD 28
`define SUB 29
`define SLL 30
`define SLT 31
`define SLTU 32
`define XOR 33
`define SRL 34
`define SRA 35
`define OR 36
`define AND 37
// 'C' type