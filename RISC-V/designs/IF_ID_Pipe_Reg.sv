// ------------------------------------------------------------
// Module: IF_ID_Pipe_Reg
// Description: Pipeline register between the Instruction Fetch
//              (IF) and Instruction Decode (ID) stages.
//
//              Stores the fetched instruction, PC values, and
//              branch prediction metadata. Supports pipeline
//              stall and flush control to maintain correct
//              instruction flow.
// Author: Srivibhav Jonnalagadda
// Date: 03-07-2026
// ------------------------------------------------------------
import Core_Cfg_pkg::*;

module IF_ID_Pipe_Reg (
    input logic clk_i,                      // System clock
    input logic rst_i,                      // Active high synchronous reset
    input logic stall_i,                    // Stall signal (prevents updates)
    input logic flush_i,                    // Flush pipeline register (clears the instruction word)
    input addr_t PC_curr_i,                 // Current PC from the fetch stage
    input addr_t PC_next_i,                 // Next PC from the fetch stage
    input inst_t PC_inst_i,                 // Current instruction word from the fetch stage
    input logic [1:0]  prediction_i,        // 2-bit prediction from the fetch stage
    input addr_t predicted_target_i,        // Predicted target from the BTB

    output addr_t IF_ID_PC_curr_o,                // Pipelined current instruction address passed to the decode stage
    output addr_t IF_ID_PC_next_o,                // Pipelined next PC passed to the decode stage
    output inst_t IF_ID_PC_inst_o,                // Pipelined current instruction word passed to the decode stage
    output logic [1:0]  IF_ID_prediction_o,       // Pipelined 2-bit branch prediction signal passed to the decode stage
    output addr_t IF_ID_predicted_target_o        // Pipelined predicted target passed to the decode stage
  );

  ///////////////////////////////////////////////
  // Declare any internal signals as type logic//
  ///////////////////////////////////////////////
  logic wen; // Register write enable signal.
  logic clr; // Clear signal for instruction word register
  ///////////////////////////////////////////////

  ///////////////////////////////////////
  // Model the IF/ID Pipeline Register //
  ///////////////////////////////////////
  // We write to the register whenever we don't stall.
  assign wen = ~stall_i;
 
  // We clear the instruction word register whenever we flush or during rst.
  assign clr = flush_i | rst_i;

  // Infer register for storing the current instruction's address.
  always_ff @(posedge clk_i)
    if (rst_i)
      IF_ID_PC_curr_o <= '0;
    else if (wen)
      IF_ID_PC_curr_o <= PC_curr_i;
  
  // Infer register for storing the next instruction's address.
  always_ff @(posedge clk_i)
    if (rst_i)
      IF_ID_PC_next_o <= '0;
    else if (wen)
      IF_ID_PC_next_o <= PC_next_i;
  
  // Infer register for storing the fetched instruction word (clear the instruction on flush).
  always_ff @(posedge clk_i)
    if (clr)
      IF_ID_PC_inst_o <= '0;
    else if (wen)
      IF_ID_PC_inst_o <= PC_inst_i;
  
  // Infer register for storing the predicted branch taken signal (clear the signal on flush).
  always_ff @(posedge clk_i)
    if (clr)
      IF_ID_prediction_o <= '0;
    else if (wen)
      IF_ID_prediction_o <= prediction_i;
  
  // Infer register for storing the predicted target address (clear the data on flush).
  always_ff @(posedge clk_i)
    if (clr)
      IF_ID_predicted_target_o <= '0;
    else if (wen)
      IF_ID_predicted_target_o <= predicted_target_i;
  /////////////////////////////////////////////////////////////////////////////

endmodule
