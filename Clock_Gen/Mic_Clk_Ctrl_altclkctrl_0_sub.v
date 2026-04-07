//altclkctrl CBX_SINGLE_OUTPUT_FILE="ON" CLOCK_TYPE="Global Clock" DEVICE_FAMILY="Cyclone V" ENA_REGISTER_MODE="double register" USE_GLITCH_FREE_SWITCH_OVER_IMPLEMENTATION="ON" clkselect ena inclk outclk
//VERSION_BEGIN 25.1 cbx_altclkbuf 2025:10:22:10:31:27:SC cbx_cycloneii 2025:10:22:10:31:27:SC cbx_lpm_add_sub 2025:10:22:10:31:27:SC cbx_lpm_compare 2025:10:22:10:31:27:SC cbx_lpm_decode 2025:10:22:10:31:27:SC cbx_lpm_mux 2025:10:22:10:31:26:SC cbx_mgl 2025:10:22:10:31:44:SC cbx_nadder 2025:10:22:10:31:27:SC cbx_stratix 2025:10:22:10:31:27:SC cbx_stratixii 2025:10:22:10:31:26:SC cbx_stratixiii 2025:10:22:10:31:27:SC cbx_stratixv 2025:10:22:10:31:26:SC  VERSION_END
// synthesis VERILOG_INPUT_VERSION VERILOG_2001
// altera message_off 10463



// Copyright (C) 2025  Altera Corporation. All rights reserved.
//  Your use of Altera Corporation's design tools, logic functions 
//  and other software and tools, and any partner logic 
//  functions, and any output files from any of the foregoing 
//  (including device programming or simulation files), and any 
//  associated documentation or information are expressly subject 
//  to the terms and conditions of the Altera Program License 
//  Subscription Agreement, the Altera Quartus Prime License Agreement,
//  the Altera IP License Agreement, or other applicable license
//  agreement, including, without limitation, that your use is for
//  the sole purpose of programming logic devices manufactured by
//  Altera and sold by Altera or its authorized distributors.  Please
//  refer to the Altera Software License Subscription Agreements 
//  on the Quartus Prime software download page.



//synthesis_resources = cyclonev_clkena 1 reg 2 
//synopsys translate_off
`timescale 1 ps / 1 ps
//synopsys translate_on
module Mic_Clk_Ctrl_altclkctrl_0_sub (
    clkselect,
    ena,
    inclk,
    outclk
)  /* synthesis synthesis_clearbox=1 */;
  input [1:0] clkselect;
  input ena;
  input [3:0] inclk;
  output outclk;
`ifndef ALTERA_RESERVED_QIS
  // synopsys translate_off
`endif
  tri0 [1:0] clkselect;
  tri1 ena;
  tri0 [3:0] inclk;
`ifndef ALTERA_RESERVED_QIS
  // synopsys translate_on
`endif	(* ALTERA_ATTRIBUTE = {"POWER_UP_LEVEL=LOW"} *)
  reg [1:0] select_reg;
  wire wire_sd2_outclk;
  wire wire_sd1_enaout;
  wire wire_sd1_outclk;
  wire [1:0] clkselect_wire;
  wire [3:0] inclk_wire;
  wire [1:0] select_enable_wire;

  // synopsys translate_off
  initial select_reg = 0;
  // synopsys translate_on
  always @(posedge wire_sd2_outclk) if (wire_sd1_enaout == 1'b0) select_reg <= clkselect_wire[1:0];
  cyclonev_clkselect sd2 (
      .clkselect({select_reg}),
      .inclk(inclk_wire),
      .outclk(wire_sd2_outclk)
  );
  cyclonev_clkena sd1 (
      .ena((ena & (~select_enable_wire[1]))),
      .enaout(wire_sd1_enaout),
      .inclk(wire_sd2_outclk),
      .outclk(wire_sd1_outclk)
  );
  defparam sd1.clock_type = "Global Clock", sd1.ena_register_mode = "double register",
      sd1.lpm_type = "cyclonev_clkena";
  assign clkselect_wire = {
    clkselect
  },
  inclk_wire = {
    inclk
  },
  outclk = wire_sd1_outclk,
  select_enable_wire = {
    (select_enable_wire[0] | (clkselect_wire[1] ^ select_reg[1])),
    (clkselect_wire[0] ^ select_reg[0])
  };
endmodule  //Mic_Clk_Ctrl_altclkctrl_0_sub
