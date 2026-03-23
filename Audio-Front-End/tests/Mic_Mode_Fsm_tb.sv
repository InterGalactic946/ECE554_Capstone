// ------------------------------------------------------------
// Testbench: Mic_Mode_Fsm_tb
// Description: Verifies Mic_Mode_Fsm behavior.
// Author: sjonnalagad2
// Date: 03-21-2026
// ------------------------------------------------------------
module Mic_Mode_Fsm_tb();

  int error_count;

  /////////////////////////////
  // Stimulus of type logic //
  ///////////////////////////
  logic clk_i;
  logic rst_i;
  logic volt_on_i;
  logic [1:0] mode_req_i;
  logic pll_locked_i;
  logic clk_en_o;
  logic [1:0] clk_sel_o;
  logic [1:0] curr_mode_o;
  logic data_val_o;

  //////////////////////
  // Instantiate DUT //
  ////////////////////
  Mic_Mode_Fsm iDUT (
    .clk_i(clk_i),
    .rst_i(rst_i),
    .volt_on_i(volt_on_i),
    .mode_req_i(mode_req_i),
    .pll_locked_i(pll_locked_i),
    .clk_en_o(clk_en_o),
    .clk_sel_o(clk_sel_o),
    .curr_mode_o(curr_mode_o),
    .data_val_o(data_val_o)
  );

  initial begin
    error_count = 0;
    // TODO: Initialize inputs.
    // TODO: Apply stimulus and checks.

    if (error_count == 0) begin
      $display("YAHOO!! All tests passed.");
    end else begin
      $display("ERROR: %0d test(s) failed.", error_count);
    end

    $stop();
  end

  ////////////////////////////////////////////////////
  // Optional clock generation for synchronous DUT //
  //////////////////////////////////////////////////
  // always
  //   #5 clk = ~clk;

endmodule
