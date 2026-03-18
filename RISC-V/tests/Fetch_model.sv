// ------------------------------------------------------------
// Module: Fetch_model
// Description: This module models the fetch stage of the CPU.
// Author: Srivibhav Jonnalagadda
// Date: 03-13-2026
// ------------------------------------------------------------
import Core_Cfg_pkg::*;

module Fetch_model (
    input logic clk_i,                      // System clock
    input logic rst_i,                      // Active high synchronous reset
    input logic stall_i,                    // Stall signal for the PC (from the hazard detection unit)
    input logic actual_taken_i,             // Signal used to determine whether branch instruction met condition codes
    input logic wen_BHT_i,                  // Write enable for BHT (Branch History Table)
    input addr_t branch_target_i,           // Branch target address
    input logic wen_BTB_i,                  // Write enable for BTB (Branch Target Buffer)
    input addr_t actual_target_i,           // Actual target address
    input logic update_PC_i,                // Signal to update the PC with the actual target
    input addr_t IF_ID_PC_curr_i,           // Pipelined previous PC value (from the fetch stage)
    input logic [1:0] IF_ID_prediction_i,   // The predicted value of the previous branch instruction

    output addr_t PC_next_o,                // Computed next PC value
    output addr_t PC_curr_o,                // Current PC value
    output logic [1:0] prediction_o,        // The 2-bit predicted value of the current branch instruction
    output addr_t predicted_target_o        // The predicted target from the BTB.
);

  /////////////////////////////////////////////////
  // Declare any internal signals as type wire  //
  ///////////////////////////////////////////////
  logic predicted_taken;      // The predicted value of the current instruction.
  logic enable;               // Enables the reads/writes for PC, instruction memory, and BHT, BTB.
  addr_t PC_target;           // The target address of the branch instruction from the BTB or the next PC.
  addr_t PC_update;           // The address to update the PC with.
  ////////////////////////////////////////////////

  ///////////////////////////
  // Model the Fetch stage //
  ///////////////////////////
  // We write to the PC whenever we don't stall on decode.
  assign enable = ~stall_i;

  // Get the branch instruction address from the BTB, if predicted to be taken, else it is PC + 4.
  assign PC_target = (predicted_taken) ? predicted_target_o : PC_next_o;

  // Update the PC with correct target on misprediction or the target PC otherwise.
  assign PC_update = (update_PC_i) ? actual_target_i : PC_target;

  // Instantiate the Dynamic Branch Predictor model.
  Dynamic_Branch_Predictor_model iDBP_model (
    .clk_i(clk_i),
    .rst_i(rst_i),
    .PC_curr_i(PC_curr_o),
    .IF_ID_PC_curr_i(IF_ID_PC_curr_i),
    .IF_ID_prediction_i(IF_ID_prediction_i),
    .enable_i(enable),
    .wen_BTB_i(wen_BTB_i),
    .wen_BHT_i(wen_BHT_i),
    .actual_taken_i(actual_taken_i),
    .actual_target_i(branch_target_i),

    .predicted_taken_o(predicted_taken),
    .prediction_o(prediction_o),
    .predicted_target_o(predicted_target_o)
  );

  // Model the PC register.
  always_ff @(posedge clk_i)
    if (rst_i)
      PC_curr_o <= '0;
    else if (enable)
      PC_curr_o <= PC_update;

  // Compute PC_new as the next instruction address.
  assign PC_next_o = PC_curr_o + ILEN_BYTES;
  //////////////////////////////////////

endmodule
