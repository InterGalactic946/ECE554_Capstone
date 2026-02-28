/////////////////////////////////////////////////////////////
// Execute_model.sv: Model Instruction Execute Stage       //
//                                                         //
// This module implements the execution stage of the       //
// pipeline for the model CPU.                             //
/////////////////////////////////////////////////////////////
module Execute (
    input logic clk,                   // System clock
    input logic rst,                   // Active high synchronous reset
    input logic [15:0] ALU_In1,        // First input to ALU (from the decode stage)
    input logic [15:0] ALU_imm,        // Immediate for I-type ALU instructions (from the decode stage)
    input logic [15:0] ALU_In2_step,   // Second ALU input based on the instruction type (from the decode stage)
    input logic [3:0] ALUOp,           // ALU operation code (from the decode stage)
    input logic ALUSrc,                // Selects second ALU input (immediate or SrcReg2_data) based on instruction type (from the decode stage)
    input logic Z_en,                  // Enable signal for Z flag
    input logic NV_en,                 // Enable signal for N and V flags
    
    output logic [2:0] flags,          // Flags output: {ZF, VF, NF}
    output logic [15:0] ALU_out        // ALU operation result output
);

  ////////////////////////////////////////////////
  // Declare any internal signals as type wire  //
  ////////////////////////////////////////////////
  logic ZF, VF, NF;           // flag signals for zero, overflow, and negative
  logic Z_set, V_set, N_set;  // flag set signals by the ALU
  logic [15:0] ALU_In2;       // Second ALU input based on the instruction type
  ////////////////////////////////////////////////

  /////////////////////////////////////////////
  // EXECUTE instruction based on the opcode //
  /////////////////////////////////////////////
  // Determine the 2nd ALU input, either immediate or ALU_In2_step if non I-type instruction.
  assign ALU_In2 = (ALUSrc) ? ALU_imm : ALU_In2_step;

  // Execute the instruction on the ALU based on the opcode.
  ALU iALU (.ALU_In1(ALU_In1),
            .ALU_In2(ALU_In2),
            .Opcode(ALUOp),
                        
            .ALU_Out(ALU_out),
            .Z_set(Z_set),
            .N_set(N_set),
            .V_set(V_set)
          );
  /////////////////////////////////////////////

  ////////////////////////////////////////////////////
  // Set FLAGS based on the output of the execution //
  ////////////////////////////////////////////////////
  always_ff @(posedge clk)
    if (rst)
      ZF <= 1'b0;
    else if (Z_en)
      ZF <= Z_set;
  
  always_ff @(posedge clk) begin
    if (rst) begin
      VF <= 1'b0;
      NF <= 1'b0;
    end else if (NV_en) begin
      VF <= V_set;
      NF <= N_set;
    end
  end
  
  // Set the flags based on the enable signals and the set signals from the ALU.
  assign flags = (Z_en & NV_en) ? {Z_set, V_set, N_set} : 
                  (Z_en) ? {Z_set, VF, NF} :
                  {ZF, VF, NF};
  ////////////////////////////////////////////////////

endmodule