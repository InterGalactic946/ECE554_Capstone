///////////////////////////////////////////////////////////////
// ForwardingUnit.v: Forwarding Unit for Hazard Detection    //
//                                                           //
// This module implements the forwarding unit of the         //
// pipeline. It determines whether forwarding should occur   //
// from MEM or WB stages based on the source and destination //
// registers of the EX and MEM stages. The forwarding logic  //
// prevents hazards by ensuring the correct values are used  //
// in the EX stage.                                          //
///////////////////////////////////////////////////////////////
module ForwardingUnit (
    input logic [3:0] SrcReg1,       // First source register ID (Rs) in ID stage
    input logic [3:0] SrcReg2,       // Second source register ID (Rt) in ID stage
    input logic [3:0] ID_EX_SrcReg1, // Pipelined first source register ID from the decode stage
    input logic [3:0] ID_EX_SrcReg2, // Pipelined second source register ID from the decode stage
    input logic [3:0] EX_MEM_SrcReg2,// Pipelined register ID second source register from the memory stage
    input logic [3:0] ID_EX_reg_rd,  // Pipelined register ID of the destination register from the decode stage
    input logic [3:0] EX_MEM_reg_rd, // Pipelined register ID of the destination register from the memory stage
    input logic [3:0] MEM_WB_reg_rd, // Pipelined register ID of the destination register from the write-back stage
    input logic ID_EX_RegWrite,      // Pipelined write enable to the register file from the decode stage 
    input logic EX_MEM_RegWrite,     // Pipelined write enable to the register file from the execute stage
    input logic MEM_WB_RegWrite,     // Pipelined write enable to the register file from the write-back stage

    output logic [1:0] ForwardA,     // Forwarding signal for the first ALU input (ALU_In1) to ID stage
    output logic [1:0] ForwardB,     // Forwarding signal for the second ALU input (ALU_In2) to ID stage
    output wire Forward_MEM          // Forwarding signal for the SW instruction in the MEM stage
);

  /////////////////////////////////////////////////
  // Declare any internal signals as type wire  //
  ///////////////////////////////////////////////
  logic EX_to_ID_haz_A;  // Detects a hazard between the begining of the EX and ID stage for the first ALU input
  logic EX_to_ID_haz_B;  // Detects a hazard between the begining of the EX and ID stage for the second ALU input
  logic MEM_to_ID_haz_A; // Detects a hazard between the begining of the MEM and ID stage for the first ALU input
  logic MEM_to_ID_haz_B; // Detects a hazard between the begining of the MEM and ID stage for the second ALU input
  logic MEM_to_MEM_haz;  // Detects a hazard between the begining and end of the MEM stage for the SW instruction
  ////////////////////////////////////////////////

  ///////////////////////////////////
  // Set the forwarding conditions //
  ///////////////////////////////////
  // Set the correct signals to enable/disable EX-to-ID/MEM-to-ID forwarding as applicable for the first input operand.
  assign ForwardA = (EX_to_ID_haz_A)  ? 2'b10 :
                    (MEM_to_ID_haz_A) ? 2'b01 :
                    2'b00;
  
  // Set the correct signals to enable/disable EX-to-ID/MEM-to-ID forwarding as applicable for the first input operand.
  assign ForwardB = (EX_to_ID_haz_B)  ? 2'b10 :
                    (MEM_to_ID_haz_B) ? 2'b01 :
                    2'b00;

  // Set the correct signals to enable/disable MEM-to-MEM forwarding for SW instruction.
  assign Forward_MEM = MEM_to_MEM_haz;
  ////////////////////////////////////

  /////////////////////////////
  // Determine EX-ID hazard  //
  /////////////////////////////
  // The first ALU input has an EX-to-ID hazard when the ID stage is trying to use the value in SrcReg1 (not $0) which 
  // is being written to by the instruction at the begining of the EX stage.
  assign EX_to_ID_haz_A = (ID_EX_RegWrite & (ID_EX_reg_rd != 4'h0)) & (ID_EX_reg_rd == SrcReg1);

  // The second ALU input has an EX-to-ID hazard when the ID stage is trying to use the value in SrcReg2 (not $0) which 
  // is being written to by the instruction at the begining of the EX stage.
  assign EX_to_ID_haz_B = (ID_EX_RegWrite & (ID_EX_reg_rd != 4'h0)) & (ID_EX_reg_rd == SrcReg2);
  //////////////////////////////

  /////////////////////////////
  // Determine MEM-ID hazard  //
  /////////////////////////////
  // The first ALU input has an MEM-to-ID hazard when the ID stage is trying to use the value in SrcReg1 (not $0) which 
  // is being written to by the instruction at the begining of the MEM stage. We disable this forwarding when
  // there is an EX-to-ID hazard on the same register as MEM-to-ID, in which case we forward the latest result.
  assign MEM_to_ID_haz_A = (EX_MEM_RegWrite & (EX_MEM_reg_rd != 4'h0)) & ~(EX_to_ID_haz_A) & (EX_MEM_reg_rd == SrcReg1);

  // The second ALU input has an MEM-to-ID hazard when the ID stage is trying to use the value in SrcReg2 (not $0) which 
  // is being written to by the instruction at the begining of the MEM stage. We disable this forwarding when
  // there is an EX-to-ID hazard on the same register as MEM-to-ID, in which case we forward the latest result.
  assign MEM_to_ID_haz_B = (EX_MEM_RegWrite & (EX_MEM_reg_rd != 4'h0)) & ~(EX_to_ID_haz_B) & (EX_MEM_reg_rd == SrcReg2);
  //////////////////////////////

  /////////////////////////
  // Determine SW hazard //
  /////////////////////////
  // We detect a MEM-to-MEM hazard when the instruction in the begining of the MEM stage is reading from a register (SrcReg2) (not $0) 
  // which is being written to by an instruction at the begining of the WB stage.
  assign MEM_to_MEM_haz = (MEM_WB_RegWrite & (MEM_WB_reg_rd != 4'h0)) & (MEM_WB_reg_rd == EX_MEM_SrcReg2);
  //////////////////////////////
                  
endmodule