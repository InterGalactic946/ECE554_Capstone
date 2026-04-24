// ============================================================================
// Copyright (c) 2013 by Terasic Technologies Inc.
// ============================================================================
//
// Permission:
//
//   Terasic grants permission to use and modify this code for use
//   in synthesis for all Terasic Development Boards and Altera Development 
//   Kits made by Terasic.  Other use of this code, including the selling 
//   ,duplication, or modification of any portion is strictly prohibited.
//
// Disclaimer:
//
//   This VHDL/Verilog or C/C++ source code is intended as a design reference
//   which illustrates how these types of functions can be implemented.
//   It is the user's responsibility to verify their design for
//   consistency and functionality through the use of formal
//   verification methods.  Terasic provides no warranty regarding the use 
//   or functionality of this code.
//
// ============================================================================
//           
//  Terasic Technologies Inc
//  9F., No.176, Sec.2, Gongdao 5th Rd, East Dist, Hsinchu City, 30070. Taiwan
//  
//  
//                     web: http://www.terasic.com/  
//                     email: support@terasic.com
//
// ============================================================================
//Date:  Mon Jun 17 20:35:29 2013
// ============================================================================

`define ENABLE_HPS

module DE1_SOC_Linux_FB(

     inout              ADC_CS_N,
      output             ADC_DIN,
      input              ADC_DOUT,
      output             ADC_SCLK,

      ///////// AUD /////////
      input              AUD_ADCDAT,
      inout              AUD_ADCLRCK,
      inout              AUD_BCLK,
      output             AUD_DACDAT,
      inout              AUD_DACLRCK,
      output             AUD_XCK,

      ///////// CLOCK2 /////////
      input              CLOCK2_50,

      ///////// CLOCK3 /////////
      input              CLOCK3_50,

      ///////// CLOCK4 /////////
      input              CLOCK4_50,

      ///////// CLOCK /////////
      input              CLOCK_50,

      ///////// DRAM /////////
      output      [12:0] DRAM_ADDR,
      output      [1:0]  DRAM_BA,
      output             DRAM_CAS_N,
      output             DRAM_CKE,
      output             DRAM_CLK,
      output             DRAM_CS_N,
      inout       [15:0] DRAM_DQ,
      output             DRAM_LDQM,
      output             DRAM_RAS_N,
      output             DRAM_UDQM,
      output             DRAM_WE_N,

      ///////// FAN /////////
      output             FAN_CTRL,

      ///////// FPGA /////////
      output             FPGA_I2C_SCLK,
      inout              FPGA_I2C_SDAT,

      ///////// GPIO /////////
      inout     [35:0]         GPIO_0,
      inout     [35:0]         GPIO_1,
 

      ///////// HEX0 /////////
      output      [6:0]  HEX0,

      ///////// HEX1 /////////
      output      [6:0]  HEX1,

      ///////// HEX2 /////////
      output      [6:0]  HEX2,

      ///////// HEX3 /////////
      output      [6:0]  HEX3,

      ///////// HEX4 /////////
      output     [6:0]  HEX4,

      ///////// HEX5 /////////
      output      [6:0]  HEX5,

`ifdef ENABLE_HPS
      ///////// HPS /////////
      inout              HPS_CONV_USB_N,
      output      [14:0] HPS_DDR3_ADDR,
      output      [2:0]  HPS_DDR3_BA,
      output             HPS_DDR3_CAS_N,
      output             HPS_DDR3_CKE,
      output             HPS_DDR3_CK_N,
      output             HPS_DDR3_CK_P,
      output             HPS_DDR3_CS_N,
      output      [3:0]  HPS_DDR3_DM,
      inout       [31:0] HPS_DDR3_DQ,
      inout       [3:0]  HPS_DDR3_DQS_N,
      inout       [3:0]  HPS_DDR3_DQS_P,
      output             HPS_DDR3_ODT,
      output             HPS_DDR3_RAS_N,
      output             HPS_DDR3_RESET_N,
      input              HPS_DDR3_RZQ,
      output             HPS_DDR3_WE_N,
      output             HPS_ENET_GTX_CLK,
      inout              HPS_ENET_INT_N,
      output             HPS_ENET_MDC,
      inout              HPS_ENET_MDIO,
      input              HPS_ENET_RX_CLK,
      input       [3:0]  HPS_ENET_RX_DATA,
      input              HPS_ENET_RX_DV,
      output      [3:0]  HPS_ENET_TX_DATA,
      output             HPS_ENET_TX_EN,
      inout       [3:0]  HPS_FLASH_DATA,
      output             HPS_FLASH_DCLK,
      output             HPS_FLASH_NCSO,
      inout              HPS_GSENSOR_INT,
      inout              HPS_I2C1_SCLK,
      inout              HPS_I2C1_SDAT,
      inout              HPS_I2C2_SCLK,
      inout              HPS_I2C2_SDAT,
      inout              HPS_I2C_CONTROL,
      inout              HPS_KEY,
      inout              HPS_LED,
      inout              HPS_LTC_GPIO,
      output             HPS_SD_CLK,
      inout              HPS_SD_CMD,
      inout       [3:0]  HPS_SD_DATA,
      output             HPS_SPIM_CLK,
      input              HPS_SPIM_MISO,
      output             HPS_SPIM_MOSI,
      inout              HPS_SPIM_SS,
      input              HPS_UART_RX,
      output             HPS_UART_TX,
      input              HPS_USB_CLKOUT,
      inout       [7:0]  HPS_USB_DATA,
      input              HPS_USB_DIR,
      input              HPS_USB_NXT,
      output             HPS_USB_STP,
`endif /*ENABLE_HPS*/

      ///////// IRDA /////////
      input              IRDA_RXD,
      output             IRDA_TXD,

      ///////// KEY /////////
      input       [3:0]  KEY,

      ///////// LEDR /////////
      output      [9:0]  LEDR,

      ///////// PS2 /////////
      inout              PS2_CLK,
      inout              PS2_CLK2,
      inout              PS2_DAT,
      inout              PS2_DAT2,

      ///////// SW /////////
      input       [9:0]  SW,

      ///////// TD /////////
      input              TD_CLK27,
      input      [7:0]  TD_DATA,
      input             TD_HS,
      output             TD_RESET_N,
      input             TD_VS,

      ///////// VGA /////////
      output      [7:0]  VGA_B,
      output             VGA_BLANK_N,
      output             VGA_CLK,
      output      [7:0]  VGA_G,
      output             VGA_HS,
      output      [7:0]  VGA_R,
      output             VGA_SYNC_N,
      output             VGA_VS
);


//=======================================================
//  REG/WIRE declarations
//=======================================================
// internal wires and registers declaration
wire  [3:0]  fpga_debounced_buttons;
wire  [3:0]  fpga_led_internal;
wire         hps_fpga_reset_n;
 
wire               clk_65;
wire [7:0]         vid_r,vid_g,vid_b;
wire               vid_v_sync ;
wire               vid_h_sync ;
wire               vid_datavalid;

//=======================================================
//  Structural coding
//=======================================================      
assign   VGA_BLANK_N          =     1'b1;
assign   VGA_SYNC_N           =     1'b0;	
assign   VGA_CLK              =     clk_65;
assign  {VGA_B,VGA_G,VGA_R}   =     {vid_b,vid_g,vid_r};
assign   VGA_VS               =     vid_v_sync;
assign   VGA_HS               =     vid_h_sync;
  
// Debounce logic to clean out glitches within 1ms
debounce debounce_inst (
  .clk                                  (CLOCK3_50),
  .reset_n                              (hps_fpga_reset_n),  
  .data_in                              (KEY),
  .data_out                             (fpga_debounced_buttons)
);
 defparam debounce_inst.WIDTH = 4;
 defparam debounce_inst.POLARITY = "LOW";
 defparam debounce_inst.TIMEOUT = 50000;        // at 50Mhz this is a debounce time of 1ms
 defparam debounce_inst.TIMEOUT_WIDTH = 16;     // ceil(log2(TIMEOUT))


vga_pll  vga_pll_inst(
			.refclk(CLOCK4_50),   //  refclk.clk
		   .rst(1'b0),      //   reset.reset
		   .outclk_0(clk_65), // outclk0.clk
		   .locked()    //  locked.export
);

//////////////////
  // Parameters //
  ////////////////
  // 50 MHz / 5,000,000 = 10 Hz refresh rate per sample.
  localparam integer DISPLAY_UPDATE_DIV = 5000000;

  /////////////////////////////////////////////////////
  // Declare clock, reset, and mode control signals //
  ///////////////////////////////////////////////////
  wire clk_i;
  wire rst_i;
  wire mic_clk_o;
  wire mic_data_val;
  wire [1:0] curr_mode;
  wire [2:0] freq_sel;
  wire ps_ready_for_data;
  reg latch_event_done;

  always @(posedge clk_i) begin
    if (rst_i) begin
      latch_event_done <= 1'b0;
    end else if (event_done) begin
      latch_event_done <= 1'b1;
    end if (~KEY[2]) begin
      latch_event_done <= 1'b0;
    end
  end

  assign LEDR[0] = rst_i;  // Show reset state on LEDR[0]
  assign LEDR[1] = ps_ready_for_data;
  assign LEDR[2] = latch_event_done;

  /////////////////////////////////////////////////
  // Declare PCM converter interface signals    //
  ///////////////////////////////////////////////
  wire signed [15:0] conv1_pcm_pos;
  wire signed [15:0] conv1_pcm_neg;
  wire signed [15:0] conv2_pcm_pos;
  wire signed [15:0] conv2_pcm_neg;
  wire conv1_pcm_valid_pos;
  wire conv1_pcm_valid_neg;
  wire conv2_pcm_valid_pos;
  wire conv2_pcm_valid_neg;
  wire conv1_pos_pcm_cap_rdy;
  wire conv1_neg_pcm_cap_rdy;
  wire conv2_pos_pcm_cap_rdy;
  wire conv2_neg_pcm_cap_rdy;

  /////////////////////////////////////////////////
  // Declare FIFO capture and display signals   //
  ///////////////////////////////////////////////
  wire [1:0] pcm_stream_sel;
  reg signed [15:0] fifo_data;
  reg fifo_pcm_valid;
  wire fifo_wrreq;
  wire fifo_rdreq;
  wire fifo_empty;
  wire fifo_full;
  wire [15:0] fifo_q;
  wire [12:0] fifo_usedw;

  reg fifo_rdreq_q;
  reg [15:0] latest_fifo_sample;
  reg [15:0] display_sample;
  reg [22:0] display_div_cnt;

  /////////////////////////////
  // Top-level assignments  //
  ///////////////////////////
  // Drive the internal system clock and active-high reset.
  assign clk_i = CLOCK_50;
  assign rst_i = ~fpga_debounced_buttons[0];


  // Frequency selection based on SW[4:2].
  assign freq_sel = SW[4:2];

  // Select which PCM stream to capture/display.
  // 0: GPIO[1] positive edge mic, 1: GPIO[1] negative edge mic,
  // 2: GPIO[2] positive edge mic, 3: GPIO[2] negative edge mic.
  assign pcm_stream_sel = SW[6:5];

  // Output the mic clock on the GPIO.
  assign GPIO_0[0] = mic_clk_o;

  // We don't care about the remaining GPIO pins.
  assign GPIO_0[35:3] = {33{1'bz}};

  wire [9:0] ps_to_pl_data;
  wire [9:0] pl_to_ps_data;
  wire [15:0] data_from_pl;
  wire ready_for_data, data_valid;

  wire ps_ready_for_data_time, ps_ready_for_data_quadrant;
  wire ready_for_data_time, ready_for_data_quadrant;
  wire [9:0] pl_to_ps_data_time, pl_to_ps_data_quadrant;


  assign pl_to_ps_data = SW[9] ? pl_to_ps_data_time : pl_to_ps_data_quadrant;
  assign ready_for_data = SW[9] ? ready_for_data_time : ready_for_data_quadrant;
  assign ps_ready_for_data = SW[9] ? ps_ready_for_data_time : ps_ready_for_data_quadrant;

 hit_time_to_ps hit_time_to_ps_inst (
    .clk(clk_i),
    .rst_n(~rst_i),
    .data_from_ps(ps_to_pl_data),
    .input_data_valid(event_done),
    .input_data({hit_time1, hit_time2, hit_time3, hit_time4}),
    .data_to_ps(pl_to_ps_data_time),
    .ready_for_data(ready_for_data_time),
    .ps_ready_for_data(ps_ready_for_data_time)
  );

  pl_to_ps pl_to_ps_inst (
    .clk(clk_i),
    .rst_n(~rst_i),
    .data_from_ps(ps_to_pl_data),
    .input_data(quadrant_code),
    .input_data_valid(quadrant_valid),
    .data_to_ps(pl_to_ps_data_quadrant),
    .ready_for_data(ready_for_data_quadrant),
    .ps_ready_for_data(ps_ready_for_data_quadrant)
);

mock_data mock_data_inst (
    .clk(clk_i),
    .rst_n(~rst_i),
    .data_out(data_from_pl),
    .data_valid(data_valid),
);

  //////////////////////////
  // Submodule instances //
  ////////////////////////
  // Instantiate the Audio Front End.
  Audio_Front_End iAUD_FRONT (
      .clk_i(clk_i),
      .rst_i(rst_i),
      .mode_req_i(SW[1:0]),

      .ADC_data_out_i(ADC_DOUT),
      .ADC_SCLK_o(ADC_SCLK),
      .ADC_CS_o(ADC_CS_N),
      .ADC_data_in_o(ADC_DIN),

      .curr_mode_o(curr_mode),
      .data_val_o (mic_data_val),
      .mic_clk_o  (mic_clk_o)
  );

  // Instantiate the PDM2PCM module for the first microphone data input.
  Pdm_To_Pcm iCONV_1 (
      .clk_i            (clk_i),
      .rst_i            (rst_i),
      .mic_clk_i        (mic_clk_o),
      .mic_clk_val_i    (mic_data_val),
      .freq_sel_i       (freq_sel),
      .mic_data_i       (GPIO_0[1]),              // Input the mic's PDM signal.
      .pos_pcm_cap_rdy_i(conv1_pos_pcm_cap_rdy),
      .neg_pcm_cap_rdy_i(conv1_neg_pcm_cap_rdy),

      .pcm_pos_o      (conv1_pcm_pos),
      .pcm_valid_pos_o(conv1_pcm_valid_pos),
      .pcm_neg_o      (conv1_pcm_neg),
      .pcm_valid_neg_o(conv1_pcm_valid_neg)
  );

  // Instantiate the PDM2PCM module for the second microphone data input.
  Pdm_To_Pcm iCONV_2 (
      .clk_i            (clk_i),
      .rst_i            (rst_i),
      .mic_clk_i        (mic_clk_o),
      .mic_clk_val_i    (mic_data_val),
      .freq_sel_i       (freq_sel),
      .mic_data_i       (GPIO_0[2]),              // Input the mic's PDM signal.
      .pos_pcm_cap_rdy_i(conv2_pos_pcm_cap_rdy),
      .neg_pcm_cap_rdy_i(conv2_neg_pcm_cap_rdy),

      .pcm_pos_o      (conv2_pcm_pos),
      .pcm_valid_pos_o(conv2_pcm_valid_pos),
      .pcm_neg_o      (conv2_pcm_neg),
      .pcm_valid_neg_o(conv2_pcm_valid_neg)
  );

  wire pulse;

  pulse_gen #(.PULSE_LENGTH_MS(100), .PULSE_GAP_MS(500)) pulse_gen_inst (
    .clk(clk_i),
    .rst_n(~rst_i),
    .freq_sel(2'b10),
    .pulse(pulse)
  );

  assign GPIO_0[5] = pulse;

  wire [2:0] quadrant_code;
  wire quadrant_valid, event_done;
  wire [3:0]  threshold_valid;
  reg [3:0]  prev_threshold_valid;
  wire [15:0] hit_time1, hit_time2, hit_time3, hit_time4;
  reg [15:0] prev_hit_time1, prev_hit_time2, prev_hit_time3, prev_hit_time4;
  wire [15:0] sta_mean_1, sta_mean_2, sta_mean_3, sta_mean_4;
  wire [15:0] lta_mean_1, lta_mean_2, lta_mean_3, lta_mean_4;
  wire sta_valid_1, sta_valid_2, sta_valid_3, sta_valid_4;
  wire lta_valid_1, lta_valid_2, lta_valid_3, lta_valid_4;


  tdoa tdoa_inst (
    .clk(clk_i),
    .rst_n(~rst_i),
    .mic_valid({conv1_pcm_valid_pos, conv1_pcm_valid_neg, conv2_pcm_valid_pos, conv2_pcm_valid_neg}),
    .mic_pcm_0(conv1_pcm_pos),
    .mic_pcm_1(conv1_pcm_neg),
    .mic_pcm_2(conv2_pcm_pos),
    .mic_pcm_3(conv2_pcm_neg),
    .quadrant_valid(quadrant_valid),
    .quadrant_code(quadrant_code),
    .collect_sample(collect_sample),
    .hit_time1(hit_time1),
    .hit_time2(hit_time2),
    .hit_time3(hit_time3),
    .hit_time4(hit_time4),
    .threshold_valid(threshold_valid),
    .event_done(event_done),
    .sta_mean_1(sta_mean_1),
    .sta_mean_2(sta_mean_2),
    .sta_mean_3(sta_mean_3),
    .sta_mean_4(sta_mean_4),
    .lta_mean_1(lta_mean_1),
    .lta_mean_2(lta_mean_2),
    .lta_mean_3(lta_mean_3),
    .lta_mean_4(lta_mean_4),
    .sta_valid_1(sta_valid_1),
    .sta_valid_2(sta_valid_2),
    .sta_valid_3(sta_valid_3),
    .sta_valid_4(sta_valid_4),
    .lta_valid_1(lta_valid_1),
    .lta_valid_2(lta_valid_2),
    .lta_valid_3(lta_valid_3),
    .lta_valid_4(lta_valid_4)
  );

  /////////////////////////////////
  // PCM stream selection logic //
  ///////////////////////////////
  // Select one of the four PCM streams to push into the display FIFO.
  always @(*) begin
    fifo_data = 16'h0000;
    fifo_pcm_valid = 1'b0;

    case (pcm_stream_sel)
      2'b00: begin
        fifo_data = conv1_pcm_pos;
        fifo_pcm_valid = conv1_pcm_valid_pos;
      end
      2'b01: begin
        fifo_data = conv1_pcm_neg;
        fifo_pcm_valid = conv1_pcm_valid_neg;
      end
      2'b10: begin
        fifo_data = conv2_pcm_pos;
        fifo_pcm_valid = conv2_pcm_valid_pos;
      end
      2'b11: begin
        fifo_data = conv2_pcm_neg;
        fifo_pcm_valid = conv2_pcm_valid_neg;
      end
      default: begin
        fifo_data = 16'h0000;
        fifo_pcm_valid = 1'b0;
      end
    endcase
  end

  ////////////////////////
  // FIFO control logic //
  //////////////////////
  // Write selected PCM samples when the FIFO can accept data.
  assign fifo_wrreq = fifo_pcm_valid & ~fifo_full;

  // Read continuously so the most recent captured sample reaches the display.
  assign fifo_rdreq = ~fifo_empty;

  // Backpressure only the selected stream when the display FIFO is full.
  assign conv1_pos_pcm_cap_rdy = (pcm_stream_sel == 2'b00) ? ~fifo_full : 1'b1;
  assign conv1_neg_pcm_cap_rdy = (pcm_stream_sel == 2'b01) ? ~fifo_full : 1'b1;
  assign conv2_pos_pcm_cap_rdy = (pcm_stream_sel == 2'b10) ? ~fifo_full : 1'b1;
  assign conv2_neg_pcm_cap_rdy = (pcm_stream_sel == 2'b11) ? ~fifo_full : 1'b1;

  // Instantiate the PCM display FIFO.
  FIFO iPCM_DISPLAY_FIFO (
      .clock(clk_i), 
      .data (fifo_data),
      .rdreq(fifo_rdreq),
      .sclr (rst_i),
      .wrreq(fifo_wrreq),

      .empty(fifo_empty),
      .full (fifo_full),
      .q    (fifo_q),
      .usedw(fifo_usedw)
  );

  // Register the FIFO output one cycle after each read request.
  always @(posedge clk_i) begin
    if (rst_i) begin
      fifo_rdreq_q <= 1'b0;
      latest_fifo_sample <= 16'h0000;
    end else begin
      fifo_rdreq_q <= fifo_rdreq;

      if (fifo_rdreq_q) begin
        latest_fifo_sample <= fifo_q;
      end
    end
  end

  always @(posedge clk_i) begin
    if (rst_i) begin
      prev_hit_time1 <= 16'h0;
      prev_hit_time2 <= 16'h0;
      prev_hit_time3 <= 16'h0;
      prev_hit_time4 <= 16'h0;
      prev_threshold_valid <= 4'h0;
    end else if (event_done && ~SW[8]) begin
      prev_hit_time1 <= hit_time1;
      prev_hit_time2 <= hit_time2;
      prev_hit_time3 <= hit_time3;
      prev_hit_time4 <= hit_time4;
      prev_threshold_valid <= threshold_valid;
    end
  end

  //////////////////////////
  // HEX display logic   //
  ////////////////////////
  // Slow the visible update rate so the HEX display can be read by eye.
  always @(posedge clk_i) begin
    if (rst_i) begin
      display_div_cnt <= 23'd0;
      display_sample  <= 16'h0000;
    end else if (display_div_cnt == DISPLAY_UPDATE_DIV - 1) begin
      display_div_cnt <= 23'd0;
      display_sample  <= latest_fifo_sample;
    end else begin
      display_div_cnt <= display_div_cnt + 1'b1;
    end
  end

  reg [3:0] hex0_data, hex1_data, hex2_data, hex3_data, hex4_data, hex5_data;
  reg [2:0] page_sel;
  reg next_page;
  reg prev_button_1;

  always @(posedge clk_i) begin
    if (rst_i) begin
      prev_button_1 <= 1'b1;
    end else begin
      prev_button_1 <= fpga_debounced_buttons[1];
    end
  end

  always @(posedge clk_i) begin
    if (rst_i) begin
      page_sel <= 3'b000;
    end else if ((~fpga_debounced_buttons[1] && prev_button_1) || next_page) begin
      page_sel <= page_sel + 1'b1;
    end
  end

  always @(*) begin
    next_page = 1'b0;
    if (page_sel == 0) begin
      // Show PCM sample and stream/mode info.
      hex0_data = display_sample[3:0];
      hex1_data = display_sample[7:4];
      hex2_data = display_sample[11:8];
      hex3_data = display_sample[15:12];
      hex4_data = {2'b00, pcm_stream_sel};
      hex5_data = {2'b00, curr_mode};
    end else if (page_sel == 1) begin
      // Show TDOA quadrant code and validity.
      hex0_data = {1'b0, quadrant_code};
      hex1_data = {3'b0, quadrant_valid};
      hex2_data = {3'b0, collect_sample};
      hex3_data = {3'b0, event_done};
      hex4_data = 0;
      hex5_data = 0;
    end else if (page_sel == 2) begin
      // Show hit times and their validity.
      hex0_data = prev_hit_time1[3:0];
      hex1_data = prev_hit_time1[7:4];
      hex2_data = prev_hit_time1[11:8];
      hex3_data = prev_hit_time1[15:12];
      hex4_data = {3'b0, threshold_valid[0]};
      hex5_data = 4'd1;
    end else if (page_sel == 3) begin
      // Show hit times and their validity.
      hex0_data = prev_hit_time2[3:0];
      hex1_data = prev_hit_time2[7:4];
      hex2_data = prev_hit_time2[11:8];
      hex3_data = prev_hit_time2[15:12];
      hex4_data = {3'b0, threshold_valid[1]};
      hex5_data = 4'd2;
    end else if (page_sel == 4) begin
      // Show hit times and their validity.
      hex0_data = prev_hit_time3[3:0];
      hex1_data = prev_hit_time3[7:4];
      hex2_data = prev_hit_time3[11:8];
      hex3_data = prev_hit_time3[15:12];
      hex4_data = {3'b0, threshold_valid[2]};
      hex5_data = 4'd3;
    end else if (page_sel == 5) begin
      // Show hit times and their validity.
      hex0_data = prev_hit_time4[3:0];
      hex1_data = prev_hit_time4[7:4];
      hex2_data = prev_hit_time4[11:8];
      hex3_data = prev_hit_time4[15:12];
      hex4_data = {3'b0, threshold_valid[3]};
      hex5_data = 4'd4;
    end else begin
      hex0_data = 0;
      hex1_data = 0;
      hex2_data = 0;
      hex3_data = 0;
      hex4_data = 0;
      hex5_data = 0;
      // Default to showing PCM sample and stream/mode info.
      next_page = 1'b1;
    end
  end


  reg  [5:0] band_visual;
  assign LEDR[9:4] = band_visual;

  always @(*) begin
    case(freq_sel)
      3'b100: band_visual = 6'b110000;
      3'b000: band_visual = 6'b011000;
      3'b001: band_visual = 6'b001100;
      3'b010: band_visual = 6'b000110;
      3'b011: band_visual = 6'b000011;
      default: band_visual = 6'b000000;
    endcase
  end

  // Display the selected PCM sample as four hexadecimal digits.
  Seven_Seg iHEX0 (
      .bin_i(hex0_data),
      .hex_o(HEX0)
  );

  Seven_Seg iHEX1 (
      .bin_i(hex1_data),
      .hex_o(HEX1)
  );

  Seven_Seg iHEX2 (
      .bin_i(hex2_data),
      .hex_o(HEX2)
  );

  Seven_Seg iHEX3 (
      .bin_i(hex3_data),
      .hex_o(HEX3)
  );

  // Display the selected PCM stream number on HEX4.
  Seven_Seg iHEX4 (
      .bin_i(hex4_data),
      .hex_o(HEX4)
  );

  // Display the current microphone mode on HEX5.
  Seven_Seg iHEX5 (
      .bin_i(hex5_data),
      .hex_o(HEX5)
  );

soc_system u0 (
        .clk_clk                               ( CLOCK_50),                          	 //             clk.clk
        .reset_reset_n                         ( hps_fpga_reset_n & ~rst_i),                      //           reset.reset_n
        .memory_mem_a                          ( HPS_DDR3_ADDR),                          //          memory.mem_a
        .memory_mem_ba                         ( HPS_DDR3_BA),                         //                .mem_ba
        .memory_mem_ck                         ( HPS_DDR3_CK_P),                         //                .mem_ck
        .memory_mem_ck_n                       ( HPS_DDR3_CK_N),                       //                .mem_ck_n
        .memory_mem_cke                        ( HPS_DDR3_CKE),                        //                .mem_cke
        .memory_mem_cs_n                       ( HPS_DDR3_CS_N),                       //                .mem_cs_n
        .memory_mem_ras_n                      ( HPS_DDR3_RAS_N),                      //                .mem_ras_n
        .memory_mem_cas_n                      ( HPS_DDR3_CAS_N),                      //                 .mem_cas_n
        .memory_mem_we_n                       ( HPS_DDR3_WE_N),                       //                .mem_we_n
        .memory_mem_reset_n                    ( HPS_DDR3_RESET_N),                    //                .mem_reset_n
        .memory_mem_dq                         ( HPS_DDR3_DQ),                         //                .mem_dq
        .memory_mem_dqs                        ( HPS_DDR3_DQS_P),                        //                .mem_dqs
        .memory_mem_dqs_n                      ( HPS_DDR3_DQS_N),                      //                .mem_dqs_n
        .memory_mem_odt                        ( HPS_DDR3_ODT),                        //                .mem_odt
        .memory_mem_dm                         ( HPS_DDR3_DM),                         //                .mem_dm
        .memory_oct_rzqin                      ( HPS_DDR3_RZQ),                      //                .oct_rzqin
       		
	     .hps_0_hps_io_hps_io_emac1_inst_TX_CLK ( HPS_ENET_GTX_CLK), //                   hps_0_hps_io.hps_io_emac1_inst_TX_CLK
        .hps_0_hps_io_hps_io_emac1_inst_TXD0   ( HPS_ENET_TX_DATA[0] ),   //                               .hps_io_emac1_inst_TXD0
        .hps_0_hps_io_hps_io_emac1_inst_TXD1   ( HPS_ENET_TX_DATA[1] ),   //                               .hps_io_emac1_inst_TXD1
        .hps_0_hps_io_hps_io_emac1_inst_TXD2   ( HPS_ENET_TX_DATA[2] ),   //                               .hps_io_emac1_inst_TXD2
        .hps_0_hps_io_hps_io_emac1_inst_TXD3   ( HPS_ENET_TX_DATA[3] ),   //                               .hps_io_emac1_inst_TXD3
        .hps_0_hps_io_hps_io_emac1_inst_RXD0   ( HPS_ENET_RX_DATA[0] ),   //                               .hps_io_emac1_inst_RXD0
        .hps_0_hps_io_hps_io_emac1_inst_MDIO   ( HPS_ENET_MDIO ),   //                               .hps_io_emac1_inst_MDIO
        .hps_0_hps_io_hps_io_emac1_inst_MDC    ( HPS_ENET_MDC  ),    //                               .hps_io_emac1_inst_MDC
        .hps_0_hps_io_hps_io_emac1_inst_RX_CTL ( HPS_ENET_RX_DV), //                               .hps_io_emac1_inst_RX_CTL
        .hps_0_hps_io_hps_io_emac1_inst_TX_CTL ( HPS_ENET_TX_EN), //                               .hps_io_emac1_inst_TX_CTL
        .hps_0_hps_io_hps_io_emac1_inst_RX_CLK ( HPS_ENET_RX_CLK), //                               .hps_io_emac1_inst_RX_CLK
        .hps_0_hps_io_hps_io_emac1_inst_RXD1   ( HPS_ENET_RX_DATA[1] ),   //                               .hps_io_emac1_inst_RXD1
        .hps_0_hps_io_hps_io_emac1_inst_RXD2   ( HPS_ENET_RX_DATA[2] ),   //                               .hps_io_emac1_inst_RXD2
        .hps_0_hps_io_hps_io_emac1_inst_RXD3   ( HPS_ENET_RX_DATA[3] ),   //                               .hps_io_emac1_inst_RXD3
        
		  
		  .hps_0_hps_io_hps_io_qspi_inst_IO0     ( HPS_FLASH_DATA[0]    ),     //                               .hps_io_qspi_inst_IO0
        .hps_0_hps_io_hps_io_qspi_inst_IO1     ( HPS_FLASH_DATA[1]    ),     //                               .hps_io_qspi_inst_IO1
        .hps_0_hps_io_hps_io_qspi_inst_IO2     ( HPS_FLASH_DATA[2]    ),     //                               .hps_io_qspi_inst_IO2
        .hps_0_hps_io_hps_io_qspi_inst_IO3     ( HPS_FLASH_DATA[3]    ),     //                               .hps_io_qspi_inst_IO3
        .hps_0_hps_io_hps_io_qspi_inst_SS0     ( HPS_FLASH_NCSO    ),     //                               .hps_io_qspi_inst_SS0
        .hps_0_hps_io_hps_io_qspi_inst_CLK     ( HPS_FLASH_DCLK    ),     //                               .hps_io_qspi_inst_CLK
        
		  .hps_0_hps_io_hps_io_sdio_inst_CMD     ( HPS_SD_CMD    ),     //                               .hps_io_sdio_inst_CMD
        .hps_0_hps_io_hps_io_sdio_inst_D0      ( HPS_SD_DATA[0]     ),      //                               .hps_io_sdio_inst_D0
        .hps_0_hps_io_hps_io_sdio_inst_D1      ( HPS_SD_DATA[1]     ),      //                               .hps_io_sdio_inst_D1
        .hps_0_hps_io_hps_io_sdio_inst_CLK     ( HPS_SD_CLK   ),     //                               .hps_io_sdio_inst_CLK
        .hps_0_hps_io_hps_io_sdio_inst_D2      ( HPS_SD_DATA[2]     ),      //                               .hps_io_sdio_inst_D2
        .hps_0_hps_io_hps_io_sdio_inst_D3      ( HPS_SD_DATA[3]     ),      //                               .hps_io_sdio_inst_D3
        		  
		  .hps_0_hps_io_hps_io_usb1_inst_D0      ( HPS_USB_DATA[0]    ),      //                               .hps_io_usb1_inst_D0
        .hps_0_hps_io_hps_io_usb1_inst_D1      ( HPS_USB_DATA[1]    ),      //                               .hps_io_usb1_inst_D1
        .hps_0_hps_io_hps_io_usb1_inst_D2      ( HPS_USB_DATA[2]    ),      //                               .hps_io_usb1_inst_D2
        .hps_0_hps_io_hps_io_usb1_inst_D3      ( HPS_USB_DATA[3]    ),      //                               .hps_io_usb1_inst_D3
        .hps_0_hps_io_hps_io_usb1_inst_D4      ( HPS_USB_DATA[4]    ),      //                               .hps_io_usb1_inst_D4
        .hps_0_hps_io_hps_io_usb1_inst_D5      ( HPS_USB_DATA[5]    ),      //                               .hps_io_usb1_inst_D5
        .hps_0_hps_io_hps_io_usb1_inst_D6      ( HPS_USB_DATA[6]    ),      //                               .hps_io_usb1_inst_D6
        .hps_0_hps_io_hps_io_usb1_inst_D7      ( HPS_USB_DATA[7]    ),      //                               .hps_io_usb1_inst_D7
        .hps_0_hps_io_hps_io_usb1_inst_CLK     ( HPS_USB_CLKOUT    ),     //                               .hps_io_usb1_inst_CLK
        .hps_0_hps_io_hps_io_usb1_inst_STP     ( HPS_USB_STP    ),     //                               .hps_io_usb1_inst_STP
        .hps_0_hps_io_hps_io_usb1_inst_DIR     ( HPS_USB_DIR    ),     //                               .hps_io_usb1_inst_DIR
        .hps_0_hps_io_hps_io_usb1_inst_NXT     ( HPS_USB_NXT    ),     //                               .hps_io_usb1_inst_NXT
        		  
		  .hps_0_hps_io_hps_io_spim1_inst_CLK    ( HPS_SPIM_CLK  ),    //                               .hps_io_spim1_inst_CLK
        .hps_0_hps_io_hps_io_spim1_inst_MOSI   ( HPS_SPIM_MOSI ),   //                               .hps_io_spim1_inst_MOSI
        .hps_0_hps_io_hps_io_spim1_inst_MISO   ( HPS_SPIM_MISO ),   //                               .hps_io_spim1_inst_MISO
        .hps_0_hps_io_hps_io_spim1_inst_SS0    ( HPS_SPIM_SS ),    //                               .hps_io_spim1_inst_SS0
      		
		  .hps_0_hps_io_hps_io_uart0_inst_RX     ( HPS_UART_RX    ),     //                               .hps_io_uart0_inst_RX
        .hps_0_hps_io_hps_io_uart0_inst_TX     ( HPS_UART_TX    ),     //                               .hps_io_uart0_inst_TX
		
		  .hps_0_hps_io_hps_io_i2c0_inst_SDA     ( HPS_I2C1_SDAT    ),     //                               .hps_io_i2c0_inst_SDA
        .hps_0_hps_io_hps_io_i2c0_inst_SCL     ( HPS_I2C1_SCLK    ),     //                               .hps_io_i2c0_inst_SCL
		
		  .hps_0_hps_io_hps_io_i2c1_inst_SDA     ( HPS_I2C2_SDAT    ),     //                               .hps_io_i2c1_inst_SDA
        .hps_0_hps_io_hps_io_i2c1_inst_SCL     ( HPS_I2C2_SCLK    ),     //                               .hps_io_i2c1_inst_SCL
        
		.hps_0_hps_io_hps_io_gpio_inst_GPIO09  ( HPS_CONV_USB_N),  //                               .hps_io_gpio_inst_GPIO09
        .hps_0_hps_io_hps_io_gpio_inst_GPIO35  ( HPS_ENET_INT_N),  //                               .hps_io_gpio_inst_GPIO35
        .hps_0_hps_io_hps_io_gpio_inst_GPIO40  ( HPS_LTC_GPIO),  //                               .hps_io_gpio_inst_GPIO40
        .hps_0_hps_io_hps_io_gpio_inst_GPIO48  ( HPS_I2C_CONTROL),  //                               .hps_io_gpio_inst_GPIO48
        .hps_0_hps_io_hps_io_gpio_inst_GPIO53  ( HPS_LED),  //                               .hps_io_gpio_inst_GPIO53
        .hps_0_hps_io_hps_io_gpio_inst_GPIO54  ( HPS_KEY),  //                               .hps_io_gpio_inst_GPIO54
        .hps_0_hps_io_hps_io_gpio_inst_GPIO61  ( HPS_GSENSOR_INT),  //                               .hps_io_gpio_inst_GPIO61
       
	    .led_pio_external_connection_export    ( ps_to_pl_data ),      	                              
        .dipsw_pio_external_connection_export  ( pl_to_ps_data ),  //  dipsw_pio_external_connection.export
        .button_pio_external_connection_export ( ), // button_pio_external_connection.export
        .hps_0_h2f_reset_reset_n               ( hps_fpga_reset_n ),                //                hps_0_h2f_reset.reset_n
		  
		  
		  //itc
		  .alt_vip_itc_0_clocked_video_vid_clk         (~clk_65),         					 	 // alt_vip_itc_0_clocked_video.vid_clk
        .alt_vip_itc_0_clocked_video_vid_data        ({vid_r,vid_g,vid_b}),        		 //                .vid_data
        .alt_vip_itc_0_clocked_video_underflow       (),                           		 //                .underflow
        .alt_vip_itc_0_clocked_video_vid_datavalid   (vid_datavalid),                   //                .vid_datavalid
        .alt_vip_itc_0_clocked_video_vid_v_sync      (vid_v_sync),      					 //                .vid_v_sync
        .alt_vip_itc_0_clocked_video_vid_h_sync      (vid_h_sync),      					 //                .vid_h_sync
        .alt_vip_itc_0_clocked_video_vid_f           (),           							 //                .vid_f
        .alt_vip_itc_0_clocked_video_vid_h           (),           							 //                .vid_h
        .alt_vip_itc_0_clocked_video_vid_v           (),            		
		  
    );
endmodule
