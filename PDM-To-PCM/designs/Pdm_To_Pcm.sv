`timescale 1ns / 1ps
// ------------------------------------------------------------
// Module: Pdm_To_Pcm
// Description: Converts PDM data from two microphones (Hi-Mic
//              and Lo-Mic) into PCM format. The module samples
//              the PDM data, processes it through a CIC decimator,
//              and applies FIR compensation to produce the final
//              PCM output. The design supports both single and dual
//              microphone modes based on the mic_mode input.
// Author(s): Nate Parmley and Srivibhav Jonnalagadda
// Date: 04-01-2026
// ------------------------------------------------------------
module Pdm_To_Pcm #(
    parameter int unsigned SYS_CLK_HZ = 50_000_000
) (
    input logic clk_i,
    input logic rst_i,
    input logic mic_clk_i,
    input logic mic_clk_val_i,

    // 2'b00: 10kHz to 18kHz Band
    // 2'b01: 18kHz to 25kHz Band
    // 2'b10: 25kHz to 32kHz Band
    // 2'b11: 32kHz to 40kHz Band
    input logic [1:0] freq_sel_i,

    input logic mic_data_i,
    input logic pos_pcm_cap_rdy_i,
    input logic neg_pcm_cap_rdy_i,

    output logic signed [15:0] pcm_pos_o,
    output logic pcm_valid_pos_o,
    output logic signed [15:0] pcm_neg_o,
    output logic pcm_valid_neg_o
);

  localparam int unsigned NS_PER_SEC = 1_000_000_000;
  localparam int unsigned SYS_CLK_PERIOD_NS = NS_PER_SEC / SYS_CLK_HZ;

  // SPH0641LU4H-1 datasheet worst-case DATA timing:
  // tDD max = 40 ns, tDZ max = 16 ns. tDD dominates, so sample after
  // tDD plus guard while staying safely before the next mic-clock edge.
  localparam int unsigned MIC_TDD_MAX_NS = 40;
  localparam int unsigned MIC_TDZ_MAX_NS = 16;

  // Add a buffer to ensure we sample after the data is stable.
  localparam int unsigned MIC_DATA_SAMPLE_GUARD_NS = 10;

  // Total time for data to settle.
  localparam int unsigned MIC_DATA_SETTLE_NS = MIC_TDD_MAX_NS + MIC_DATA_SAMPLE_GUARD_NS;

  // Calculate the number of system clock cycles needed to meet the data settle time.
  localparam int unsigned MIC_DATA_SETTLE_CYCLES =
      (MIC_DATA_SETTLE_NS + SYS_CLK_PERIOD_NS - 1) / SYS_CLK_PERIOD_NS;

  // Set the capture cycles of the data after the mic clock edge to ensure we sample after the data is stable.
  localparam int unsigned MIC_CAPTURE_DELAY_CYCLES = (MIC_DATA_SETTLE_CYCLES - 1);
  localparam int unsigned MIC_CAPTURE_COUNTER_W = $clog2(MIC_CAPTURE_DELAY_CYCLES + 1);

  /////////////////////////////////////////////////
  // Declare any internal signals as type logic //
  ///////////////////////////////////////////////
  logic rst_n;
  logic mic_clk_step, mic_clk_stable;
  logic mic_clk_stable_prev;
  logic mic_clk_rising, mic_clk_falling;
  logic [MIC_CAPTURE_COUNTER_W-1:0] pos_capture_cntr, neg_capture_cntr;
  logic pos_pdm_cap, neg_pdm_cap;
  logic pdm_pos_valid, pdm_neg_valid;
  logic pdm_pos, pdm_neg;
  logic [1:0] data_in_pos, data_in_neg;
  logic cic_valid_pos, cic_valid_neg;
  logic cic_valid_pos_q, cic_valid_neg_q;
  logic [17:0] cic_out_pos, cic_out_neg;
  logic [1:0] cic_error_pos, cic_error_neg;
  logic [1:0] cic_error_pos_q, cic_error_neg_q;
  logic fir_pos_ready, fir_neg_ready;
  logic [3:0] fir_bank_sel;
  logic [21:0] fir_in_pos, fir_in_neg;
  logic [40:0] comp_out_pos, comp_out_neg;
  logic output_valid_pos, output_valid_neg;
  logic [1:0] fir_error_pos, fir_error_neg;
  logic pcm_valid_pos, pcm_valid_neg;
  ///////////////////////////////////////////////

  // Get active low rst.
  assign rst_n = ~rst_i;

  // Synchronize the microphone clock and generate an enable signal for sampling.
  always_ff @(posedge clk_i) begin
    if (rst_i) begin
      mic_clk_step   <= 1'b0;
      mic_clk_stable <= 1'b0;
    end else begin
      mic_clk_step   <= mic_clk_i;
      mic_clk_stable <= mic_clk_step;
    end
  end

  // Get the previous value of mic_clk_stable to detect edges.
  always_ff @(posedge clk_i) begin
    if (rst_i) begin
      mic_clk_stable_prev <= 1'b0;
    end else begin
      mic_clk_stable_prev <= mic_clk_stable;
    end
  end

  // Detect an edge on mic_clk.
  assign mic_clk_rising  = (~mic_clk_stable_prev & mic_clk_stable);
  assign mic_clk_falling = (mic_clk_stable_prev & ~mic_clk_stable);

  // Capture each mic after the datasheet DATA timing has elapsed.
  always_ff @(posedge clk_i) begin
    if (rst_i) pos_capture_cntr <= '0;
    else if (~mic_clk_val_i) pos_capture_cntr <= '0;
    else if (mic_clk_falling) pos_capture_cntr <= MIC_CAPTURE_DELAY_CYCLES;
    else if (pos_capture_cntr != '0) pos_capture_cntr <= pos_capture_cntr - 1'b1;
  end

  // Pulse when the counter is about to expire so the data is sampled once per mic edge.
  assign pos_pdm_cap = (pos_capture_cntr == 1'b1);

  always_ff @(posedge clk_i) begin
    if (rst_i) neg_capture_cntr <= '0;
    else if (~mic_clk_val_i) neg_capture_cntr <= '0;
    else if (mic_clk_rising) neg_capture_cntr <= MIC_CAPTURE_DELAY_CYCLES;
    else if (neg_capture_cntr != '0) neg_capture_cntr <= neg_capture_cntr - 1'b1;
  end

  // Pulse when the counter is about to expire so the data is sampled once per mic edge.
  assign neg_pdm_cap = (neg_capture_cntr == 1'b1);

  always_ff @(posedge clk_i) begin
    if (rst_i) data_in_pos <= 2'h0;
    else if (pos_pdm_cap) data_in_pos <= (mic_data_i) ? 2'b01 : 2'b11;
    else data_in_pos <= 2'h0;
  end

  always_ff @(posedge clk_i) begin
    if (rst_i) data_in_neg <= 2'h0;
    else if (neg_pdm_cap) data_in_neg <= (mic_data_i) ? 2'b01 : 2'b11;
    else data_in_neg <= 2'h0;
  end

  always_ff @(posedge clk_i) begin
    if (rst_i) pdm_pos_valid <= 1'b0;
    else if (pos_pdm_cap) pdm_pos_valid <= 1'b1;
    else pdm_pos_valid <= 1'b0;
  end

  always_ff @(posedge clk_i) begin
    if (rst_i) pdm_neg_valid <= 1'b0;
    else if (neg_pdm_cap) pdm_neg_valid <= 1'b1;
    else pdm_neg_valid <= 1'b0;
  end

  // CIC for Mic High (sampled on falling Edge)
  Cic_Decimator_192 iPOS_MIC (
      .clk    (clk_i),
      .reset_n(rst_n),

      .in_error (2'b00),
      .in_data  (data_in_pos),
      .in_valid (pdm_pos_valid),
      .out_ready(fir_pos_ready),  // Backpressure from FIR filter

      .in_ready (),
      .out_data (cic_out_pos),
      .out_valid(cic_valid_pos),
      .out_error(cic_error_pos)
  );

  // CIC for Mic Low (sampled on rising Edge)
  Cic_Decimator_192 iNEG_MIC (
      .clk    (clk_i),
      .reset_n(rst_n),

      .in_error (2'b00),
      .in_data  (data_in_neg),
      .in_valid (pdm_neg_valid),
      .out_ready(fir_neg_ready),  // Backpressure from FIR filter

      .in_ready (),
      .out_data (cic_out_neg),
      .out_valid(cic_valid_neg),
      .out_error(cic_error_neg)
  );

  // The generated FIR uses the two bits directly above the 18-bit data sample
  // for bank selection. The upper two extension bits stay at 0.
  always_comb begin
    fir_bank_sel = {2'b00, freq_sel_i};
  end

  // Package the input to the FIR filter with the frequency band selection for compensation.
  always_ff @(posedge clk_i) begin
    if (rst_i) begin
      fir_in_pos <= '0;
      cic_error_pos_q <= '0;
    end else if (cic_valid_pos) begin
      fir_in_pos <= {fir_bank_sel, cic_out_pos};
      cic_error_pos_q <= cic_error_pos;
    end else begin
      fir_in_pos <= '0;
      cic_error_pos_q <= '0;
    end
  end

  always_ff @(posedge clk_i) begin
    if (rst_i) begin
      fir_in_neg <= '0;
      cic_error_neg_q <= '0;
    end else if (cic_valid_neg) begin
      fir_in_neg <= {fir_bank_sel, cic_out_neg};
      cic_error_neg_q <= cic_error_neg;
    end else begin
      fir_in_neg <= '0;
      cic_error_neg_q <= '0;
    end
  end

  // Delay the CIC valid signals to align with the FIR input data.
  always_ff @(posedge clk_i) begin
    if (rst_i) cic_valid_pos_q <= 1'b0;
    else cic_valid_pos_q <= cic_valid_pos;
  end

  always_ff @(posedge clk_i) begin
    if (rst_i) cic_valid_neg_q <= 1'b0;
    else cic_valid_neg_q <= cic_valid_neg;
  end

  // Instantiate the POS FIR filter.
  FIR iPOS_FIR (
      .clk    (clk_i),
      .reset_n(rst_n),

      // input stream
      .ast_sink_data (fir_in_pos),
      .ast_sink_valid(cic_valid_pos_q),
      .ast_sink_error(cic_error_pos_q),
      .ast_sink_ready(fir_pos_ready),

      // output stream
      .ast_source_data (comp_out_pos),
      .ast_source_valid(output_valid_pos),
      .ast_source_error(fir_error_pos),
      .ast_source_ready(pos_pcm_cap_rdy_i)
  );

  // Instantiate the NEG FIR filter.
  FIR iNEG_FIR (
      .clk    (clk_i),
      .reset_n(rst_n),

      // input stream
      .ast_sink_data (fir_in_neg),
      .ast_sink_valid(cic_valid_neg_q),
      .ast_sink_error(cic_error_neg_q),
      .ast_sink_ready(fir_neg_ready),

      // output stream
      .ast_source_data (comp_out_neg),
      .ast_source_valid(output_valid_neg),
      .ast_source_error(fir_error_neg),
      .ast_source_ready(neg_pcm_cap_rdy_i)
  );

  // Convert the FIR output to 16-bit PCM with saturation logic.
  function automatic logic signed [15:0] fir41_to_pcm16(input logic signed [40:0] fir_sample);
    logic sign_bit;
    logic positive_overflow;
    logic negative_overflow;

    begin
      // The FIR output is a 41-bit signed fixed point value. Bits [30:15] represent the scaled PCM value after shifting right by 15. Bit 30 is the sign bit for the PCM output.
      sign_bit = fir_sample[30];

      // After shifting right by 15, bit 30 becomes the 16-bit PCM sign bit.
      // Bits [40:31] must all match bit 30. If not, saturation is needed.
      positive_overflow = ~sign_bit & (|fir_sample[40:31]);
      negative_overflow = sign_bit & (~&fir_sample[40:31]);

      if (positive_overflow) begin
        fir41_to_pcm16 = 16'sh7FFF;
      end else if (negative_overflow) begin
        fir41_to_pcm16 = 16'sh8000;
      end else begin
        fir41_to_pcm16 = fir_sample[30:15];
      end
    end
  endfunction

  // The PCM output is valid when the FIR output is valid and that there are no errors from the FIR filter before asserting valid.
  assign pcm_valid_pos = output_valid_pos && (fir_error_pos == 2'b00);
  assign pcm_valid_neg = output_valid_neg && (fir_error_neg == 2'b00);

  // Register the final PCM pos outputs and valid signals, applying backpressure from the capture interface.
  always_ff @(posedge clk_i) begin
    if (rst_i) begin
      pcm_pos_o       <= 16'sh0;
      pcm_valid_pos_o <= 1'b0;
    end else begin
      pcm_valid_pos_o <= pcm_valid_pos;

      if (pcm_valid_pos) begin
        pcm_pos_o <= fir41_to_pcm16($signed(comp_out_pos));
      end
    end
  end

  // Register the final PCM negoutputs and valid signals, applying backpressure from the capture interface.
  always_ff @(posedge clk_i) begin
    if (rst_i) begin
      pcm_neg_o       <= 16'sh0;
      pcm_valid_neg_o <= 1'b0;
    end else begin
      pcm_valid_neg_o <= pcm_valid_neg;

      if (pcm_valid_neg) begin
        pcm_neg_o <= fir41_to_pcm16($signed(comp_out_neg));
      end
    end
  end

endmodule
