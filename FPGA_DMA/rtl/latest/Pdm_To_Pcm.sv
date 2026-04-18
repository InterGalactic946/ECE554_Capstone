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

    // 3'h0: 10kHz to 18kHz Band
    // 3'h1: 18kHz to 25kHz Band
    // 3'h2: 25kHz to 32kHz Band
    // 3'h3: 32kHz to 40kHz Band
    // 3'h4: 0kHz to 10kHz Band
    // Others invalid.
    input logic [2:0] freq_sel_i,

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
  localparam int unsigned MIC_DATA_SAMPLE_GUARD_NS = 90;

  // Total time for data to settle.
  localparam int unsigned MIC_DATA_SETTLE_NS = MIC_TDD_MAX_NS + MIC_DATA_SAMPLE_GUARD_NS;

  // Calculate the number of system clock cycles needed to meet the data settle time.
  localparam int unsigned MIC_DATA_SETTLE_CYCLES =
      (MIC_DATA_SETTLE_NS + SYS_CLK_PERIOD_NS - 1) / SYS_CLK_PERIOD_NS;

  // Set the capture cycles of the data after the mic clock edge to ensure we sample after the data is stable.
  localparam int unsigned MIC_CAPTURE_DELAY_CYCLES = (MIC_DATA_SETTLE_CYCLES - 1);
  localparam int unsigned MIC_CAPTURE_COUNTER_W = $clog2(MIC_CAPTURE_DELAY_CYCLES + 1);

  ///////////////////////////////////
  // Declare any internal signals //
  /////////////////////////////////
  ////////////////////////////// Clock/Capture Logic //////////////////////////////////////
  logic rst_n;  // Active-low reset for generated IP blocks.
  logic mic_clk_step;  // First synchronizer stage for the microphone clock.
  logic mic_clk_stable;  // Second synchronizer stage for edge detection.
  logic mic_clk_stable_prev;  // Previous synchronized microphone clock value.
  logic mic_clk_rising;  // Indicates a synchronized rising edge on mic_clk_i.
  logic mic_clk_falling;  // Indicates a synchronized falling edge on mic_clk_i.
  logic [MIC_CAPTURE_COUNTER_W-1:0] pos_capture_cntr; // Wait counter for positive-channel PDM capture.
  logic [MIC_CAPTURE_COUNTER_W-1:0] neg_capture_cntr; // Wait counter for negative-channel PDM capture.
  logic pos_pdm_cap;  // Pulses when positive-channel PDM should be sampled.
  logic neg_pdm_cap;  // Pulses when negative-channel PDM should be sampled.
  ////////////////////////////// PDM Sample Logic /////////////////////////////////////////
  logic pdm_pos_valid;  // Valid pulse for positive-channel PDM sample.
  logic pdm_neg_valid;  // Valid pulse for negative-channel PDM sample.
  logic signed [1:0] data_in_pos;  // Signed 2-bit PDM sample sent to positive CIC inputs.
  logic signed [1:0] data_in_neg;  // Signed 2-bit PDM sample sent to negative CIC inputs.
  ////////////////////////////// 48 kHz CIC/FIR Path //////////////////////////////////////
  logic [19:0] cic_48_out_pos;  // Positive-channel output from the 48 kHz CIC.
  logic [19:0] cic_48_out_neg;  // Negative-channel output from the 48 kHz CIC.
  logic cic_48_valid_pos;  // Positive-channel valid from the 48 kHz CIC.
  logic cic_48_valid_neg;  // Negative-channel valid from the 48 kHz CIC.
  logic cic_48_valid_pos_q;  // Delayed positive 48 kHz valid aligned to FIR input.
  logic cic_48_valid_neg_q;  // Delayed negative 48 kHz valid aligned to FIR input.
  logic [1:0] cic_48_error_pos;  // Positive-channel error from the 48 kHz CIC.
  logic [1:0] cic_48_error_neg;  // Negative-channel error from the 48 kHz CIC.
  logic [1:0] cic_48_error_pos_q;  // Registered positive 48 kHz CIC error for FIR input.
  logic [1:0] cic_48_error_neg_q;  // Registered negative 48 kHz CIC error for FIR input.
  logic fir_48_pos_ready;  // Backpressure ready from positive FIR_48 sink.
  logic fir_48_neg_ready;  // Backpressure ready from negative FIR_48 sink.
  logic fir_48_pos_source_ready;  // Ready into positive FIR_48 source output.
  logic fir_48_neg_source_ready;  // Ready into negative FIR_48 source output.
  logic [19:0] fir_48_in_pos;  // Positive-channel input sample for FIR_48.
  logic [19:0] fir_48_in_neg;  // Negative-channel input sample for FIR_48.
  logic [42:0] comp_48_out_pos;  // Positive-channel compensated output from FIR_48.
  logic [42:0] comp_48_out_neg;  // Negative-channel compensated output from FIR_48.
  logic output_48_valid_pos;  // Positive-channel valid from FIR_48.
  logic output_48_valid_neg;  // Negative-channel valid from FIR_48.
  logic [1:0] fir_48_error_pos;  // Positive-channel error from FIR_48.
  logic [1:0] fir_48_error_neg;  // Negative-channel error from FIR_48.
  ////////////////////////////// 192 kHz CIC/FIR Path /////////////////////////////////////
  logic [17:0] cic_192_out_pos;  // Positive-channel output from the 192 kHz CIC.
  logic [17:0] cic_192_out_neg;  // Negative-channel output from the 192 kHz CIC.
  logic cic_192_valid_pos;  // Positive-channel valid from the 192 kHz CIC.
  logic cic_192_valid_neg;  // Negative-channel valid from the 192 kHz CIC.
  logic cic_192_valid_pos_q;  // Delayed positive 192 kHz valid aligned to FIR input.
  logic cic_192_valid_neg_q;  // Delayed negative 192 kHz valid aligned to FIR input.
  logic [1:0] cic_192_error_pos;  // Positive-channel error from the 192 kHz CIC.
  logic [1:0] cic_192_error_neg;  // Negative-channel error from the 192 kHz CIC.
  logic [1:0] cic_192_error_pos_q;  // Registered positive 192 kHz CIC error for FIR input.
  logic [1:0] cic_192_error_neg_q;  // Registered negative 192 kHz CIC error for FIR input.
  logic fir_192_pos_ready;  // Backpressure ready from positive FIR_192 sink.
  logic fir_192_neg_ready;  // Backpressure ready from negative FIR_192 sink.
  logic fir_192_pos_source_ready;  // Ready into positive FIR_192 source output.
  logic fir_192_neg_source_ready;  // Ready into negative FIR_192 source output.
  logic [3:0] fir_192_bank_sel;  // FIR_192 bank select for the 10-40 kHz bands.
  logic [21:0] fir_192_in_pos;  // Positive-channel bank/sample input for FIR_192.
  logic [21:0] fir_192_in_neg;  // Negative-channel bank/sample input for FIR_192.
  logic [40:0] comp_192_out_pos;  // Positive-channel compensated output from FIR_192.
  logic [40:0] comp_192_out_neg;  // Negative-channel compensated output from FIR_192.
  logic output_192_valid_pos;  // Positive-channel valid from FIR_192.
  logic output_192_valid_neg;  // Negative-channel valid from FIR_192.
  logic [1:0] fir_192_error_pos;  // Positive-channel error from FIR_192.
  logic [1:0] fir_192_error_neg;  // Negative-channel error from FIR_192.
  ////////////////////////////// Output Selection Logic ///////////////////////////////////
  logic [40:0] comp_out_pos;  // Selected positive-channel FIR output.
  logic [40:0] comp_out_neg;  // Selected negative-channel FIR output.
  logic output_valid_pos;  // Selected positive-channel FIR valid.
  logic output_valid_neg;  // Selected negative-channel FIR valid.
  logic [1:0] fir_error_pos;  // Selected positive-channel FIR error.
  logic [1:0] fir_error_neg;  // Selected negative-channel FIR error.
  logic use_fir_48;  // Indicates that the selected output path is FIR_48.
  ////////////////////////////// PCM Output Logic /////////////////////////////////////////
  logic pcm_valid_pos;  // Final positive-channel PCM valid before output register.
  logic pcm_valid_neg;  // Final negative-channel PCM valid before output register.
  ////////////////////////////////////////////////////////////////////////////////////////

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
    else if (mic_clk_rising) pos_capture_cntr <= MIC_CAPTURE_DELAY_CYCLES;
    else if (pos_capture_cntr != '0) pos_capture_cntr <= pos_capture_cntr - 1'b1;
  end

  // Pulse when the counter is about to expire so the data is sampled once per mic edge.
  assign pos_pdm_cap = (pos_capture_cntr == 1'b1);

  always_ff @(posedge clk_i) begin
    if (rst_i) neg_capture_cntr <= '0;
    else if (~mic_clk_val_i) neg_capture_cntr <= '0;
    else if (mic_clk_falling) neg_capture_cntr <= MIC_CAPTURE_DELAY_CYCLES;
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

  // 48 kHz CIC for Mic High (sampled on rising edge)
  Cic_Decimator_48 iPOS_MIC_48 (
      .clk    (clk_i),
      .reset_n(rst_n),

      .in_error (2'b00),
      .in_data  (data_in_pos),
      .in_valid (pdm_pos_valid),
      .out_ready(fir_48_pos_ready), // Backpressure from FIR_48 filter

      .in_ready (),
      .out_data (cic_48_out_pos),
      .out_valid(cic_48_valid_pos),
      .out_error(cic_48_error_pos)
  );

  // 48 kHz CIC for Mic Low (sampled on falling edge)
  Cic_Decimator_48 iNEG_MIC_48 (
      .clk    (clk_i),
      .reset_n(rst_n),

      .in_error (2'b00),
      .in_data  (data_in_neg),
      .in_valid (pdm_neg_valid),
      .out_ready(fir_48_neg_ready), // Backpressure from FIR_48 filter

      .in_ready (),
      .out_data (cic_48_out_neg),
      .out_valid(cic_48_valid_neg),
      .out_error(cic_48_error_neg)
  );

  // 192 kHz CIC for Mic High (sampled on rising edge)
  Cic_Decimator_192 iPOS_MIC_192 (
      .clk    (clk_i),
      .reset_n(rst_n),

      .in_error (2'b00),
      .in_data  (data_in_pos),
      .in_valid (pdm_pos_valid),
      .out_ready(fir_192_pos_ready), // Backpressure from FIR_192 filter

      .in_ready (),
      .out_data (cic_192_out_pos),
      .out_valid(cic_192_valid_pos),
      .out_error(cic_192_error_pos)
  );

  // 192 kHz CIC for Mic Low (sampled on falling edge)
  Cic_Decimator_192 iNEG_MIC_192 (
      .clk    (clk_i),
      .reset_n(rst_n),

      .in_error (2'b00),
      .in_data  (data_in_neg),
      .in_valid (pdm_neg_valid),
      .out_ready(fir_192_neg_ready), // Backpressure from FIR_192 filter

      .in_ready (),
      .out_data (cic_192_out_neg),
      .out_valid(cic_192_valid_neg),
      .out_error(cic_192_error_neg)
  );

  // The generated FIR uses the two bits directly above the 18-bit data sample
  // for bank selection. The upper two extension bits stay at 0.
  always_comb begin
    fir_192_bank_sel = {2'b00, freq_sel_i[1:0]};
  end

  // Package the 48 kHz CIC outputs directly into the FIR_48 input streams.
  always_ff @(posedge clk_i) begin
    if (rst_i) begin
      fir_48_in_pos <= '0;
      cic_48_error_pos_q <= '0;
    end else if (cic_48_valid_pos) begin
      fir_48_in_pos <= cic_48_out_pos;
      cic_48_error_pos_q <= cic_48_error_pos;
    end else begin
      fir_48_in_pos <= '0;
      cic_48_error_pos_q <= '0;
    end
  end

  always_ff @(posedge clk_i) begin
    if (rst_i) begin
      fir_48_in_neg <= '0;
      cic_48_error_neg_q <= '0;
    end else if (cic_48_valid_neg) begin
      fir_48_in_neg <= cic_48_out_neg;
      cic_48_error_neg_q <= cic_48_error_neg;
    end else begin
      fir_48_in_neg <= '0;
      cic_48_error_neg_q <= '0;
    end
  end

  // Package the 192 kHz CIC outputs with the FIR bank selection for the 10-40 kHz bands.
  always_ff @(posedge clk_i) begin
    if (rst_i) begin
      fir_192_in_pos <= '0;
      cic_192_error_pos_q <= '0;
    end else if (cic_192_valid_pos) begin
      fir_192_in_pos <= {fir_192_bank_sel, cic_192_out_pos};
      cic_192_error_pos_q <= cic_192_error_pos;
    end else begin
      fir_192_in_pos <= '0;
      cic_192_error_pos_q <= '0;
    end
  end

  always_ff @(posedge clk_i) begin
    if (rst_i) begin
      fir_192_in_neg <= '0;
      cic_192_error_neg_q <= '0;
    end else if (cic_192_valid_neg) begin
      fir_192_in_neg <= {fir_192_bank_sel, cic_192_out_neg};
      cic_192_error_neg_q <= cic_192_error_neg;
    end else begin
      fir_192_in_neg <= '0;
      cic_192_error_neg_q <= '0;
    end
  end

  // Delay the CIC valid signals to align with the registered FIR input data.
  always_ff @(posedge clk_i) begin
    if (rst_i) cic_48_valid_pos_q <= 1'b0;
    else cic_48_valid_pos_q <= cic_48_valid_pos;
  end

  always_ff @(posedge clk_i) begin
    if (rst_i) cic_48_valid_neg_q <= 1'b0;
    else cic_48_valid_neg_q <= cic_48_valid_neg;
  end

  always_ff @(posedge clk_i) begin
    if (rst_i) cic_192_valid_pos_q <= 1'b0;
    else cic_192_valid_pos_q <= cic_192_valid_pos;
  end

  always_ff @(posedge clk_i) begin
    if (rst_i) cic_192_valid_neg_q <= 1'b0;
    else cic_192_valid_neg_q <= cic_192_valid_neg;
  end

  // Instantiate the POS FIR_48 filter.
  FIR_48 iPOS_FIR_48 (
      .clk    (clk_i),
      .reset_n(rst_n),

      // input stream
      .ast_sink_data (fir_48_in_pos),
      .ast_sink_valid(cic_48_valid_pos_q),
      .ast_sink_error(cic_48_error_pos_q),
      .ast_sink_ready(fir_48_pos_ready),

      // output stream
      .ast_source_data (comp_48_out_pos),
      .ast_source_valid(output_48_valid_pos),
      .ast_source_error(fir_48_error_pos),
      .ast_source_ready(fir_48_pos_source_ready)
  );

  // Instantiate the NEG FIR_48 filter.
  FIR_48 iNEG_FIR_48 (
      .clk    (clk_i),
      .reset_n(rst_n),

      // input stream
      .ast_sink_data (fir_48_in_neg),
      .ast_sink_valid(cic_48_valid_neg_q),
      .ast_sink_error(cic_48_error_neg_q),
      .ast_sink_ready(fir_48_neg_ready),

      // output stream
      .ast_source_data (comp_48_out_neg),
      .ast_source_valid(output_48_valid_neg),
      .ast_source_error(fir_48_error_neg),
      .ast_source_ready(fir_48_neg_source_ready)
  );

  // Instantiate the POS FIR_192 filter.
  FIR_192 iPOS_FIR_192 (
      .clk    (clk_i),
      .reset_n(rst_n),

      // input stream
      .ast_sink_data (fir_192_in_pos),
      .ast_sink_valid(cic_192_valid_pos_q),
      .ast_sink_error(cic_192_error_pos_q),
      .ast_sink_ready(fir_192_pos_ready),

      // output stream
      .ast_source_data (comp_192_out_pos),
      .ast_source_valid(output_192_valid_pos),
      .ast_source_error(fir_192_error_pos),
      .ast_source_ready(fir_192_pos_source_ready)
  );

  // Instantiate the NEG FIR_192 filter.
  FIR_192 iNEG_FIR_192 (
      .clk    (clk_i),
      .reset_n(rst_n),

      // input stream
      .ast_sink_data (fir_192_in_neg),
      .ast_sink_valid(cic_192_valid_neg_q),
      .ast_sink_error(cic_192_error_neg_q),
      .ast_sink_ready(fir_192_neg_ready),

      // output stream
      .ast_source_data (comp_192_out_neg),
      .ast_source_valid(output_192_valid_neg),
      .ast_source_error(fir_192_error_neg),
      .ast_source_ready(fir_192_neg_source_ready)
  );

  // Select the active FIR path. Unselected FIR outputs are drained so they do not backpressure stale samples.
  always_comb begin
    fir_48_pos_source_ready  = 1'b1;
    fir_48_neg_source_ready  = 1'b1;
    fir_192_pos_source_ready = 1'b1;
    fir_192_neg_source_ready = 1'b1;
    comp_out_pos             = '0;
    comp_out_neg             = '0;
    output_valid_pos         = 1'b0;
    output_valid_neg         = 1'b0;
    fir_error_pos            = 2'b00;
    fir_error_neg            = 2'b00;
    use_fir_48               = 1'b0;

    unique case (freq_sel_i)
      3'h4: begin
        fir_48_pos_source_ready = pos_pcm_cap_rdy_i;
        fir_48_neg_source_ready = neg_pcm_cap_rdy_i;
        output_valid_pos        = output_48_valid_pos;
        output_valid_neg        = output_48_valid_neg;
        fir_error_pos           = fir_48_error_pos;
        fir_error_neg           = fir_48_error_neg;
        use_fir_48              = 1'b1;
      end
      3'h0, 3'h1, 3'h2, 3'h3: begin
        fir_192_pos_source_ready = pos_pcm_cap_rdy_i;
        fir_192_neg_source_ready = neg_pcm_cap_rdy_i;
        comp_out_pos             = comp_192_out_pos;
        comp_out_neg             = comp_192_out_neg;
        output_valid_pos         = output_192_valid_pos;
        output_valid_neg         = output_192_valid_neg;
        fir_error_pos            = fir_192_error_pos;
        fir_error_neg            = fir_192_error_neg;
      end
      default: begin
        // Invalid band selections are drained but do not produce PCM output.
      end
    endcase
  end

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

  // Convert the 43-bit FIR_48 output to the same 16-bit PCM format.
  function automatic logic signed [15:0] fir43_to_pcm16(input logic signed [42:0] fir_sample);
    logic sign_bit;
    logic positive_overflow;
    logic negative_overflow;

    begin
      // FIR_48 produces two extra bits, so the 16-bit PCM window shifts up by two.
      sign_bit = fir_sample[32];

      positive_overflow = ~sign_bit & (|fir_sample[42:33]);
      negative_overflow = sign_bit & (~&fir_sample[42:33]);

      if (positive_overflow) begin
        fir43_to_pcm16 = 16'sh7FFF;
      end else if (negative_overflow) begin
        fir43_to_pcm16 = 16'sh8000;
      end else begin
        fir43_to_pcm16 = fir_sample[32:17];
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
        pcm_pos_o <= (use_fir_48) ? fir43_to_pcm16($signed(comp_48_out_pos)) :
            fir41_to_pcm16($signed(comp_out_pos));
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
        pcm_neg_o <= (use_fir_48) ? fir43_to_pcm16($signed(comp_48_out_neg)) :
            fir41_to_pcm16($signed(comp_out_neg));
      end
    end
  end

endmodule
