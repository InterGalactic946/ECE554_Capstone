`timescale 1ns / 1ps
// ------------------------------------------------------------
// Module: Pdm_To_Pcm
// Description: Converts PDM data from two microphones (Hi-Mic
//              and Lo-Mic) into PCM format. The module samples
//              the PDM data, processes it through a CIC decimator,
//              and applies FIR compensation to produce the final
//              PCM output. The design supports both single and dual
//              microphone modes based on the mic_mode input.
// Author: Nate Parmley
// Date: 04-01-2026
// ------------------------------------------------------------
module Pdm_To_Pcm (
    input logic clk_i,
    input logic rst_i,
    input logic mic_clk_i,
    input logic mic_clk_val_i,
    input logic mic_data_i,
    input logic pos_pcm_cap_rdy_i,
    input logic neg_pcm_cap_rdy_i,

    output logic signed [15:0] pcm_pos_o,
    output logic pcm_valid_pos_o,
    output logic signed [15:0] pcm_neg_o,
    output logic pcm_valid_neg_o
);

  /////////////////////////////////////////////////
  // Declare any internal signals as type logic //
  ///////////////////////////////////////////////
  logic rst_n;
  logic mic_clk_step, mic_clk_stable;
  logic mic_clk_stable_prev;
  logic mic_clk_en;
  logic mic_clk_rising, mic_clk_falling;
  logic pdm_pos_valid, pdm_neg_valid;
  logic pdm_pos, pdm_neg;
  logic [1:0] data_in_pos, data_in_neg;
  logic cic_valid_pos, cic_valid_neg;
  logic [17:0] cic_out_pos, cic_out_neg;
  logic [1:0] cic_error_pos, cic_error_neg;
  logic fir_pos_ready, fir_neg_ready;
  logic [40:0] comp_out_pos, comp_out_neg;
  logic output_valid_pos, output_valid_neg;
  logic fir_error_pos, fir_error_neg;
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
  assign mic_clk_rising = (~mic_clk_stable_prev & mic_clk_stable);
  assign mic_clk_falling = (mic_clk_stable_prev & ~mic_clk_stable);
  assign mic_clk_en = mic_clk_rising | mic_clk_falling;

  // 1-cycle delay to align valid signals with DDIO output latency
  always_ff @(posedge clk_i) begin
    if (rst_i) begin
      pdm_pos_valid <= 1'b0;
      pdm_neg_valid <= 1'b0;
    end else begin
      // Mic (High) is valid after falling edge
      pdm_pos_valid <= mic_clk_falling & mic_clk_val_i;
      // Mic (Low) is valid on rising edge
      pdm_neg_valid <= mic_clk_rising & mic_clk_val_i;
    end
  end

  // Instantiate the PDM data sampler.
  // NOTE: We latch the Hi-Mic's data on clk low and the Lo-Mic's data
  // on clk high to ensure we capture the correct bits for each mic mode.
  Mic_Data_In iPDM_Sampler (
      .inclock(clk_i),
      .sclr(rst_i),
      .inclocken(mic_clk_en),
      .datain(mic_data_i),

      .dataout_h(pdm_neg),
      .dataout_l(pdm_pos)
  );

  // Convert the latched PDM bits into 2-bit values for the CIC decimator.
  // If pdm data is 1, we input 2'b01 to represent a positive pulse;
  // if it's 0, we input 2'b11 to represent a negative pulse.
  always_ff @(posedge clk_i) begin
    if (rst_i) begin
      data_in_pos <= 2'b00;
      data_in_neg <= 2'b00;
    end else begin
      // Makes data_in stable for the CIC exactly when the valid pulses are high
      data_in_pos <= (pdm_pos) ? 2'b01 : 2'b11;
      data_in_neg <= (pdm_neg) ? 2'b01 : 2'b11;
    end
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

  // Instantiate the POS FIR filter.
  FIR iPOS_FIR (
      .clk    (clk_i),
      .reset_n(rst_n),

      // input stream
      .ast_sink_data (cic_out_pos),
      .ast_sink_valid(cic_valid_pos),
      .ast_sink_error(cic_error_pos),
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
      .ast_sink_data (cic_out_neg),
      .ast_sink_valid(cic_valid_neg),
      .ast_sink_error(cic_error_neg),
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

  // The PCM output is valid when the FIR output is valid and the capture interface is ready to accept data and
  // we also check that there are no errors from the FIR filter before asserting valid.
  assign pcm_valid_pos = output_valid_pos && pos_pcm_cap_rdy_i && (fir_error_pos == 2'b00);
  assign pcm_valid_neg = output_valid_neg && neg_pcm_cap_rdy_i && (fir_error_neg == 2'b00);

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
