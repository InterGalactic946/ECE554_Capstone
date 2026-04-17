`timescale 1ns / 1ps
// ------------------------------------------------------------
// Module: mock_data
// Description: Generates deterministic PCM test samples for
//              validating the DMA and software ingest path.
//              Each asserted step pulse increments the sample
//              counter and marks the corresponding output word
//              as valid for one cycle.
// Author: ECE554 Capstone Team
// Date: 04-16-2026
// ------------------------------------------------------------
module mock_data (
    input logic clk_i,
    input logic rst_n_i,
    input logic step_i,
    output logic [15:0] data_o,
    output logic data_valid_o
);

  /////////////////////////////////////////////////
  // Declare any internal signals as type logic //
  ///////////////////////////////////////////////
  logic [15:0] data_counter;
  ///////////////////////////////////////////////

  // Drive the current counter value as the synthetic PCM sample.
  assign data_o = data_counter;

  // Advance the sample stream once per requested test step.
  always_ff @(posedge clk_i, negedge rst_n_i) begin
    if (!rst_n_i) begin
      data_counter <= '0;
    end else if (step_i) begin
      data_counter <= data_counter + 1'b1;
    end
  end

  // Mark the generated sample valid on the same cycle as the step pulse.
  always_ff @(posedge clk_i, negedge rst_n_i) begin
    if (!rst_n_i) begin
      data_valid_o <= 1'b0;
    end else begin
      data_valid_o <= step_i;
    end
  end

endmodule
