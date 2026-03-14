// ------------------------------------------------------------
// Module: Dynamic_Branch_Predictor_model
// Description: This module models the dynamic branch predictor
//              of the CPU.
// Author: Srivibhav Jonnalagadda
// Date: 03-07-2026
// ------------------------------------------------------------
import Monitor_tasks::*;
import Core_Cfg_pkg::*;

module Dynamic_Branch_Predictor_model (
    input logic clk_i,                     // System clock
    input logic rst_i,                     // Active high reset signal
    input addr_t PC_curr_i,                // Current PC address
    input addr_t IF_ID_PC_curr_i,          // Pipelined previous PC address
    input logic [1:0] IF_ID_prediction_i,  // The predicted value of the previous branch inst.
    input logic enable_i,                  // Enable signal for the DynamicBranchPredictor
    input logic wen_BTB_i,                 // Write enable for BTB (Branch Target Buffer) (from the decode stage)
    input logic wen_BHT_i,                 // Write enable for BHT (Branch History Table) (from the decode stage)
    input logic actual_taken_i,            // Actual branch taken value (from the decode stage)
    input addr_t actual_target_i,          // Actual target address for the branch (from the decode stage)

    output logic predicted_taken_o,        // Indicates if the branch is predicted taken (1) or not (0)
    output logic [1:0] prediction_o,       // 2-bit Predicted branch signal (from BHT)
    output addr_t predicted_target_o       // Predicted target address (from BTB)
);

  /////////////////////////////////////////////////
  // Declare any internal signals as type wire  //
  ///////////////////////////////////////////////
  logic [1:0] prediction_rd;  // The prediction read out as it is from the memory.
  state_t prev_prediction;  // Holds the previous prediction.
  state_t updated_prediction;     // The new prediction to be stored in the BHT on an incorrect prediction.
  logic updated_valid;  // The updated valid bit for the branch.
  logic valid;  // Indicates that the valid bit is set.
  logic [DBP_TAG_W-1:0] read_tag;  // The tag used for the current instruction as a read.
  logic [DBP_TAG_W-1:0] write_tag;  // The tag used for the previous instruction as a write.
  logic read_tags_match;          // Used to determine if the current PC tag matches the previous PC tag cached in BHT.
  logic write_tags_match;         // Used to determine if the current IF_ID_PC tag matches the previous PC tag cached in BHT.
  logic error;  // Error flag raised when prediction state is invalid.
  model_BHT_t BHT[BHT_ENTRIES];  // Declare BHT: {tag, prediction[1:0], valid}
  model_BTB_t BTB[BTB_ENTRIES];  // Declare BTB
  ////////////////////////////////////////////////

  ////////////////////////////////////////
  // Model the Dynamic Branch Predictor //
  ////////////////////////////////////////
  // Model the BTB/BHT memory.
  always_ff @(posedge clk_i) begin
    if (rst_i) begin
      // Initialize BHT: PC_addr = 'x, prediction = WEAK_NOT_TAKEN, valid = 0
      BHT <= '{default: '{PC_addr: 'x, prediction: WEAK_NOT_TAKEN, valid: 1'b0}};
      // Initialize BTB: PC_addr = 'x, target = '0
      BTB <= '{default: '{PC_addr: 'x, target: '0}};
    end else begin
      // Update BHT entry if needed (for example, on a misprediction)
      if (enable_i && wen_BHT_i) begin
        BHT[IF_ID_PC_curr_i[BHT_IDX_MSB:BHT_IDX_LSB]].PC_addr <= IF_ID_PC_curr_i;  // Store the PC address
        BHT[IF_ID_PC_curr_i[BHT_IDX_MSB:BHT_IDX_LSB]].prediction <= updated_prediction; // Store the 2-bit prediction along with the tag
        BHT[IF_ID_PC_curr_i[BHT_IDX_MSB:BHT_IDX_LSB]].valid <= updated_valid;  // Store the updated valid bit
      end

      // Update BTB entry if needed (when a branch is taken)
      if (enable_i && wen_BTB_i) begin
        BTB[IF_ID_PC_curr_i[BTB_IDX_MSB:BTB_IDX_LSB]].PC_addr <= IF_ID_PC_curr_i;  // Store the PC address
        BTB[IF_ID_PC_curr_i[BTB_IDX_MSB:BTB_IDX_LSB]].target <= actual_target_i;  // Store the target address
      end
    end
  end

  // Get the valid bit of the branch.
  assign valid = (enable_i) ? BHT[PC_curr_i[BHT_IDX_MSB:BHT_IDX_LSB]].valid : 1'b0;

  // Asynchronously read out the prediction when enabled.
  assign prediction_rd = (enable_i) ? BHT[PC_curr_i[BHT_IDX_MSB:BHT_IDX_LSB]].prediction : 2'h0;

  // Read out the tag stored in the memory when enabled for a read.
  assign read_tag = (enable_i) ? BHT[PC_curr_i[BHT_IDX_MSB:BHT_IDX_LSB]].PC_addr[XLEN-1:(BHT_IDX_MSB+1)] : '0;

  // Compare the tags of the current PC and previous PC address in the cache to determine if they match.
  assign read_tags_match = (PC_curr_i[XLEN-1:(BHT_IDX_MSB+1)] === read_tag);

  // If the read tags match and it is valid, use the prediction read out, else assume weakly not taken.
  assign prediction_o = (read_tags_match && valid) ? prediction_rd : 2'b01;

  // Take the taken flag as the MSB of the prediction.
  assign predicted_taken_o = prediction_o[1];

  // Asynchronously read out the target when enabled.
  assign predicted_target_o = (enable_i) ? BTB[PC_curr_i[BTB_IDX_MSB:BTB_IDX_LSB]].target : '0;
  //////////////////////////////////////////

  /////////////////////////////////
  // Model the prediction states //
  /////////////////////////////////
  // Cast the incoming previous prediction as of state type.
  assign prev_prediction = state_t'(IF_ID_prediction_i);

  // Read out the tag stored in the memory when enabled for a write.
  assign write_tag = (enable_i) ? BHT[IF_ID_PC_curr_i[BHT_IDX_MSB:BHT_IDX_LSB]].PC_addr[XLEN-1:(BHT_IDX_MSB+1)] 
                                : '0;

  // Check if the write tags match for the current IF_ID_PC and the previous PC address in the cache.
  assign write_tags_match = (IF_ID_PC_curr_i[XLEN-1:(BHT_IDX_MSB+1)] == write_tag);

  always_comb begin
    error = 1'b0;  // Default error state.
    updated_prediction = STRONG_NOT_TAKEN;  // Default predict not taken.
    updated_valid = 1'b0;  // Default assume invalid.
    case (prev_prediction)  // Update the new prediction based on the previous prediction.
      STRONG_NOT_TAKEN: begin
        updated_valid = 1'b1;  // Set the valid bit as it is a valid branch instruction
        if (write_tags_match) begin  // If the tags match, update the prediction.
          updated_prediction = (actual_taken_i) ? WEAK_NOT_TAKEN : STRONG_NOT_TAKEN;
        end else begin  // If the tags do not match, assume not taken.
          updated_prediction = WEAK_NOT_TAKEN;  // Default predict weak not taken.
        end
      end
      WEAK_NOT_TAKEN: begin // Default state
        updated_valid = 1'b1;  // Set the valid bit as it is a valid branch instruction
        updated_prediction = (actual_taken_i) ? WEAK_TAKEN : STRONG_NOT_TAKEN;
      end
      WEAK_TAKEN: begin
        updated_valid = 1'b1;  // Set the valid bit as it is a valid branch instruction
        if (write_tags_match) begin  // If the tags match, update the prediction.
          updated_prediction = (actual_taken_i) ? STRONG_TAKEN : WEAK_NOT_TAKEN;
        end else begin  // If the tags do not match, assume not taken.
          updated_prediction = WEAK_NOT_TAKEN;  // Default predict weak not taken.
        end

      end
      STRONG_TAKEN: begin
        updated_valid = 1'b1;  // Set the valid bit as it is a valid branch instruction
        if (write_tags_match) begin  // If the tags match, update the prediction.
          updated_prediction = (actual_taken_i) ? STRONG_TAKEN : WEAK_TAKEN;
        end else begin  // If the tags do not match, assume not taken.
          updated_prediction = WEAK_NOT_TAKEN;  // Default predict weak not taken.
        end
      end
      default: begin
        updated_valid = 1'b0;  // Default assume invalid.
        updated_prediction = STRONG_NOT_TAKEN;  // Default predict not taken.
        error = 1'b1;  // Invalid prediction state.
      end
    endcase
  end
  ///////////////////////////////////

endmodule
