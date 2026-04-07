#**************************************************************
# This .sdc file is created by Terasic Tool.
# Users are recommended to modify this file to match users logic.
#**************************************************************

#**************************************************************
# Create Clock
#**************************************************************
create_clock -period 20.000ns [get_ports CLOCK2_50]
create_clock -period 20.000ns [get_ports CLOCK3_50]
create_clock -period 20.000ns [get_ports CLOCK4_50]
create_clock -period 20.000ns [get_ports CLOCK_50]

# for enhancing USB BlasterII to be reliable, 25MHz
create_clock -name {altera_reserved_tck} -period 40 {altera_reserved_tck}
set_input_delay -clock altera_reserved_tck -clock_fall 3 [get_ports altera_reserved_tdi]
set_input_delay -clock altera_reserved_tck -clock_fall 3 [get_ports altera_reserved_tms]
set_output_delay -clock altera_reserved_tck 3 [get_ports altera_reserved_tdo]

#**************************************************************
# Create Generated Clock
#**************************************************************
derive_pll_clocks



#**************************************************************
# Set Clock Latency
#**************************************************************



#**************************************************************
# Set Clock Uncertainty
#**************************************************************
derive_clock_uncertainty



#**************************************************************
# Set Input Delay
#**************************************************************



#**************************************************************
# Set Output Delay
#**************************************************************



#**************************************************************
# Set Clock Groups
#**************************************************************



#**************************************************************
# Set False Path
#**************************************************************
# False-path clock-control signals from Mic_Mode_Fsm into altclkctrl internal
# control flops. These are control/protocol paths, not ordinary synchronous
# datapaths. The FSM enforces safe sequencing: CLK_DIS -> CLK_SEL -> CLK_EN -> WAIT.

set_false_path \
-from [get_registers {Mic_Clk_Gen:iCLK_GEN|Mic_Mode_Fsm:iMIC_FSM|clk_en_o}] \
-to   [get_registers {Mic_Clk_Gen:iCLK_GEN|Mic_Clk_Ctrl:iCLK_CTRL|*select_reg*}]

set_false_path \
-from [get_registers {Mic_Clk_Gen:iCLK_GEN|Mic_Mode_Fsm:iMIC_FSM|pending_mode[0]}] \
-to   [get_registers {Mic_Clk_Gen:iCLK_GEN|Mic_Clk_Ctrl:iCLK_CTRL|*select_reg*}]

set_false_path \
-from [get_registers {Mic_Clk_Gen:iCLK_GEN|Mic_Mode_Fsm:iMIC_FSM|pending_mode[1]}] \
-to   [get_registers {Mic_Clk_Gen:iCLK_GEN|Mic_Clk_Ctrl:iCLK_CTRL|*select_reg*}]

set_false_path \
-from [get_registers {Mic_Clk_Gen:iCLK_GEN|Mic_Mode_Fsm:iMIC_FSM|clk_en_o}] \
-to   [get_registers {Mic_Clk_Gen:iCLK_GEN|Mic_Clk_Ctrl:iCLK_CTRL|Mic_Clk_Ctrl_altclkctrl_0:altclkctrl_0|Mic_Clk_Ctrl_altclkctrl_0_sub:Mic_Clk_Ctrl_altclkctrl_0_sub_component|sd1~FF_0}]

set_false_path \
-from [get_registers {Mic_Clk_Gen:iCLK_GEN|Mic_Mode_Fsm:iMIC_FSM|pending_mode[0]}] \
-to   [get_registers {Mic_Clk_Gen:iCLK_GEN|Mic_Clk_Ctrl:iCLK_CTRL|Mic_Clk_Ctrl_altclkctrl_0:altclkctrl_0|Mic_Clk_Ctrl_altclkctrl_0_sub:Mic_Clk_Ctrl_altclkctrl_0_sub_component|sd1~FF_0}]

set_false_path \
-from [get_registers {Mic_Clk_Gen:iCLK_GEN|Mic_Mode_Fsm:iMIC_FSM|pending_mode[1]}] \
-to   [get_registers {Mic_Clk_Gen:iCLK_GEN|Mic_Clk_Ctrl:iCLK_CTRL|Mic_Clk_Ctrl_altclkctrl_0:altclkctrl_0|Mic_Clk_Ctrl_altclkctrl_0_sub:Mic_Clk_Ctrl_altclkctrl_0_sub_component|sd1~FF_0}]

set_false_path \
-from [get_registers {Mic_Clk_Gen:iCLK_GEN|Mic_Clk_Ctrl:iCLK_CTRL|*select_reg*}] \
-to   [get_registers {Mic_Clk_Gen:iCLK_GEN|Mic_Clk_Ctrl:iCLK_CTRL|*select_reg*}]

set_false_path \
-from [get_registers {Mic_Clk_Gen:iCLK_GEN|Mic_Clk_Ctrl:iCLK_CTRL|Mic_Clk_Ctrl_altclkctrl_0:altclkctrl_0|Mic_Clk_Ctrl_altclkctrl_0_sub:Mic_Clk_Ctrl_altclkctrl_0_sub_component|sd1~FF_0}] \
-to   [get_registers {Mic_Clk_Gen:iCLK_GEN|Mic_Clk_Ctrl:iCLK_CTRL|*select_reg*}]

set_false_path \
-from [get_registers {Mic_Clk_Gen:iCLK_GEN|Mic_Clk_Ctrl:iCLK_CTRL|*select_reg*}] \
-to   [get_registers {Mic_Clk_Gen:iCLK_GEN|Mic_Clk_Ctrl:iCLK_CTRL|Mic_Clk_Ctrl_altclkctrl_0:altclkctrl_0|Mic_Clk_Ctrl_altclkctrl_0_sub:Mic_Clk_Ctrl_altclkctrl_0_sub_component|sd1~FF_0}]

set_false_path \
-from [get_registers {Mic_Clk_Gen:iCLK_GEN|Mic_Clk_Ctrl:iCLK_CTRL|Mic_Clk_Ctrl_altclkctrl_0:altclkctrl_0|Mic_Clk_Ctrl_altclkctrl_0_sub:Mic_Clk_Ctrl_altclkctrl_0_sub_component|sd1~FF_0}] \
-to   [get_registers {Mic_Clk_Gen:iCLK_GEN|Mic_Clk_Ctrl:iCLK_CTRL|Mic_Clk_Ctrl_altclkctrl_0:altclkctrl_0|Mic_Clk_Ctrl_altclkctrl_0_sub:Mic_Clk_Ctrl_altclkctrl_0_sub_component|sd1~FF_0}]


#**************************************************************
# Set Multicycle Path
#**************************************************************



#**************************************************************
# Set Maximum Delay
#**************************************************************



#**************************************************************
# Set Minimum Delay
#**************************************************************



#**************************************************************
# Set Input Transition
#**************************************************************



#**************************************************************
# Set Load
#**************************************************************



