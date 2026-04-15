// ------------------------------------------------------------
// Module: PDM2PCM
// Description: Top-level module for the PDM-to-PCM design.
//              It connects the ADC-based audio front end,
//              microphone PDM inputs, PCM conversion blocks,
//              a display FIFO, and six 7-segment displays.
//              The selected PCM stream is buffered through
//              the FIFO and displayed as a 16-bit hexadecimal
//              value on HEX3-HEX0.
// Author: Srivibhav Jonnalagadda
// Date: 04-15-2026
// ------------------------------------------------------------
module PDM2PCM (

    //////////// ADC //////////
    output ADC_CONVST,
    output ADC_DIN,
    input  ADC_DOUT,
    output ADC_SCLK,

    //////////// CLOCK //////////
    input CLOCK2_50,
    input CLOCK3_50,
    input CLOCK4_50,
    input CLOCK_50,

    //////////// SEG7 //////////
    output [6:0] HEX0,
    output [6:0] HEX1,
    output [6:0] HEX2,
    output [6:0] HEX3,
    output [6:0] HEX4,
    output [6:0] HEX5,

    //////////// KEY //////////
    input [3:0] KEY,

    //////////// SW //////////
    input [9:0] SW,

    //////////// GPIO_0, GPIO_0 connect to GPIO Default //////////
    inout [35:0] GPIO
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
  assign rst_i = ~KEY[0];

  // Frequency selection based on SW[4:2].
  assign freq_sel = SW[4:2];

  // Select which PCM stream to capture/display.
  // 0: GPIO[1] positive edge mic, 1: GPIO[1] negative edge mic,
  // 2: GPIO[2] positive edge mic, 3: GPIO[2] negative edge mic.
  assign pcm_stream_sel = SW[6:5];

  // Output the mic clock on the GPIO.
  assign GPIO[0] = mic_clk_o;

  // We don't care about the remaining GPIO pins.
  assign GPIO[35:3] = {33{1'bz}};

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
      .ADC_CS_o(ADC_CONVST),
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
      .mic_data_i       (GPIO[1]),                // Input the mic's PDM signal.
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
      .mic_data_i       (GPIO[2]),                // Input the mic's PDM signal.
      .pos_pcm_cap_rdy_i(conv2_pos_pcm_cap_rdy),
      .neg_pcm_cap_rdy_i(conv2_neg_pcm_cap_rdy),

      .pcm_pos_o      (conv2_pcm_pos),
      .pcm_valid_pos_o(conv2_pcm_valid_pos),
      .pcm_neg_o      (conv2_pcm_neg),
      .pcm_valid_neg_o(conv2_pcm_valid_neg)
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

  // Display the selected PCM sample as four hexadecimal digits.
  Seven_Seg iHEX0 (
      .bin_i(display_sample[3:0]),
      .hex_o(HEX0)
  );

  Seven_Seg iHEX1 (
      .bin_i(display_sample[7:4]),
      .hex_o(HEX1)
  );

  Seven_Seg iHEX2 (
      .bin_i(display_sample[11:8]),
      .hex_o(HEX2)
  );

  Seven_Seg iHEX3 (
      .bin_i(display_sample[15:12]),
      .hex_o(HEX3)
  );

  // Display the selected PCM stream number on HEX4.
  Seven_Seg iHEX4 (
      .bin_i({2'b00, pcm_stream_sel}),
      .hex_o(HEX4)
  );

  // Display the current microphone mode on HEX5.
  Seven_Seg iHEX5 (
      .bin_i({2'b00, curr_mode}),
      .hex_o(HEX5)
  );

endmodule
