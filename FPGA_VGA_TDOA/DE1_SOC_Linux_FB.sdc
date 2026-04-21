#************************************************************
# THIS IS A WIZARD-GENERATED FILE.                           
#
# Version 13.0.0 Build 156 04/24/2013 Service Pack 0.dp1 SJ Full Version
#
#************************************************************

# Copyright (C) 1991-2013 Altera Corporation
# Your use of Altera Corporation's design tools, logic functions 
# and other software and tools, and its AMPP partner logic 
# functions, and any output files from any of the foregoing 
# (including device programming or simulation files), and any 
# associated documentation or information are expressly subject 
# to the terms and conditions of the Altera Program License 
# Subscription Agreement, Altera MegaCore Function License 
# Agreement, or other applicable license agreement, including, 
# without limitation, that your use is for the sole purpose of 
# programming logic devices manufactured by Altera and sold by 
# Altera or its authorized distributors.  Please refer to the 
# applicable agreement for further details.



# Clock constraints

create_clock -name "clock_50_0" -period 20.000ns [get_ports {CLOCK_50}]
create_clock -name "clock_50_1" -period 20.000ns [get_ports {CLOCK2_50}]
create_clock -name "clock_50_2" -period 20.000ns [get_ports {CLOCK3_50}]
create_clock -name "clock_50_3" -period 20.000ns [get_ports {CLOCK4_50}]


# Automatically constrain PLL and other generated clocks
derive_pll_clocks -create_base_clocks

# Automatically calculate clock uncertainty to jitter and other effects.
derive_clock_uncertainty


create_clock -name "VGA_CLK" -period "65.0 MHz" [get_ports {VGA_CLK}]

set_output_delay -max -clock clk_vga 0.220 [get_ports VGA_R*]
set_output_delay -min -clock clk_vga -1.506 [get_ports VGA_R*]
set_output_delay -max -clock clk_vga 0.212 [get_ports VGA_G*]
set_output_delay -min -clock clk_vga -1.519 [get_ports VGA_G*]
set_output_delay -max -clock clk_vga 0.264 [get_ports VGA_B*]
set_output_delay -min -clock clk_vga -1.519 [get_ports VGA_B*]
set_output_delay -max -clock clk_vga 0.215 [get_ports VGA_BLANK]
set_output_delay -min -clock clk_vga -1.485 [get_ports VGA_BLANK]

set_false_path \
-from [get_registers {Audio_Front_End:iAUD_FRONT|Mic_Clk_Gen:iCLK_GEN|Mic_Mode_Fsm:iMIC_FSM|clk_en_o}] \
-to   [get_registers {Audio_Front_End:iAUD_FRONT|Mic_Clk_Gen:iCLK_GEN|Mic_Clk_Ctrl:iCLK_CTRL|*select_reg*}]

set_false_path \
-from [get_registers {Audio_Front_End:iAUD_FRONT|Mic_Clk_Gen:iCLK_GEN|Mic_Mode_Fsm:iMIC_FSM|pending_mode[0]}] \
-to   [get_registers {Audio_Front_End:iAUD_FRONT|Mic_Clk_Gen:iCLK_GEN|Mic_Clk_Ctrl:iCLK_CTRL|*select_reg*}]

set_false_path \
-from [get_registers {Audio_Front_End:iAUD_FRONT|Mic_Clk_Gen:iCLK_GEN|Mic_Mode_Fsm:iMIC_FSM|pending_mode[1]}] \
-to   [get_registers {Audio_Front_End:iAUD_FRONT|Mic_Clk_Gen:iCLK_GEN|Mic_Clk_Ctrl:iCLK_CTRL|*select_reg*}]

set_false_path \
-from [get_registers {Audio_Front_End:iAUD_FRONT|Mic_Clk_Gen:iCLK_GEN|Mic_Mode_Fsm:iMIC_FSM|clk_en_o}] \
-to   [get_registers {Audio_Front_End:iAUD_FRONT|Mic_Clk_Gen:iCLK_GEN|Mic_Clk_Ctrl:iCLK_CTRL|Mic_Clk_Ctrl_altclkctrl_0:altclkctrl_0|Mic_Clk_Ctrl_altclkctrl_0_sub:Mic_Clk_Ctrl_altclkctrl_0_sub_component|sd1~FF_0}]

set_false_path \
-from [get_registers {Audio_Front_End:iAUD_FRONT|Mic_Clk_Gen:iCLK_GEN|Mic_Mode_Fsm:iMIC_FSM|pending_mode[0]}] \
-to   [get_registers {Audio_Front_End:iAUD_FRONT|Mic_Clk_Gen:iCLK_GEN|Mic_Clk_Ctrl:iCLK_CTRL|Mic_Clk_Ctrl_altclkctrl_0:altclkctrl_0|Mic_Clk_Ctrl_altclkctrl_0_sub:Mic_Clk_Ctrl_altclkctrl_0_sub_component|sd1~FF_0}]

set_false_path \
-from [get_registers {Audio_Front_End:iAUD_FRONT|Mic_Clk_Gen:iCLK_GEN|Mic_Mode_Fsm:iMIC_FSM|pending_mode[1]}] \
-to   [get_registers {Audio_Front_End:iAUD_FRONT|Mic_Clk_Gen:iCLK_GEN|Mic_Clk_Ctrl:iCLK_CTRL|Mic_Clk_Ctrl_altclkctrl_0:altclkctrl_0|Mic_Clk_Ctrl_altclkctrl_0_sub:Mic_Clk_Ctrl_altclkctrl_0_sub_component|sd1~FF_0}]

set_false_path \
-from [get_registers {Audio_Front_End:iAUD_FRONT|Mic_Clk_Gen:iCLK_GEN|Mic_Clk_Ctrl:iCLK_CTRL|*select_reg*}] \
-to   [get_registers {Audio_Front_End:iAUD_FRONT|Mic_Clk_Gen:iCLK_GEN|Mic_Clk_Ctrl:iCLK_CTRL|*select_reg*}]

set_false_path \
-from [get_registers {Audio_Front_End:iAUD_FRONT|Mic_Clk_Gen:iCLK_GEN|Mic_Clk_Ctrl:iCLK_CTRL|Mic_Clk_Ctrl_altclkctrl_0:altclkctrl_0|Mic_Clk_Ctrl_altclkctrl_0_sub:Mic_Clk_Ctrl_altclkctrl_0_sub_component|sd1~FF_0}] \
-to   [get_registers {Audio_Front_End:iAUD_FRONT|Mic_Clk_Gen:iCLK_GEN|Mic_Clk_Ctrl:iCLK_CTRL|*select_reg*}]

set_false_path \
-from [get_registers {Audio_Front_End:iAUD_FRONT|Mic_Clk_Gen:iCLK_GEN|Mic_Clk_Ctrl:iCLK_CTRL|*select_reg*}] \
-to   [get_registers {Audio_Front_End:iAUD_FRONT|Mic_Clk_Gen:iCLK_GEN|Mic_Clk_Ctrl:iCLK_CTRL|Mic_Clk_Ctrl_altclkctrl_0:altclkctrl_0|Mic_Clk_Ctrl_altclkctrl_0_sub:Mic_Clk_Ctrl_altclkctrl_0_sub_component|sd1~FF_0}]

set_false_path \
-from [get_registers {Audio_Front_End:iAUD_FRONT|Mic_Clk_Gen:iCLK_GEN|Mic_Clk_Ctrl:iCLK_CTRL|Mic_Clk_Ctrl_altclkctrl_0:altclkctrl_0|Mic_Clk_Ctrl_altclkctrl_0_sub:Mic_Clk_Ctrl_altclkctrl_0_sub_component|sd1~FF_0}] \
-to   [get_registers {Audio_Front_End:iAUD_FRONT|Mic_Clk_Gen:iCLK_GEN|Mic_Clk_Ctrl:iCLK_CTRL|Mic_Clk_Ctrl_altclkctrl_0:altclkctrl_0|Mic_Clk_Ctrl_altclkctrl_0_sub:Mic_Clk_Ctrl_altclkctrl_0_sub_component|sd1~FF_0}]

# tsu/th constraints

# tco constraints

# tpd constraints

