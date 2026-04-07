//VALID FILE // (C) 2001-2025 Altera Corporation. All rights reserved.
// Your use of Altera Corporation's design tools, logic functions and other 
// software and tools, and its AMPP partner logic functions, and any output 
// files from any of the foregoing (including device programming or simulation 
// files), and any associated documentation or information are expressly subject 
// to the terms and conditions of the Altera Program License Subscription 
// Agreement, Altera IP License Agreement, or other applicable 
// license agreement, including, without limitation, that your use is for the 
// sole purpose of programming logic devices manufactured by Altera and sold by 
// Altera or its authorized distributors.  Please refer to the applicable 
// agreement for further details.



// synopsys translate_off
`timescale 1 ps / 1 ps
// synopsys translate_on
module Mic_Clk_Ctrl_altclkctrl_0 (
    ena,
    clkselect,
    inclk0x,
    inclk1x,
    inclk2x,
    inclk3x,
    outclk
);

  input ena;
  input [1:0] clkselect;
  input inclk0x;
  input inclk1x;
  input inclk2x;
  input inclk3x;
  output outclk;
`ifndef ALTERA_RESERVED_QIS
  // synopsys translate_off
`endif
  tri1       ena;
  tri0 [1:0] clkselect;
`ifndef ALTERA_RESERVED_QIS
  // synopsys translate_on
`endif

  wire sub_wire0;
  wire outclk;
  wire sub_wire1;
  wire [3:0] sub_wire2;
  wire sub_wire3;
  wire sub_wire4;
  wire sub_wire5;

  assign outclk = sub_wire0;
  assign sub_wire1 = inclk0x;
  assign sub_wire2[3:0] = {sub_wire5, sub_wire4, sub_wire3, sub_wire1};
  assign sub_wire3 = inclk1x;
  assign sub_wire4 = inclk2x;
  assign sub_wire5 = inclk3x;

  Mic_Clk_Ctrl_altclkctrl_0_sub Mic_Clk_Ctrl_altclkctrl_0_sub_component (
      .clkselect(clkselect),
      .ena(ena),
      .inclk(sub_wire2),
      .outclk(sub_wire0)
  );

endmodule
