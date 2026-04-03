`timescale 1ns / 1ps
// ------------------------------------------------------------
// Module: Mic_Clk_Gen
// Description: The Mic_Clk_Gen generates the microphone clock
//              for the audio front end. It integrates the PLL,
//              mode FSM, and clock-control logic to select and
//              enable the proper clock source based on the
//              requested operating mode. It also outputs a
//              stable mic clock when the microphone is ready.
// Author: Srivibhav Jonnalagadda
// Date: 03-23-2026
// ------------------------------------------------------------
module Mic_Clk_Gen #(
    parameter int unsigned SYS_CLK_HZ = 50_000_000,
    parameter bit FAST_SIM = 1'b0,
    parameter int unsigned FAST_SIM_DIV = 1
) (
    input logic clk_i,
    input logic rst_i,
    input logic volt_on_i,
    input logic [2:0] mode_req_i,

    output logic data_val_o,
    output logic [1:0] curr_mode_o,
    output logic mic_clk_o
);

  /////////////////////////////////////////////////
  // Declare any internal signals as type logic //
  ///////////////////////////////////////////////
  logic clk_std, clk_ult;
  logic clk_en, pll_locked, clk_ctrl_en;
  logic [1:0] clk_sel;
  ///////////////////////////////////////////////

  //////////////////////////
  // Submodule instances //
  ////////////////////////
  // Instantiate the FSM to control b/w transitions.
  Mic_Mode_Fsm #(
      .SYS_CLK_HZ(SYS_CLK_HZ),
      .FAST_SIM(FAST_SIM),
      .FAST_SIM_DIV(FAST_SIM_DIV)
  ) iMIC_FSM (
      .clk_i(clk_i),
      .rst_i(rst_i),
      .volt_on_i(volt_on_i),
      .mode_req_i(mode_req_i),
      .pll_locked_i(pll_locked),

      .clk_en_o (clk_en),
      .clk_sel_o(clk_sel),

      .curr_mode_o(curr_mode_o),
      .data_val_o (data_val_o)
  );

  // Instantiate the PLL that generates the clocks.
  Mic_Clk_Pll iPLL (
      .refclk(clk_i),
      .rst(rst_i),

      .outclk_0(clk_std),
      .outclk_1(clk_ult),
      .locked  (pll_locked)
  );

  // Enable condition for the output clock.
  assign clk_ctrl_en = clk_en & pll_locked;

  // Instantiate clock mux.
  Mic_Clk_Ctrl iCLK_CTRL (
      .inclk0x  (clk_i),
      .inclk1x  (clk_i),
      .inclk2x  (clk_std),
      .inclk3x  (clk_ult),
      .clkselect(clk_sel),
      .ena      (clk_ctrl_en),

      .outclk(mic_clk_o)
  );

endmodule
