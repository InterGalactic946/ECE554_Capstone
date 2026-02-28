///////////////////////////////////////////////////////////////
// HazardDetectionUnit.v: Handle stall conditions for Branch //
// Instructions (B, BR) and load-to-use hazards.             //
//                                                           //
// This module detects hazards in the pipeline and applies   //
// necessary stalls for both branch and load instructions.   //
///////////////////////////////////////////////////////////////
module HazardDetectionUnit (
    input logic [3:0] SrcReg1,          // First source register ID (Rs) in ID stage
    input logic [3:0] SrcReg2,          // Second source register ID (Rt) in ID stage
    input logic ID_EX_RegWrite,         // Register write signal from ID/EX stage
    input logic [3:0] ID_EX_reg_rd,     // Destination register ID in ID/EX stage
    input logic ID_EX_MemEnable,        // Data memory enable signal from ID/EX stage
    input logic ID_EX_MemWrite,         // Data memory write signal from ID/EX stage
    input logic MemWrite,               // Memory write signal for current instruction
    input logic ICACHE_miss,            // Signal indicating that the instruction cache had a miss so PC must stall and NOP inserted into IF_ID
    input logic DCACHE_miss,            // Signal indicating that the data cache had a miss so whole pipeline must stall and NOP inserted into MEM_WB
    input logic update_PC,              // Signal that we need to update the PC
    
    output logic PC_stall,              // Stall signal for IF stage
    output logic IF_ID_stall,           // Stall signal for ID stage
    output logic ID_EX_stall,           // Stall signal for EX stage
    output logic EX_MEM_stall,          // Stall signal for MEM stage
    output logic MEM_flush,             // Flush signal for EX/MEM register
    output logic ID_flush,              // Flush signal for ID/EX register
    output logic IF_flush               // Flush signal for IF/ID register
);

  /////////////////////////////////////////////////
  // Declare any internal signals as type wire  //
  ///////////////////////////////////////////////
  logic ID_EX_MemRead;      // Indicates instruction in the EX stage is a LW instruction
  logic load_to_use_hazard; // Signal to detect and place a load-to-use stall in the pipeline
  ////////////////////////////////////////////////

  ////////////////////////////////////////////////////////
  // Stall conditions for LW/SW, B, and BR instructions //
  ////////////////////////////////////////////////////////
  // We stall PC whenever we stall the IF_ID pipeline register or when the ICACHE is busy.
  assign PC_stall = ICACHE_miss | IF_ID_stall;

  // We stall anytime we stall on EX_MEM or when there is a load to use hazard in the decode stage.
  assign IF_ID_stall = EX_MEM_stall | load_to_use_hazard;

  // We stall anytime we stall the EX_MEM pipeline register.
  assign ID_EX_stall = EX_MEM_stall;

  // We stall anytime the DCACHE had a miss.
  assign EX_MEM_stall = DCACHE_miss;
  /////////////////////////////////////////////////////

  ///////////////////////////////////////////////////////////////////
  // Flush the pipeline on memory accesses or branch misprediction //
  ///////////////////////////////////////////////////////////////////
  // We flush the MEM_WB pipeline register whenever the DCACHE had a miss.
  assign MEM_flush = DCACHE_miss;
  
  // We flush the ID_EX pipeline register when not stalling on execute and whenever there is a load to use hazard, i.e. send nops to execute onward.
  assign ID_flush = (~ID_EX_stall) & (load_to_use_hazard);

  // We flush the IF_ID pipeline instruction word whenever we are when not stalling on decode and stalling on PC, i.e. on an ICACHE miss, or need to update the PC, i.e. on an incorrect branch fetch.
  assign IF_flush = (~IF_ID_stall) & (ICACHE_miss | update_PC);
  /////////////////////////////////////////////////////////////

  //////////////////////////////////
  // Load-to-Use Hazard Detection //
  //////////////////////////////////
  // We are reading from memory in the ID/EX stage if data memory is enabled and we are not writing to it (LW).
  assign ID_EX_MemRead = ID_EX_MemEnable & ~ID_EX_MemWrite;
  
  // A load to use hazard is detected when the instruction in the EX stage (LW) is writing to the same register that the instruction 
  // in the decode stage is trying to read. We don't want to stall when the second read register is the same and
  // is a save word instruction, as we have MEM-MEM forwarding available.
  assign load_to_use_hazard = (ID_EX_MemRead & (ID_EX_reg_rd != 4'h0) & ((ID_EX_reg_rd == SrcReg1) | ((ID_EX_reg_rd == SrcReg2) & ~MemWrite)));
  ////////////////////////////////////

endmodule