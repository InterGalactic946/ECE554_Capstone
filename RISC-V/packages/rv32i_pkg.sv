// ------------------------------------------------------------
// Package: rv32i_pkg
// Description: Shared RV32I ISA constants, ALU op encodings,
// and immediate extraction helpers.
// Author: Srivibhav Jonnalagadda
// Date: 03-03-2026
// ------------------------------------------------------------
package rv32i_pkg;

    // --------------------------------------------------------
    // Architectural constants
    // --------------------------------------------------------
    localparam int unsigned XLEN = 32;

    // --------------------------------------------------------
    // RV32I opcode constants (inst[6:0])
    // --------------------------------------------------------
    localparam logic [6:0] OPCODE_LUI      = 7'b0110111;
    localparam logic [6:0] OPCODE_AUIPC    = 7'b0010111;
    localparam logic [6:0] OPCODE_JAL      = 7'b1101111;
    localparam logic [6:0] OPCODE_JALR     = 7'b1100111;
    localparam logic [6:0] OPCODE_BRANCH   = 7'b1100011;
    localparam logic [6:0] OPCODE_LOAD     = 7'b0000011;
    localparam logic [6:0] OPCODE_STORE    = 7'b0100011;
    localparam logic [6:0] OPCODE_OP_IMM   = 7'b0010011;
    localparam logic [6:0] OPCODE_OP       = 7'b0110011;
    localparam logic [6:0] OPCODE_MISC_MEM = 7'b0001111;
    localparam logic [6:0] OPCODE_SYSTEM   = 7'b1110011;

    // --------------------------------------------------------
    // Common funct3 constants by instruction class
    // --------------------------------------------------------

    // BRANCH funct3 values
    localparam logic [2:0] F3_BEQ  = 3'b000;
    localparam logic [2:0] F3_BNE  = 3'b001;
    localparam logic [2:0] F3_BLT  = 3'b100;
    localparam logic [2:0] F3_BGE  = 3'b101;
    localparam logic [2:0] F3_BLTU = 3'b110;
    localparam logic [2:0] F3_BGEU = 3'b111;

    // LOAD funct3 values
    localparam logic [2:0] F3_LB   = 3'b000;
    localparam logic [2:0] F3_LH   = 3'b001;
    localparam logic [2:0] F3_LW   = 3'b010;
    localparam logic [2:0] F3_LBU  = 3'b100;
    localparam logic [2:0] F3_LHU  = 3'b101;

    // STORE funct3 values
    localparam logic [2:0] F3_SB   = 3'b000;
    localparam logic [2:0] F3_SH   = 3'b001;
    localparam logic [2:0] F3_SW   = 3'b010;

    // OP-IMM / OP funct3 values
    localparam logic [2:0] F3_ADD_SUB = 3'b000;
    localparam logic [2:0] F3_SLL     = 3'b001;
    localparam logic [2:0] F3_SLT     = 3'b010;
    localparam logic [2:0] F3_SLTU    = 3'b011;
    localparam logic [2:0] F3_XOR     = 3'b100;
    localparam logic [2:0] F3_SRL_SRA = 3'b101;
    localparam logic [2:0] F3_OR      = 3'b110;
    localparam logic [2:0] F3_AND     = 3'b111;

    // JALR funct3 value
    localparam logic [2:0] F3_JALR    = 3'b000;

    // MISC-MEM funct3 values
    localparam logic [2:0] F3_FENCE   = 3'b000;
    localparam logic [2:0] F3_FENCE_I = 3'b001;

    // SYSTEM funct3 values
    localparam logic [2:0] F3_PRIV    = 3'b000; // ECALL/EBREAK
    localparam logic [2:0] F3_CSRRW   = 3'b001;
    localparam logic [2:0] F3_CSRRS   = 3'b010;
    localparam logic [2:0] F3_CSRRC   = 3'b011;
    localparam logic [2:0] F3_CSRRWI  = 3'b101;
    localparam logic [2:0] F3_CSRRSI  = 3'b110;
    localparam logic [2:0] F3_CSRRCI  = 3'b111;

    // --------------------------------------------------------
    // funct7 constants used by RV32I OP/OP-IMM variants
    // --------------------------------------------------------
    localparam logic [6:0] F7_BASE = 7'b0000000;
    localparam logic [6:0] F7_ALT  = 7'b0100000; // SUB/SRA variant selector

    // --------------------------------------------------------
    // SYSTEM immediate constants for priv-encoded operations
    // (identified when opcode=SYSTEM and funct3=F3_PRIV)
    // --------------------------------------------------------
    localparam logic [11:0] IMM12_ECALL  = 12'h000;
    localparam logic [11:0] IMM12_EBREAK = 12'h001;

    // --------------------------------------------------------
    // ALU operation enum used by control/decode
    // --------------------------------------------------------
    typedef enum logic [4:0] {
        ALU_ADD  = 5'd0,
        ALU_SUB  = 5'd1,
        ALU_AND  = 5'd2,
        ALU_OR   = 5'd3,
        ALU_XOR  = 5'd4,
        ALU_SLL  = 5'd5,
        ALU_SRL  = 5'd6,
        ALU_SRA  = 5'd7,
        ALU_SLT  = 5'd8,
        ALU_SLTU = 5'd9,
        ALU_COPY_B = 5'd10 // Useful for LUI pass-through behavior
    } alu_op_e;

    // --------------------------------------------------------
    // Immediate extraction helpers
    // --------------------------------------------------------

    // I-type immediate: inst[31:20], sign-extended to 32 bits.
    function automatic logic [31:0] rv32i_imm_i(input logic [31:0] inst);
        rv32i_imm_i = {{20{inst[31]}}, inst[31:20]};
    endfunction

    // S-type immediate: inst[31:25|11:7], sign-extended to 32 bits.
    function automatic logic [31:0] rv32i_imm_s(input logic [31:0] inst);
        rv32i_imm_s = {{20{inst[31]}}, inst[31:25], inst[11:7]};
    endfunction

    // B-type immediate: inst[31|7|30:25|11:8|0], sign-extended to 32 bits.
    function automatic logic [31:0] rv32i_imm_b(input logic [31:0] inst);
        rv32i_imm_b = {{19{inst[31]}}, inst[31], inst[7], inst[30:25], inst[11:8], 1'b0};
    endfunction

    // U-type immediate: inst[31:12] shifted left by 12.
    function automatic logic [31:0] rv32i_imm_u(input logic [31:0] inst);
        rv32i_imm_u = {inst[31:12], 12'b0};
    endfunction

    // J-type immediate: inst[31|19:12|20|30:21|0], sign-extended to 32 bits.
    function automatic logic [31:0] rv32i_imm_j(input logic [31:0] inst);
        rv32i_imm_j = {{11{inst[31]}}, inst[31], inst[19:12], inst[20], inst[30:21], 1'b0};
    endfunction

endpackage
