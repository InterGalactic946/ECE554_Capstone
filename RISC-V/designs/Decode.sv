//////////////////////////////////////////////////////////////
// Decode_model.sv: Model Instruction Decode Stage          //
//                                                          //
// This module implements the instruction decode stage of   //
// the pipeline for the model CPU.                          //
//////////////////////////////////////////////////////////////
module Decode (
    input logic clk,                       // System clock
    input logic rst,                       // Active high synchronous reset
    input logic [31:0] pc_curr,            // The current fetched PC value
    input logic [31:0] pc_inst,            // The current instruction word
    input logic [31:0] pc_next,            // The next instruction's address
    input logic [2:0] flags,               // Flag register signals (ZF, VF, NF)
    input logic [31:0] IF_ID_predicted_target, // Predicted target address from the branch predictor of the previous instruction
    input logic [1:0] ForwardA,            // Forwarding signal for the first ALU input (ALU_In1) to ID stage
    input logic [1:0] ForwardB,            // Forwarding signal for the second ALU input (ALU_In2) to ID stage
    input logic [31:0] EX_result,          // Result from the EX stage (ALU output)
    input logic [31:0] MEM_result,         // Result from the MEM stage
    
    input logic MEM_WB_RegWrite,           // Write enable to the register file (from the MEM/WB stage)
    input logic [3:0] MEM_WB_reg_rd,       // Register ID of the destination register (from the MEM/WB stage)
    input logic [31:0] RegWriteData,       // Data to write to the register file (from the MEM/WB stage)
    
    output logic [110:0] EX_signals,       // Execute stage control signals
    output logic [33:0] MEM_signals,       // Memory stage control signals
    output logic [7:0] WB_signals,         // Write-back stage control signals
    
    output logic actual_taken,             // Signal used to determine whether branch instruction met condition codes
    output logic wen_BHT,                  // Write enable for BHT (Branch History Table)
    output logic [31:0] branch_target,     // 16-bit address of the branch target
    output logic wen_BTB,                  // Write enable for BTB (Branch Target Buffer)
    output logic [31:0] actual_target,     // 16-bit address of the actual target
    output logic update_PC                 // Signal to update the PC with the actual target
  );
  
  /////////////////////////////////////////////////
  // Declare any internal signals as type wire  //
  ///////////////////////////////////////////////
  /////////////////////////// DECODE INSTRUCTION SIGNALS //////////////////////////
  logic [3:0] opcode;        // Opcode of the instruction
  logic [6:0] opcode7;       // RV32I opcode field inst[6:0].
  logic [2:0] funct3;        // RV32I funct3 field inst[14:12].
  logic [6:0] funct7;        // RV32I funct7 field inst[31:25].
  logic is_NOP;              // Indicates a NOP instruction
  /********************************** REGFILE Signals ******************************/
  logic [3:0] reg_rs;         // Register ID of the first source register extracted from the instruction
  logic [3:0] reg_rt;         // Register ID of the second source register extracted from the instruction
  logic [31:0] SrcReg1_data;  // Data from the first source register
  logic [31:0] SrcReg2_data;  // Data from the second source register
  logic RegSrc;               // Selects register source based on LLB/LHB instructions
  /********************************** ALU Signals **********************************/
  logic [3:0] imm;            // immediate value decoded from the instruction
  logic [31:0] imm_ext;       // Sign-extended or zero-extended immediate from the instruction
  logic [7:0] LB_imm;         // Immediate for LLB/LHB instructions
  /********************************************************************************/
  /////////////////////////// BRANCH CONTROL SIGNALS //////////////////////////////
  logic [8:0] Branch_imm;     // Immediate for branch instructions
  logic is_branch;            // Indicates a branch instruction
  logic is_BR;                // Indicates a branch register instruction
  logic [2:0] c_codes;        // Condition codes for branch instructions
  logic [31:0] Rs_data;       // Data from the first source register (Rs) for branch instructions
  ///////////////////////////// EXECUTE STAGE ////////////////////////////////////
  logic [3:0] SrcReg1;        // Register ID of the first source register
  logic [3:0] SrcReg2;        // Register ID of the second source register
  logic [31:0] ALU_In1;       // First ALU input
  logic [31:0] ALU_imm;       // Immediate for I-type ALU instructions
  logic [31:0] ALU_In2;       // Second ALU input
  logic [3:0] ALUOp;          // ALU operation code
  logic ALUSrc;               // Selects second ALU input (immediate or SrcReg2_data) based on instruction type
  logic Z_en, NV_en;          // Enables setting the Z, N, and V flags
  /////////////////////////// MEMORY STAGE ///////////////////////////////////////
  logic [31:0] MemWriteData;  // Data written to the data memory for SW
  logic MemEnable;            // Enables reading from memory
  logic MemWrite;             // Enables writing to memory
  /////////////////////////// WRITE BACK STAGE ///////////////////////////////////
  logic [3:0] reg_rd;         // Register ID of the destination register
  logic RegWrite;             // Enables writing to the register file
  logic MemToReg;             // Selects data to write back to the register file        
  logic HLT;                  // Indicates a HLT instruction
  logic PCS;                  // Indicates a PCS instruction
  ////////////////////////////////////////////////////////////////////////////////

  //////////////////////////////////////////////
  // Decode control signals from the opcode   //
  //////////////////////////////////////////////
  // Get the opcode from the instructions.
  assign opcode = pc_inst[15:12];
  assign opcode7 = pc_inst[6:0];
  assign funct3 = pc_inst[14:12];
  assign funct7 = pc_inst[31:25];

  // Indicates a NOP instruction.
  assign is_NOP = (pc_inst == 32'h0000_0000);

  // Instantiate the Control Unit.
  ControlUnit iCC (
    .Opcode(opcode),
    .opcode7_i(opcode7),
    .funct3_i(funct3),
    .funct7_i(funct7),
    
    .Branch(is_branch),
    
    .ALUOp(ALUOp),
    .ALUSrc(ALUSrc),
    .RegSrc(RegSrc),
    .Z_en(Z_en),
    .NV_en(NV_en),
    
    .MemEnable(MemEnable),
    .MemWrite(MemWrite),
    .RegWrite(RegWrite),
    .MemtoReg(MemToReg),
    .HLT(HLT),
    .PCS(PCS)
  );
  //////////////////////////////////////////////

  ////////////////////////////////////////////////////////////
  // Package each stage's control signals for the pipeline  //
  ////////////////////////////////////////////////////////////
  // Package the execute stage control signals.
  assign EX_signals = (is_NOP) ? 111'd0 : {SrcReg1, SrcReg2, ALU_In1, ALU_imm, ALU_In2, ALUOp, ALUSrc, Z_en, NV_en};

  // Package the memory stage control signals.
  assign MEM_signals = (is_NOP) ? 34'd0 : {MemWriteData, MemEnable, MemWrite};

  // Package the write back stage control signals.
  assign WB_signals = (is_NOP) ? 8'h00 : {reg_rd, RegWrite, MemToReg, HLT, PCS};
  /////////////////////////////////////////////////////////////

  //////////////////////////////////////////////////////////////////////
  // Determine the branch target address and whether branch is taken  //
  //////////////////////////////////////////////////////////////////////
  // Get the 9-bit right shifted branch target offset.
  assign Branch_imm = pc_inst[8:0];
  
  // Indicates the branch is a BR instruction.
  assign is_BR = pc_inst[12];

  // Get the condition codes to determine if branch is taken or not.
  assign c_codes = pc_inst[11:9];

  // We update the PC to fetch the actual target when the current instruction fetched is not the same as the actual target, on a branch instruction.
  assign update_PC = (pc_curr != actual_target) & (is_branch);

  // Get the Rs data for branch instructions.
  assign Rs_data = (ForwardA == 2'b10) ? EX_result  :
                   (ForwardA == 2'b01) ? MEM_result :
                    SrcReg1_data;

  // Instantiate the Branch Control Unit.
  Branch_Control iBC (
      .C(c_codes),
      .I(Branch_imm),
      .F(flags),
      .Rs_data(Rs_data),
      .Branch(is_branch),
      .BR(is_BR),
      .IF_ID_predicted_target(IF_ID_predicted_target),
      .PC_next(pc_next),
      
      .taken(actual_taken),
      .wen_BHT(wen_BHT),
      .PC_branch(branch_target),
      .wen_BTB(wen_BTB),
      .actual_target(actual_target)
  );
  ////////////////////////////////////////////////////////////////////////

  //////////////////////////////
  // Access the Register File //
  //////////////////////////////
  // Extract the register id's from the instruction word.
  assign reg_rd = pc_inst[11:8]; // destination register id
  assign reg_rs = pc_inst[7:4];  // first source register id
  assign reg_rt = pc_inst[3:0];  // second source register id

  // Get the immediate value for I-type instructions.
  assign imm = pc_inst[3:0];
  assign LB_imm = pc_inst[7:0];

  // Select the source register for ALU operations.
  assign SrcReg1 = (RegSrc) ? reg_rd : reg_rs;
  assign SrcReg2 = (MemWrite) ? reg_rd : reg_rt;

  // Get the memory write data as coming from the second read register.
  assign MemWriteData = (ForwardB == 2'b10) ? EX_result  :
                        (ForwardB == 2'b01) ? MEM_result :
                          SrcReg2_data;
  
  // Instantiate the register file.
  RegisterFile iRF (
      .clk(clk),
      .rst(rst),
      .SrcReg1(SrcReg1),
      .SrcReg2(SrcReg2),
      .DstReg(MEM_WB_reg_rd),
      .WriteReg(MEM_WB_RegWrite),
      .DstData(RegWriteData),
      
      .SrcData1(SrcReg1_data),
      .SrcData2(SrcReg2_data)
  );
  ////////////////////////////////////////////////////////////////////////

  ///////////////////////////////////////
  // Determine the ALU input operands  //
  ///////////////////////////////////////
  // Sign-extend or zero-extend the immediate from the instruction based on memory vs non-memory instructions.
  assign imm_ext = (MemEnable) ? {{28{imm[3]}}, imm} : {28'h0000000, imm};

  // Grab the LLB/LHB immediate or the extended immediate based on the instruction as the ALU immediate.
  assign ALU_imm = (RegSrc) ? {24'h000000, LB_imm} : imm_ext;
  
  // Get the first ALU input as the first register read out.
  assign ALU_In1 = (ForwardA == 2'b10) ? EX_result  :
                   (ForwardA == 2'b01) ? MEM_result :
                    SrcReg1_data;

  // Get the second ALU input as the second register read out (we pass the ALU_imm and ALUSrc to the 
  // pipeline to choose b/w regfile data or immediate).
  assign ALU_In2 = (ForwardB == 2'b10) ? EX_result  :
                   (ForwardB == 2'b01) ? MEM_result :
                    SrcReg2_data;
  /////////////////////////////////////////////////////////////////////////////

endmodule
