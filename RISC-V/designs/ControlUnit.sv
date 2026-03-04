// ------------------------------------------------------------
// Module: ControlUnit
// Description: Decode-stage control unit. Generates all control
//              signals required by the core datapath.
//
//              Supports two decode modes:
//              1) Legacy decode behavior (default core mode).
//              2) Optional RV32I decode bridge mode using
//                 definitions from rv32i_pkg.
// Author: Srivibhav Jonnalagadda
// Date: 03-04-2026
// ------------------------------------------------------------
import rv32i_pkg::*;

module ControlUnit #(
    parameter bit USE_RV32I_DECODE = 1'b0 // 0: legacy decode, 1: RV32I decode bridge.
)(
    input logic [3:0] Opcode,      // Legacy opcode of the current instruction.

    // RV32I decode fields (already sliced in Decode stage).
    input logic [6:0] opcode7_i,   // inst[6:0]
    input logic [2:0] funct3_i,    // inst[14:12]
    input logic [6:0] funct7_i,    // inst[31:25]

    output logic Branch,           // Indicates control-flow instruction requiring branch resolution.

    output logic [3:0] ALUOp,      // ALU operation code (legacy ALU encoding).
    output logic ALUSrc,           // Selects ALU second input: immediate (1) or register data (0).
    output logic RegSrc,           // Legacy source-register select (used by LLB/LHB style instructions).
    output logic Z_en,             // Enable signal for zero-flag update.
    output logic NV_en,            // Enable signal for negative/overflow flag update.

    output logic MemEnable,        // Enables data-memory access.
    output logic MemWrite,         // Enables data-memory write.

    output logic RegWrite,         // Enables register-file writeback.
    output logic MemtoReg,         // Selects memory read data for register writeback.
    output logic HLT,              // Indicates halt-class instruction.
    output logic PCS               // Legacy PCS control signal.
);

    //////////////////////////////////////////////////////////
    // Generate control signals by decoding instruction     //
    //////////////////////////////////////////////////////////
    always_comb begin
        // Default values for all control signals.
        ALUSrc    = 1'b0;
        MemtoReg  = 1'b0;
        RegWrite  = 1'b1;
        MemEnable = 1'b0;
        MemWrite  = 1'b0;
        Branch    = 1'b0;
        RegSrc    = 1'b0;
        PCS       = 1'b0;
        HLT       = 1'b0;
        ALUOp     = Opcode;
        Z_en      = 1'b0;
        NV_en     = 1'b0;

        //////////////////////////////////////////////////////
        // LEGACY DECODE PATH (current datapath behavior)   //
        //////////////////////////////////////////////////////
        if (!USE_RV32I_DECODE) begin
            case (Opcode)
                4'b0000, 4'b0001: begin // ADD/SUB
                    Z_en  = 1'b1;
                    NV_en = 1'b1;
                end
                4'b0010: begin // XOR
                    Z_en = 1'b1;
                end
                4'b0100, 4'b0101, 4'b0110: begin // Shift operations
                    ALUSrc = 1'b1;
                    Z_en   = 1'b1;
                end
                4'b0111: begin // PADDSB
                end
                4'b1000: begin // LW
                    ALUSrc    = 1'b1;
                    MemtoReg  = 1'b1;
                    MemEnable = 1'b1;
                end
                4'b1001: begin // SW
                    ALUSrc    = 1'b1;
                    RegWrite  = 1'b0;
                    MemEnable = 1'b1;
                    MemtoReg  = 1'b1;
                    MemWrite  = 1'b1;
                end
                4'b1010, 4'b1011: begin // LLB/LHB
                    ALUSrc = 1'b1;
                    RegSrc = 1'b1;
                end
                4'b1100, 4'b1101: begin // B/BR
                    Branch   = 1'b1;
                    RegWrite = 1'b0;
                end
                4'b1110: begin // PCS
                    PCS = 1'b1;
                end
                4'b1111: begin // HLT
                    HLT      = 1'b1;
                    RegWrite = 1'b0;
                end
                default: begin
                    RegWrite = 1'b0;
                end
            endcase

        //////////////////////////////////////////////////////
        // RV32I DECODE BRIDGE PATH (incremental migration) //
        //////////////////////////////////////////////////////
        end else begin
            // NOTE:
            // ALUOp is still a legacy 4-bit encoding. Unsupported RV32I
            // operations are intentionally deasserted until ALU/control
            // migration is completed end-to-end.
            case (opcode7_i)
                OPCODE_OP: begin
                    RegWrite = 1'b1;
                    case (funct3_i)
                        F3_ADD_SUB: begin // ADD/SUB
                            ALUOp = (funct7_i == F7_ALT) ? 4'h1 : 4'h0;
                            Z_en  = 1'b1;
                            NV_en = 1'b1;
                        end
                        F3_XOR: begin // XOR
                            ALUOp = 4'h2;
                            Z_en  = 1'b1;
                        end
                        F3_SLL: begin // SLL
                            ALUOp  = 4'h4;
                            ALUSrc = 1'b0;
                            Z_en   = 1'b1;
                        end
                        F3_SRL_SRA: begin // SRL/SRA
                            ALUOp  = (funct7_i == F7_ALT) ? 4'h5 : 4'h6;
                            ALUSrc = 1'b0;
                            Z_en   = 1'b1;
                        end
                        default: begin
                            RegWrite = 1'b0;
                        end
                    endcase
                end

                OPCODE_OP_IMM: begin
                    RegWrite = 1'b1;
                    ALUSrc   = 1'b1;
                    case (funct3_i)
                        F3_ADD_SUB: begin // ADDI
                            ALUOp = 4'h0;
                            Z_en  = 1'b1;
                            NV_en = 1'b1;
                        end
                        F3_XOR: begin // XORI
                            ALUOp = 4'h2;
                            Z_en  = 1'b1;
                        end
                        F3_SLL: begin // SLLI
                            ALUOp = 4'h4;
                            Z_en  = 1'b1;
                        end
                        F3_SRL_SRA: begin // SRLI/SRAI
                            ALUOp = (funct7_i == F7_ALT) ? 4'h5 : 4'h6;
                            Z_en  = 1'b1;
                        end
                        default: begin
                            RegWrite = 1'b0;
                        end
                    endcase
                end

                OPCODE_LOAD: begin
                    ALUSrc    = 1'b1;
                    MemtoReg  = 1'b1;
                    MemEnable = 1'b1;
                    RegWrite  = 1'b1;
                    ALUOp     = 4'h8;
                end

                OPCODE_STORE: begin
                    ALUSrc    = 1'b1;
                    RegWrite  = 1'b0;
                    MemEnable = 1'b1;
                    MemWrite  = 1'b1;
                    MemtoReg  = 1'b1;
                    ALUOp     = 4'h9;
                end

                OPCODE_BRANCH: begin
                    Branch   = 1'b1;
                    RegWrite = 1'b0;
                end

                OPCODE_JAL, OPCODE_JALR: begin
                    Branch   = 1'b1;
                    RegWrite = 1'b1;
                end

                OPCODE_LUI, OPCODE_AUIPC: begin
                    RegWrite = 1'b1;
                    ALUSrc   = 1'b1;
                    ALUOp    = 4'h0;
                end

                OPCODE_SYSTEM, OPCODE_MISC_MEM: begin
                    RegWrite = 1'b0;
                end

                default: begin
                    RegWrite = 1'b0;
                end
            endcase
        end
    end
    //////////////////////////////////////////////////////////

endmodule
