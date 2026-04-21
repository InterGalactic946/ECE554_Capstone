`timescale 1ns / 1ps
// ------------------------------------------------------------
// Module: Audio_Front_End
// Description: Generates the microphone clock by integrating
//              the ADC to meausre the microphone voltage, and
//              the clock generator to control the clock
//              source selection based on the requested
//              operating mode.
// Author: Srivibhav Jonnalagadda
// Date: 04-06-2026
// ------------------------------------------------------------
module Audio_Front_End #(
    parameter int unsigned SYS_CLK_HZ = 50_000_000,
    parameter bit FAST_SIM = 1'b0,
    parameter int unsigned FAST_SIM_DIV = 1
) (
    input logic clk_i,
    input logic rst_i,
    input logic [1:0] mode_req_i,

    // ADC interface
    input  logic ADC_data_out_i,
    output logic ADC_CS_o,
    output logic ADC_SCLK_o,
    output logic ADC_data_in_o,

    output logic data_val_o,
    output logic [1:0] curr_mode_o,
    output logic mic_clk_o
);

  // Assuming a 5V ref voltage with 12-bit ADC.
  localparam logic [11:0] VOLT_LOWER_THRESH = 12'd1320;  // ~1.611V
  localparam logic [11:0] VOLT_UPPER_THRESH = 12'd1330;  // ~1.624V

  /////////////////////////////////////////////////
  // Declare any internal signals as type logic //
  ///////////////////////////////////////////////
  logic volt_on;
  logic [11:0] volt_lvl;
  ///////////////////////////////////////////////

  //////////////////////////
  // Submodule instances //
  ////////////////////////
  // Instantiate ADC Controller.
  ADC_Controller iADC_CTRL (
      .CLOCK(clk_i),
      .RESET(rst_i),
      .ADC_SCLK(ADC_SCLK_o),
      .ADC_CS_N(ADC_CS_o),
      .ADC_DOUT(ADC_data_out_i),
      .ADC_DIN(ADC_data_in_o),
      .CH0(volt_lvl)
  );

  // Latch when voltage is on and off to prevent glitches in the clock output.
  always_ff @(posedge clk_i) begin
    if (rst_i) volt_on <= 1'b0;
    else if (volt_lvl < VOLT_LOWER_THRESH)  // Turn off slightly below 1.62V
      volt_on <= 1'b0;
    else if (volt_lvl > VOLT_UPPER_THRESH)  // Turn on slightly above 1.62V
      volt_on <= 1'b1;
  end

  // Instantiate Clock Generator.
  Mic_Clk_Gen #(
      .SYS_CLK_HZ(SYS_CLK_HZ),
      .FAST_SIM(FAST_SIM),
      .FAST_SIM_DIV(FAST_SIM_DIV)
  ) iCLK_GEN (
      .clk_i(clk_i),
      .rst_i(rst_i),
      .volt_on_i(volt_on),
      .mode_req_i(mode_req_i),

      .data_val_o (data_val_o),
      .curr_mode_o(curr_mode_o),
      .mic_clk_o  (mic_clk_o)
  );

endmodule
