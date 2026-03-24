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
module Mic_Clk_Gen (
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
  logic [1:0] clk_sel;
  logic clk_en, pll_locked, clk_ctrl_en;

  //////////////////////////
  // Submodule instances //
  ////////////////////////
  // Instantiate the FSM to control b/w transitions.
  Mic_Mode_Fsm iMIC_FSM (
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

  // Instantiate the PLL that generates all 4 clocks.
  Mic_Clk_Pll iPLL (
      .refclk(clk_i),
      .rst(rst_i),

      .outclk_1(clk_sleep),
      .outclk_3(clk_low_pwr),
      .outclk_4(clk_std),
      .outclk_5(clk_ult),
      .locked  (pll_locked)
  );

  // Enable condition for the output clock.
  assign clk_ctrl_en = clk_en & pll_locked;

  // Instantaiate the clk_ctrl block to choose one out of four clocks.
  Mic_Clk_Ctrl iCLK_CTRL (
      .inclk0x(clk_sleep),
      .inclk1x(clk_low_pwr),
      .inclk2x(clk_std),
      .inclk3x(clk_ultra),
      .clkselect(clk_sel),
      .ena(clk_ctrl_en),

      .outclk(mic_clk_o)
  );
endmodule
