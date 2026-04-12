`timescale 1ns / 1ps
// ------------------------------------------------------------
// Package: Pdm_To_Pcm_Tb_pkg
// Description: Shared helper functions/tasks for the
//              Pdm_To_Pcm_tb testbench. These helpers keep the
//              tone-analysis code out of the main directed test
//              sequence while preserving the same checks.
// Author: Srivibhav Jonnalagadda
// Date: 04-12-2026
// ------------------------------------------------------------
package Pdm_To_Pcm_Tb_pkg;

  import Tb_Util_pkg::*;

  /////////////////////////////////////
  // ADC helper: voltage -> ADC code //
  /////////////////////////////////////

  // Convert a real-valued rail into the 12-bit ADC code read by the AFE.
  function automatic logic [11:0] voltage_to_adc_code(input real voltage_v);
    // Clamped copy of the input voltage.
    real clamped_v;

    // Integer code after scaling into the ADC range.
    integer scaled_code;
    begin
      // Start from the requested input voltage.
      clamped_v = voltage_v;

      // Clamp low end to 0 V.
      if (clamped_v < 0.0) begin
        clamped_v = 0.0;
      end
      // Clamp high end to 5 V.
      else if (clamped_v > 5.0) begin
        clamped_v = 5.0;
      end

      // Scale 0..5 V into 0..4095 and round to nearest integer.
      scaled_code = $rtoi(((clamped_v / 5.0) * 4095.0) + 0.5);

      // Return only the lower 12 bits.
      voltage_to_adc_code = scaled_code[11:0];
    end
  endfunction : voltage_to_adc_code

  //////////////////////////////////////////
  // Utility task: clear PCM capture      //
  //////////////////////////////////////////

  // Pulse clr_capture long enough to clear the sample-collection state.
  task automatic clear_pcm_capture(ref logic clk, ref logic clr_capture);
    begin
      @(negedge clk);
      clr_capture = 1'b1;

      @(negedge clk);
      clr_capture = 1'b0;
    end
  endtask : clear_pcm_capture

  //////////////////////////////////////////
  // Utility task: wait for PCM samples   //
  //////////////////////////////////////////

  // Wait until both channels have collected enough samples.
  task automatic wait_for_pcm_samples(ref logic clk, ref int error_count,
                                      ref logic pcm_samples_ready,
                                      input int unsigned pcm_timeout_cycles,
                                      input string label);
    WaitTask(clk, error_count, pcm_samples_ready, pcm_timeout_cycles, label);
  endtask : wait_for_pcm_samples

  //////////////////////////////////////////
  // Utility task: reset quiet check      //
  //////////////////////////////////////////

  // Immediately after reset, output-valid should be low on both channels.
  task automatic check_outputs_quiet(ref int error_count, input logic pcm_valid_pos_o,
                                     input logic pcm_valid_neg_o);
    begin
      if (pcm_valid_pos_o !== 1'b0) begin
        $error("ERROR: pcm_valid_pos_o is not low immediately after reset!");
        error_count += 1;
      end

      if (pcm_valid_neg_o !== 1'b0) begin
        $error("ERROR: pcm_valid_neg_o is not low immediately after reset!");
        error_count += 1;
      end
    end
  endtask : check_outputs_quiet

  //////////////////////////////////////////
  // Utility task: request ULTRASONIC     //
  //////////////////////////////////////////

  // Power the mic rail, request ULTRASONIC mode, and wait for the AFE to settle.
  task automatic request_ult_mode(ref logic clk, ref int error_count,
                                  ref logic [1:0] mode_req, input logic [1:0] mode_ult,
                                  ref real vdd_v, input real mic_vdd_on_v,
                                  ref logic dut_volt_on_hi, ref logic curr_mode_ult,
                                  ref logic data_val, input int unsigned powerup_cycles,
                                  input int unsigned fsm_margin_cycles,
                                  input int unsigned mode_change_cycles);
    begin
      @(negedge clk) begin
        mode_req = mode_ult;
        set_vdd(vdd_v, mic_vdd_on_v);
      end

      WaitTask(clk, error_count, dut_volt_on_hi,
               powerup_cycles + fsm_margin_cycles,
               "Audio Front End ADC-derived volt_on");

      WaitTask(clk, error_count, curr_mode_ult,
               powerup_cycles + fsm_margin_cycles + mode_change_cycles,
               "ULTRASONIC mic mode");

      WaitTask(clk, error_count, data_val,
               powerup_cycles + fsm_margin_cycles,
               "ULTRASONIC mic data valid");
    end
  endtask : request_ult_mode

  //////////////////////////////////////////
  // Analysis function: peak-to-peak      //
  //////////////////////////////////////////

  // Compute peak-to-peak swing over the final analysis window.
  function automatic real calc_pcm_swing(input logic signed [15:0] samples[],
                                         input int sample_count,
                                         input int unsigned tone_check_samples);
    // First index of the steady-state analysis window.
    int start_idx;

    // One-past-last index of the analysis window.
    int stop_idx;

    // Loop index.
    int idx;

    // Current sample converted to real for comparison.
    real sample_value;

    // Running minimum sample in the window.
    real min_sample;

    // Running maximum sample in the window.
    real max_sample;
    begin
      // End of window is the current sample count.
      stop_idx = sample_count;

      // Start of window is one analysis window earlier.
      start_idx = sample_count - tone_check_samples;

      // Initialize min/max from the first sample in the window.
      min_sample = real'(samples[start_idx]);
      max_sample = min_sample;

      // Sweep the analysis window and update min/max.
      for (idx = start_idx; idx < stop_idx; idx += 1) begin
        sample_value = real'(samples[idx]);
        if (sample_value < min_sample) min_sample = sample_value;
        if (sample_value > max_sample) max_sample = sample_value;
      end

      // Return peak-to-peak swing.
      calc_pcm_swing = max_sample - min_sample;
    end
  endfunction : calc_pcm_swing

  //////////////////////////////////////////
  // Analysis function: tone correlation  //
  //////////////////////////////////////////

  // Correlate captured PCM samples against the expected test tone using the
  // measured sample timestamps.
  function automatic real calc_tone_corr(input logic signed [15:0] samples[],
                                         input realtime sample_time_ns[],
                                         input int sample_count,
                                         input int unsigned tone_check_samples,
                                         input int unsigned tone_freq_hz);
    // First index of the final steady-state analysis window.
    int start_idx;

    // One-past-last index of the analysis window.
    int stop_idx;

    // Loop index.
    int idx;

    // Mean of the selected analysis window.
    real mean;

    // Current sample after DC removal.
    real centered_sample;

    // Reference tone phase at this sample time.
    real angle_rad;

    // Correlation accumulator against sine reference.
    real sin_accum;

    // Correlation accumulator against cosine reference.
    real cos_accum;

    // Energy of captured samples after DC removal.
    real sample_energy;

    // Energy of the unit-amplitude reference basis.
    real ref_energy;

    // Sample timestamp converted from ns to seconds.
    real time_s;
    begin
      // Define the final steady-state analysis window.
      stop_idx = sample_count;
      start_idx = sample_count - tone_check_samples;

      // Initialize accumulators.
      mean = 0.0;
      sin_accum = 0.0;
      cos_accum = 0.0;
      sample_energy = 0.0;
      ref_energy = 0.0;

      // First pass: compute the mean so DC does not affect tone correlation.
      for (idx = start_idx; idx < stop_idx; idx += 1) begin
        mean += real'(samples[idx]);
      end

      // Normalize the sum into the average.
      mean = mean / real'(tone_check_samples);

      // Second pass: correlate against sine and cosine references.
      for (idx = start_idx; idx < stop_idx; idx += 1) begin
        // Remove DC component from the current sample.
        centered_sample = real'(samples[idx]) - mean;

        // Convert timestamp from ns to seconds.
        time_s = sample_time_ns[idx] * 1.0e-9;

        // Compute reference phase for the expected test tone.
        angle_rad = 6.283185307179586 * real'(tone_freq_hz) * time_s;

        // Accumulate projection onto sine reference.
        sin_accum += centered_sample * $sin(angle_rad);

        // Accumulate projection onto cosine reference.
        cos_accum += centered_sample * $cos(angle_rad);

        // Accumulate captured-signal energy.
        sample_energy += centered_sample * centered_sample;

        // Unit-amplitude sine/cosine basis contributes one reference-energy unit.
        ref_energy += 1.0;
      end

      // Guard against divide-by-zero in pathological cases.
      if ((sample_energy == 0.0) || (ref_energy == 0.0)) begin
        calc_tone_corr = 0.0;
      end else begin
        // Return normalized correlation magnitude.
        calc_tone_corr =
            $sqrt((sin_accum * sin_accum) + (cos_accum * cos_accum)) /
            $sqrt(sample_energy * ref_energy);
      end
    end
  endfunction : calc_tone_corr

  //////////////////////////////////////////
  // Utility task: check one channel      //
  //////////////////////////////////////////

  // Evaluate one channel as either a pass-band or stop-band result.
  task automatic check_pcm_channel(
      ref    int                  error_count,
      input  logic signed [15:0]  samples[],
      input  realtime             sample_time_ns[],
      input  int                  sample_count,
      input  int unsigned         tone_total_samples,
      input  int unsigned         tone_check_samples,
      input  int unsigned         tone_freq_hz,
      input  int unsigned         min_pass_swing,
      input  real                 min_tone_corr,
      input  real                 max_stop_tone_ratio,
      input  bit                  expect_pass,
      input  real                 pass_tone,
      input  string               label,
      output real                 measured_swing,
      output real                 measured_tone
  );
    // Correlation magnitude against the expected tone.
    real tone_corr;

    // Allowed tone limit when this band is expected to reject the tone.
    real stop_limit;
    begin
      // Fail immediately if there are not enough samples.
      if (sample_count < tone_total_samples) begin
        $error("ERROR: %s captured only %0d PCM samples.", label, sample_count);
        error_count += 1;
        measured_swing = 0.0;
        measured_tone = 0.0;
        return;
      end

      // Measure peak-to-peak amplitude.
      measured_swing = calc_pcm_swing(samples, sample_count, tone_check_samples);

      // Measure normalized correlation to the known tone.
      tone_corr = calc_tone_corr(samples, sample_time_ns, sample_count,
                                 tone_check_samples, tone_freq_hz);

      // Use swing * correlation as a simple "tone strength" metric.
      measured_tone = measured_swing * tone_corr;

      // Stop-band threshold is relative to the remembered pass-band tone strength.
      stop_limit = pass_tone * max_stop_tone_ratio;

      // Print measured metrics for visibility in the transcript.
      $display("%s swing: %.1f, %0d Hz correlation: %.3f, tone level: %.1f.",
               label, measured_swing, tone_freq_hz, tone_corr, measured_tone);

      // Pass-band expectations.
      if (expect_pass) begin
        // A passed tone should have nontrivial swing.
        if (measured_swing < real'(min_pass_swing)) begin
          $error("ERROR: %s PCM swing is too small for the pass band.", label);
          error_count += 1;
        end

        // A passed tone should also correlate with the expected frequency.
        if (tone_corr < min_tone_corr) begin
          $error("ERROR: %s does not correlate with the expected %0d Hz tone.",
                 label, tone_freq_hz);
          error_count += 1;
        end
      end
      // Stop-band expectations.
      else begin
        // A rejected tone must be sufficiently attenuated relative to the pass-band result.
        if (measured_tone > stop_limit) begin
          $error("ERROR: %s did not attenuate the %0d Hz tone enough.",
                 label, tone_freq_hz);
          error_count += 1;
        end
      end
    end
  endtask : check_pcm_channel

  //////////////////////////////////////////
  // Utility task: check both channels    //
  //////////////////////////////////////////

  // Evaluate both positive and negative channels for the current FIR band.
  task automatic check_pcm_band(
      ref    int                  error_count,
      input  string               label,
      input  bit                  expect_pass,
      input  logic signed [15:0]  pos_samples[],
      input  realtime             pos_sample_time_ns[],
      input  int                  pos_sample_count,
      input  logic signed [15:0]  neg_samples[],
      input  realtime             neg_sample_time_ns[],
      input  int                  neg_sample_count,
      input  int unsigned         tone_total_samples,
      input  int unsigned         tone_check_samples,
      input  int unsigned         tone_freq_hz,
      input  int unsigned         min_pass_swing,
      input  real                 min_tone_corr,
      input  real                 max_stop_tone_ratio,
      ref    real                 pos_pass_tone,
      ref    real                 neg_pass_tone
  );
    // Measured positive swing for this band.
    real pos_swing;

    // Measured negative swing for this band.
    real neg_swing;

    // Measured positive tone strength for this band.
    real pos_tone;

    // Measured negative tone strength for this band.
    real neg_tone;
    begin
      // Check positive channel first.
      check_pcm_channel(error_count, pos_samples, pos_sample_time_ns,
                        pos_sample_count, tone_total_samples,
                        tone_check_samples, tone_freq_hz, min_pass_swing,
                        min_tone_corr, max_stop_tone_ratio, expect_pass,
                        pos_pass_tone, {label, " POS channel"},
                        pos_swing, pos_tone);

      // Check negative channel next.
      check_pcm_channel(error_count, neg_samples, neg_sample_time_ns,
                        neg_sample_count, tone_total_samples,
                        tone_check_samples, tone_freq_hz, min_pass_swing,
                        min_tone_corr, max_stop_tone_ratio, expect_pass,
                        neg_pass_tone, {label, " NEG channel"},
                        neg_swing, neg_tone);

      // If this band is the pass band, remember its tone strength so later
      // stop-band checks can compare against it.
      if (expect_pass) begin
        pos_pass_tone = pos_tone;
        neg_pass_tone = neg_tone;
      end
    end
  endtask : check_pcm_band

endpackage : Pdm_To_Pcm_Tb_pkg
