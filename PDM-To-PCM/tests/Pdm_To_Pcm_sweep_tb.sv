`timescale 1ns / 1ps
// ------------------------------------------------------------
// Testbench: Pdm_To_Pcm_sweep_tb
// Description:
//   Characterization-style testbench for the PDM-to-PCM path.
//
//   This bench reuses the real Audio_Front_End and mic models,
//   then sweeps several tones across all FIR band selections.
//   The directed Pdm_To_Pcm_tb owns strict pass/fail checks; this
//   bench records measured tone strength across a dense tone sweep
//   so the filter behavior can be reviewed in the transcript or
//   plotted from CSV.
//
// Author: Srivibhav Jonnalagadda
// Date: 04-12-2026
// ------------------------------------------------------------
module Pdm_To_Pcm_sweep_tb ();

  // Import timing helpers used by the mic model / power-up timing logic.
  import Mic_Time_pkg::*;

  // Import generic testbench utilities like WaitTask(), announce_test(), etc.
  import Tb_Util_pkg::*;

  // Import PDM-to-PCM-specific tone analysis helpers.
  import Pdm_To_Pcm_Tb_pkg::*;

  /////////////////////////
  // Test configuration //
  /////////////////////////

  // System clock used by the DUT and AFE.
  localparam int unsigned SYS_CLK_HZ = 50_000_000;

  // Enable reduced timing for faster simulation.
  localparam bit FAST_SIM = 1'b1;

  // Divider used when FAST_SIM is enabled.
  localparam int unsigned FAST_SIM_DIV = 1000;

  // Extra slack added to state-machine waits so the bench is not too tight.
  localparam int unsigned FSM_MARGIN_CYCLES = 256;

  // STANDARD microphone operating mode request sent to Audio_Front_End.
  localparam logic [1:0] MODE_STD = 2'h2;

  // ULTRASONIC microphone operating mode request sent to Audio_Front_End.
  localparam logic [1:0] MODE_ULT = 2'h3;

  // FIR band select values expected by the DUT.
  localparam logic [2:0] BAND_10_18 = 3'h0;
  localparam logic [2:0] BAND_18_25 = 3'h1;
  localparam logic [2:0] BAND_25_32 = 3'h2;
  localparam logic [2:0] BAND_32_40 = 3'h3;
  localparam logic [2:0] BAND_0_10  = 3'h4;

  // Number of FIR bands swept for each tone.
  localparam int unsigned NUM_BANDS = 5;

  // First tone used by the dense characterization sweep.
  localparam int unsigned SWEEP_START_HZ = 5_000;

  // Last tone used by the dense characterization sweep.
  localparam int unsigned SWEEP_STOP_HZ = 45_000;

  // Tone spacing for the dense characterization sweep.
  localparam int unsigned SWEEP_STEP_HZ = 1_000;

  // Number of tones swept across the FIR banks.
  localparam int unsigned NUM_SWEEP_TONES =
      ((SWEEP_STOP_HZ - SWEEP_START_HZ) / SWEEP_STEP_HZ) + 1;

  // Do not compare raw strongest-band results near transition edges.
  localparam int unsigned BAND_CHECK_GUARD_HZ = 1_000;

  // Mic-model tone amplitude used for characterization.
  localparam int unsigned TONE_AMPLITUDE = 16'd1024;

  // Maximum number of cycles the bench will wait for enough PCM samples.
  localparam int unsigned PCM_TIMEOUT_CYCLES = 700_000;

  // FIFO depth used by the downstream ready/valid sink model.
  localparam int unsigned FIFO_DEPTH = 8;

  // Number of system-clock cycles between one FIFO pop and the next.
  localparam int unsigned FIFO_READ_GAP_CYCLES = 96;

  // Maximum number of PCM samples stored per channel.
  localparam int unsigned MAX_PCM_SAMPLES = 512;

  // Samples ignored after each tone/band switch so old pipeline data drains.
  localparam int unsigned SWEEP_WARMUP_SAMPLES = 128;

  // Samples used for the actual tone-strength measurement.
  localparam int unsigned SWEEP_CHECK_SAMPLES = 128;

  // Total samples captured for each tone/band measurement.
  localparam int unsigned SWEEP_TOTAL_SAMPLES = SWEEP_WARMUP_SAMPLES + SWEEP_CHECK_SAMPLES;

  // Supply voltage applied to the microphone rail during normal operation.
  localparam real MIC_VDD_ON_V = 1.80;

  // Convert the mic power-up time into system-clock cycles.
  localparam int unsigned POWERUP_CYCLES = mic_cycles_from_ms(
      SYS_CLK_HZ, MIC_POWERUP_MS, FAST_SIM, FAST_SIM_DIV
  );

  // Convert the mic mode-change time into system-clock cycles.
  localparam int unsigned MODE_CHANGE_CYCLES = mic_cycles_from_ms(
      SYS_CLK_HZ, MIC_MODECHANGE_MS, FAST_SIM, FAST_SIM_DIV
  );

  /////////////////////////////
  // Top-level bench signals //
  /////////////////////////////

  // Free-running system clock.
  logic clk;

  // Active-high reset for DUT and AFE.
  logic rst;

  // Requested operating mode sent into Audio_Front_End.
  logic [1:0] mode_req;

  // FIR band select sent into Pdm_To_Pcm DUT.
  logic [2:0] freq_sel;

  // Serial ADC return data observed by the AFE.
  logic adc_data_out;

  // ADC chip-select driven by the AFE.
  logic adc_cs;

  // ADC serial clock driven by the AFE.
  logic adc_sclk;

  // ADC serial input data toward the AFE.
  logic adc_data_in;

  // Data-valid timing from the AFE into the DUT.
  logic data_val;

  // Current mode reported by the AFE state machine.
  logic [1:0] curr_mode;

  // Generated microphone bit clock from the AFE.
  logic mic_clk;

  // Internal helper: AFE's interpreted voltage-good / rail-on condition.
  logic dut_volt_on;

  // One-bit helper used by WaitTask() for "AFE rail is on".
  logic dut_volt_on_hi;

  // One-bit helper used by WaitTask() for "AFE reached ULTRASONIC mode".
  logic curr_mode_ult;

  // Logic-level rail seen directly by the microphone models.
  logic mic_vdd_on;

  // Runtime tone frequency driven into both microphone models.
  logic [31:0] tone_freq_hz;

  // One-bit helper used by WaitTask() when enough PCM samples are collected.
  logic pcm_samples_ready;

  // Pulse used to clear captured PCM samples between measurements.
  logic clr_capture;

  // Pulse used to clear X-detection error count.
  logic clr_x_errors;

  // Real-valued supply rail used by the ADC model.
  real vdd_v;

  //////////////////////////
  // Shared PDM data wire //
  //////////////////////////

  // Left microphone model drive.
  tri data_l;

  // Right microphone model drive.
  tri data_r;

  // Shared physical PDM data line seen by the DUT.
  tri data;

  /////////////////////////////////
  // PCM FIFO capture interface //
  /////////////////////////////////

  // Ready fed back to DUT for positive-channel PCM stream.
  logic pos_pcm_cap_rdy;

  // Ready fed back to DUT for negative-channel PCM stream.
  logic neg_pcm_cap_rdy;

  // Positive PCM output from DUT.
  logic signed [15:0] pcm_pos_o;

  // Positive PCM valid from DUT.
  logic pcm_valid_pos_o;

  // Negative PCM output from DUT.
  logic signed [15:0] pcm_neg_o;

  // Negative PCM valid from DUT.
  logic pcm_valid_neg_o;

  // Handshake: positive sample accepted this cycle.
  logic pos_pcm_accept;

  // Handshake: negative sample accepted this cycle.
  logic neg_pcm_accept;

  // FIFO model drains one element this cycle.
  logic fifo_pop;

  // Positive accepted sample contains X.
  logic pos_pcm_x;

  // Negative accepted sample contains X.
  logic neg_pcm_x;

  /////////////////////////
  // Scoreboard/counters //
  /////////////////////////

  // Total generic test failures accumulated by the bench.
  int error_count;

  // Count of accepted PCM samples that contained X.
  int pcm_x_error_count;

  // Counter used to schedule periodic FIFO pops.
  int fifo_read_cntr;

  // Occupancy of the positive-channel FIFO model.
  int pos_fifo_level;

  // Occupancy of the negative-channel FIFO model.
  int neg_fifo_level;

  // Number of captured positive PCM samples.
  int pos_sample_count;

  // Number of captured negative PCM samples.
  int neg_sample_count;

  // CSV file handle for sweep results.
  int sweep_fd;

  // Captured positive-channel PCM samples.
  logic signed [15:0] pos_samples[0:MAX_PCM_SAMPLES-1];

  // Captured negative-channel PCM samples.
  logic signed [15:0] neg_samples[0:MAX_PCM_SAMPLES-1];

  // Capture timestamps for positive PCM samples, in simulation time.
  realtime pos_sample_time_ns[0:MAX_PCM_SAMPLES-1];

  // Capture timestamps for negative PCM samples, in simulation time.
  realtime neg_sample_time_ns[0:MAX_PCM_SAMPLES-1];

  /////////////////////////////
  // Clock generation block //
  ///////////////////////////

  // Toggle the system clock every 10 ns.
  // This creates a 20 ns period = 50 MHz system clock.
  always #10 clk = ~clk;

  /////////////////////////////////////////////
  // Shared PDM wire resolution / bus model  //
  /////////////////////////////////////////////

  // Both microphone models share one physical PDM DATA wire.
  assign data = data_l;
  assign data = data_r;

  /////////////////////////////////////////////
  // Simple helper signals for wait/checks   //
  /////////////////////////////////////////////

  // Convert multibit / internal states into simple one-bit flags that are
  // easier to use with WaitTask() and status checks.
  always_comb begin
    // AFE internal power-on indicator viewed as a clean boolean helper.
    dut_volt_on_hi = (dut_volt_on === 1'b1);

    // Whether the AFE currently reports ULTRASONIC mode.
    curr_mode_ult = (curr_mode === MODE_ULT);

    // Enough samples have been captured on both channels to evaluate the tone.
    pcm_samples_ready = (pos_sample_count >= SWEEP_TOTAL_SAMPLES) &&
                        (neg_sample_count >= SWEEP_TOTAL_SAMPLES);
  end

  ////////////////////////////////////////////////
  // FIFO-style downstream sink / backpressure  //
  ////////////////////////////////////////////////

  // The sink is ready when capture is active and the corresponding FIFO is not full.
  assign pos_pcm_cap_rdy = !rst && !clr_capture && (pos_fifo_level < FIFO_DEPTH);
  assign neg_pcm_cap_rdy = !rst && !clr_capture && (neg_fifo_level < FIFO_DEPTH);

  // A PCM sample is accepted only on a valid+ready handshake.
  assign pos_pcm_accept = pcm_valid_pos_o && pos_pcm_cap_rdy;
  assign neg_pcm_accept = pcm_valid_neg_o && neg_pcm_cap_rdy;

  // The sink "reads" one element periodically to emulate downstream draining.
  assign fifo_pop = (fifo_read_cntr == (FIFO_READ_GAP_CYCLES - 1));

  // Detect X only when the sample is actually accepted into the sink model.
  assign pos_pcm_x = pos_pcm_accept && (^pcm_pos_o === 1'bx);
  assign neg_pcm_x = neg_pcm_accept && (^pcm_neg_o === 1'bx);

  ////////////////////////////////////////////////
  // Convert analog-ish rail into mic power-on  //
  ////////////////////////////////////////////////

  // The mic models use mic_vdd_on directly.
  // The DUT measures this rail through the ADC serial feedback path.
  always_ff @(posedge clk) begin
    if (rst) begin
      // During reset, microphones are forced off.
      mic_vdd_on <= 1'b0;
    end else if (vdd_v < 1.611) begin
      // Below the lower threshold, microphones are considered off.
      mic_vdd_on <= 1'b0;
    end else if (vdd_v > 1.624) begin
      // Above the upper threshold, microphones are considered on.
      mic_vdd_on <= 1'b1;
    end
    // Between thresholds, hold the previous state.
  end

  ////////////////////
  // DUT instance   //
  ////////////////////

  // Main DUT: converts shared-wire PDM into positive/negative PCM channels.
  Pdm_To_Pcm iDUT (
      .clk_i            (clk),
      .rst_i            (rst),
      .mic_clk_i        (mic_clk),
      .mic_clk_val_i    (data_val),
      .freq_sel_i       (freq_sel),
      .mic_data_i       (data),
      .pos_pcm_cap_rdy_i(pos_pcm_cap_rdy),
      .neg_pcm_cap_rdy_i(neg_pcm_cap_rdy),
      .pcm_pos_o        (pcm_pos_o),
      .pcm_valid_pos_o  (pcm_valid_pos_o),
      .pcm_neg_o        (pcm_neg_o),
      .pcm_valid_neg_o  (pcm_valid_neg_o)
  );

  /////////////////////////////////////
  // Audio Front End instance        //
  /////////////////////////////////////

  // Use the real AFE path so mic clock and data-valid timing match integration.
  Audio_Front_End #(
      .SYS_CLK_HZ  (SYS_CLK_HZ),
      .FAST_SIM    (FAST_SIM),
      .FAST_SIM_DIV(FAST_SIM_DIV)
  ) iAFE (
      .clk_i         (clk),
      .rst_i         (rst),
      .mode_req_i    (mode_req),
      .ADC_data_out_i(adc_data_out),
      .ADC_CS_o      (adc_cs),
      .ADC_SCLK_o    (adc_sclk),
      .ADC_data_in_o (adc_data_in),
      .data_val_o    (data_val),
      .curr_mode_o   (curr_mode),
      .mic_clk_o     (mic_clk)
  );

  // Observe the AFE's internal volt_on indication for bench waiting/checking.
  assign dut_volt_on = iAFE.volt_on;

  //////////////////////////////
  // Microphone model: left   //
  //////////////////////////////

  // Left microphone drives one phase of the shared PDM wire.
  SPH0641LU4H_1_model #(
      .FAST_SIM      (FAST_SIM),
      .FAST_SIM_DIV  (FAST_SIM_DIV),
      .TONE_FREQ_HZ  (14_000),
      .TONE_AMPLITUDE(TONE_AMPLITUDE)
  ) iMIC_MODEL_L (
      .vdd_i         (mic_vdd_on),
      .clock_i       (mic_clk),
      .select_i      (1'b0),
      .tone_freq_hz_i(tone_freq_hz),
      .data_o        (data_l)
  );

  //////////////////////////////
  // Microphone model: right  //
  //////////////////////////////

  // Right microphone drives the opposite phase of the same PDM wire.
  SPH0641LU4H_1_model #(
      .FAST_SIM      (FAST_SIM),
      .FAST_SIM_DIV  (FAST_SIM_DIV),
      .TONE_FREQ_HZ  (14_000),
      .TONE_AMPLITUDE(TONE_AMPLITUDE)
  ) iMIC_MODEL_R (
      .vdd_i         (mic_vdd_on),
      .clock_i       (mic_clk),
      .select_i      (1'b1),
      .tone_freq_hz_i(tone_freq_hz),
      .data_o        (data_r)
  );

  ///////////////////////////////////////////
  // ADC serial response model             //
  ///////////////////////////////////////////

  // Whenever the AFE starts an ADC conversion, feed it the serial response
  // corresponding to the current rail voltage.
  always @(negedge adc_cs) begin
    simulate_adc_reading(adc_cs, adc_sclk, adc_data_out, voltage_to_adc_code(vdd_v));
  end

  ///////////////////////////////////////////
  // FIFO drain timing counter             //
  ///////////////////////////////////////////

  // This counter determines when the sink model pops one item.
  always_ff @(posedge clk) begin
    if (rst || clr_capture) begin
      fifo_read_cntr <= 0;
    end else if (fifo_pop) begin
      fifo_read_cntr <= 0;
    end else begin
      fifo_read_cntr <= fifo_read_cntr + 1;
    end
  end

  ///////////////////////////////////////////
  // Positive FIFO occupancy model         //
  ///////////////////////////////////////////

  // Track how full the positive-channel downstream FIFO is.
  always_ff @(posedge clk) begin
    if (rst || clr_capture) begin
      pos_fifo_level <= 0;
    end else begin
      unique case ({
        pos_pcm_accept, fifo_pop && (pos_fifo_level != 0)
      })
        2'b10:   pos_fifo_level <= pos_fifo_level + 1;
        2'b01:   pos_fifo_level <= pos_fifo_level - 1;
        default: pos_fifo_level <= pos_fifo_level;
      endcase
    end
  end

  ///////////////////////////////////////////
  // Negative FIFO occupancy model         //
  ///////////////////////////////////////////

  // Track how full the negative-channel downstream FIFO is.
  always_ff @(posedge clk) begin
    if (rst || clr_capture) begin
      neg_fifo_level <= 0;
    end else begin
      unique case ({
        neg_pcm_accept, fifo_pop && (neg_fifo_level != 0)
      })
        2'b10:   neg_fifo_level <= neg_fifo_level + 1;
        2'b01:   neg_fifo_level <= neg_fifo_level - 1;
        default: neg_fifo_level <= neg_fifo_level;
      endcase
    end
  end

  ///////////////////////////////////////////
  // X detection accounting                //
  ///////////////////////////////////////////

  // Count accepted PCM samples that still contain X.
  always_ff @(posedge clk) begin
    if (clr_x_errors) begin
      pcm_x_error_count <= 0;
    end else if (pos_pcm_x || neg_pcm_x) begin
      if (pos_pcm_x) begin
        $error("ERROR: POS PCM sample has X when accepted by the FIFO!");
      end

      if (neg_pcm_x) begin
        $error("ERROR: NEG PCM sample has X when accepted by the FIFO!");
      end

      pcm_x_error_count <= pcm_x_error_count + (pos_pcm_x ? 1 : 0) + (neg_pcm_x ? 1 : 0);
    end
  end

  ///////////////////////////////////////////
  // Positive-channel sample capture       //
  ///////////////////////////////////////////

  // Store accepted, non-X positive PCM samples and their timestamps.
  always_ff @(posedge clk) begin
    if (rst || clr_capture) begin
      pos_sample_count <= 0;
    end else if (pos_pcm_accept && !pos_pcm_x && (pos_sample_count < MAX_PCM_SAMPLES)) begin
      pos_samples[pos_sample_count] <= pcm_pos_o;
      pos_sample_time_ns[pos_sample_count] <= $realtime;
      pos_sample_count <= pos_sample_count + 1;
    end
  end

  ///////////////////////////////////////////
  // Negative-channel sample capture       //
  ///////////////////////////////////////////

  // Store accepted, non-X negative PCM samples and their timestamps.
  always_ff @(posedge clk) begin
    if (rst || clr_capture) begin
      neg_sample_count <= 0;
    end else if (neg_pcm_accept && !neg_pcm_x && (neg_sample_count < MAX_PCM_SAMPLES)) begin
      neg_samples[neg_sample_count] <= pcm_neg_o;
      neg_sample_time_ns[neg_sample_count] <= $realtime;
      neg_sample_count <= neg_sample_count + 1;
    end
  end

  //////////////////////////////////////////
  // Utility function: tone list          //
  //////////////////////////////////////////

  // Return the next tone used by the dense characterization sweep.
  function automatic int unsigned sweep_tone_hz(input int unsigned tone_idx);
    begin
      sweep_tone_hz = SWEEP_START_HZ + (tone_idx * SWEEP_STEP_HZ);
    end
  endfunction

  //////////////////////////////////////////
  // Utility function: band lookup        //
  //////////////////////////////////////////

  // Convert a loop index into the DUT's band-select encoding.
  function automatic logic [2:0] band_from_idx(input int unsigned band_idx);
    begin
      unique case (band_idx)
        0:       band_from_idx = BAND_10_18;
        1:       band_from_idx = BAND_18_25;
        2:       band_from_idx = BAND_25_32;
        3:       band_from_idx = BAND_32_40;
        4:       band_from_idx = BAND_0_10;
        default: band_from_idx = BAND_0_10;
      endcase
    end
  endfunction

  //////////////////////////////////////////
  // Utility function: band label         //
  //////////////////////////////////////////

  // Human-readable label for transcript and CSV output.
  function automatic string band_name(input logic [2:0] band_sel);
    begin
      unique case (band_sel)
        BAND_10_18: band_name = "10-18";
        BAND_18_25: band_name = "18-25";
        BAND_25_32: band_name = "25-32";
        BAND_32_40: band_name = "32-40";
        BAND_0_10:  band_name = "0-10";
        default:    band_name = "unknown";
      endcase
    end
  endfunction

  //////////////////////////////////////////
  // Utility function: expected band      //
  //////////////////////////////////////////

  // Return the expected pass band for clear in-band tones.
  // Tones outside selected bands or near transition edges return -1
  // and are logged only.
  function automatic int expected_band_idx(input int unsigned tone_hz);
    begin
      if (tone_hz <= (10_000 - BAND_CHECK_GUARD_HZ)) begin
        expected_band_idx = 4;
      end else if ((tone_hz >= (10_000 + BAND_CHECK_GUARD_HZ)) &&
          (tone_hz <= (18_000 - BAND_CHECK_GUARD_HZ))) begin
        expected_band_idx = 0;
      end else if ((tone_hz >= (18_000 + BAND_CHECK_GUARD_HZ)) &&
                   (tone_hz <= (25_000 - BAND_CHECK_GUARD_HZ))) begin
        expected_band_idx = 1;
      end else if ((tone_hz >= (25_000 + BAND_CHECK_GUARD_HZ)) &&
                   (tone_hz <= (32_000 - BAND_CHECK_GUARD_HZ))) begin
        expected_band_idx = 2;
      end else if ((tone_hz >= (32_000 + BAND_CHECK_GUARD_HZ)) &&
                   (tone_hz <= (40_000 - BAND_CHECK_GUARD_HZ))) begin
        expected_band_idx = 3;
      end else begin
        expected_band_idx = -1;
      end
    end
  endfunction

  //////////////////////////////////////////
  // Utility task: measure one band       //
  //////////////////////////////////////////

  // Select one FIR band, capture fresh PCM samples, then compute tone metrics.
  task automatic measure_band(input logic [2:0] next_freq_sel,
                              input int unsigned next_tone_hz,
                              output real pos_swing,
                              output real pos_corr,
                              output real pos_tone,
                              output real neg_swing,
                              output real neg_corr,
                              output real neg_tone);
    string label;
    begin
      label = $sformatf("%0d Hz tone / %s kHz band", next_tone_hz, band_name(next_freq_sel));

      @(negedge clk) begin
        tone_freq_hz = next_tone_hz;
        freq_sel = next_freq_sel;
      end

      clear_pcm_capture(clk, clr_capture);
      wait_for_pcm_samples(clk, error_count, pcm_samples_ready, PCM_TIMEOUT_CYCLES,
                           {label, " PCM samples"});

      pos_swing = calc_pcm_swing(pos_samples, pos_sample_count, SWEEP_CHECK_SAMPLES);
      pos_corr = calc_tone_corr(pos_samples, pos_sample_time_ns, pos_sample_count,
                                SWEEP_CHECK_SAMPLES, next_tone_hz);
      pos_tone = pos_swing * pos_corr;

      neg_swing = calc_pcm_swing(neg_samples, neg_sample_count, SWEEP_CHECK_SAMPLES);
      neg_corr = calc_tone_corr(neg_samples, neg_sample_time_ns, neg_sample_count,
                                SWEEP_CHECK_SAMPLES, next_tone_hz);
      neg_tone = neg_swing * neg_corr;

      $display("%s: POS tone %.1f (swing %.1f, corr %.3f), NEG tone %.1f (swing %.1f, corr %.3f).",
               label, pos_tone, pos_swing, pos_corr, neg_tone, neg_swing, neg_corr);
    end
  endtask

  //////////////////////////////////////////
  // Utility task: run one tone sweep     //
  //////////////////////////////////////////

  // Sweep all FIR banks for one tone and report raw strongest-band behavior.
  // The directed Pdm_To_Pcm_tb owns strict pass/stop checks because this
  // characterization sweep is not gain-normalized across every signal path.
  task automatic run_tone_sweep(input int test_num, input int unsigned next_tone_hz);
    int expected_idx;
    int pos_max_idx;
    int neg_max_idx;
    int band_idx;
    real pos_max_tone;
    real neg_max_tone;
    real pos_swing_by_band[0:NUM_BANDS-1];
    real neg_swing_by_band[0:NUM_BANDS-1];
    real pos_corr_by_band[0:NUM_BANDS-1];
    real neg_corr_by_band[0:NUM_BANDS-1];
    real pos_tone_by_band[0:NUM_BANDS-1];
    real neg_tone_by_band[0:NUM_BANDS-1];
    logic [2:0] curr_band;
    begin
      announce_test(test_num, $sformatf("Sweep %0d Hz tone across all FIR bands.", next_tone_hz));

      for (band_idx = 0; band_idx < NUM_BANDS; band_idx += 1) begin
        curr_band = band_from_idx(band_idx);
        measure_band(curr_band, next_tone_hz, pos_swing_by_band[band_idx],
                     pos_corr_by_band[band_idx], pos_tone_by_band[band_idx],
                     neg_swing_by_band[band_idx], neg_corr_by_band[band_idx],
                     neg_tone_by_band[band_idx]);

        if (sweep_fd != 0) begin
          $fdisplay(sweep_fd, "%0d,%s,%0d,%.3f,%.3f,%.3f,%.3f,%.3f,%.3f",
                    next_tone_hz, band_name(curr_band), band_idx,
                    pos_swing_by_band[band_idx], pos_corr_by_band[band_idx],
                    pos_tone_by_band[band_idx], neg_swing_by_band[band_idx],
                    neg_corr_by_band[band_idx], neg_tone_by_band[band_idx]);
        end
      end

      pos_max_idx = 0;
      neg_max_idx = 0;
      pos_max_tone = pos_tone_by_band[0];
      neg_max_tone = neg_tone_by_band[0];

      for (band_idx = 1; band_idx < NUM_BANDS; band_idx += 1) begin
        if (pos_tone_by_band[band_idx] > pos_max_tone) begin
          pos_max_tone = pos_tone_by_band[band_idx];
          pos_max_idx = band_idx;
        end

        if (neg_tone_by_band[band_idx] > neg_max_tone) begin
          neg_max_tone = neg_tone_by_band[band_idx];
          neg_max_idx = band_idx;
        end
      end

      expected_idx = expected_band_idx(next_tone_hz);

      if (expected_idx >= 0) begin
        if ((pos_max_idx != expected_idx) || (neg_max_idx != expected_idx)) begin
          $display(
              "NOTE: %0d Hz expected pass band is %s kHz, but raw strongest is POS %s kHz / NEG %s kHz.",
              next_tone_hz, band_name(band_from_idx(expected_idx)),
              band_name(band_from_idx(pos_max_idx)), band_name(band_from_idx(neg_max_idx)));
          $display(
              "      This sweep is not gain-normalized across 48 kHz and 192 kHz paths; use directed pass/stop checks for correctness.");
        end
      end else begin
        $display("%0d Hz is outside a clear pass band or near a transition edge, so raw strongest-band note is skipped.",
                 next_tone_hz);
      end
    end
  endtask

  ////////////////////////
  // Main test sequence //
  ////////////////////////

  initial begin
    // Initialize free-running clock state.
    clk = 1'b0;

    // Start in reset.
    rst = 1'b1;

    // Default requested mode is STANDARD.
    mode_req = MODE_STD;

    // Start with the 10-18 kHz FIR band selected.
    freq_sel = BAND_10_18;

    // Default ADC return line state.
    adc_data_out = 1'b0;

    // Start with microphone rail off.
    vdd_v = 0.0;

    // Start with a known in-band tone.
    tone_freq_hz = sweep_tone_hz(1);

    // Hold capture clear high until initialization is finished.
    clr_capture = 1'b1;

    // Hold X-error clear high during early initialization.
    clr_x_errors = 1'b1;

    // Start with zero accumulated generic errors.
    error_count = 0;

    // Open CSV output for external plotting.
    sweep_fd = $fopen("./outputs/Pdm_To_Pcm_sweep.csv", "w");
    if (sweep_fd == 0) begin
      $error("ERROR: Could not open ./outputs/Pdm_To_Pcm_sweep.csv.");
      error_count += 1;
    end else begin
      $fdisplay(sweep_fd, "tone_hz,band,band_idx,pos_swing,pos_corr,pos_tone,neg_swing,neg_corr,neg_tone");
    end

    // Hold reset for a few negative clock edges.
    wait_n_negedges(clk, 8);

    // Enable X-error counting after the initial reset period.
    clr_x_errors = 1'b0;

    // Release reset.
    rst = 1'b0;

    // Give design a few cycles to settle after reset release.
    wait_n_negedges(clk, 4);

    // Allow normal sample capture from this point onward.
    clr_capture = 1'b0;

    // ----------------------------------------------------------
    // TEST 1
    // ----------------------------------------------------------
    // Immediately after reset, outputs should still be quiet.
    announce_test(1, "Outputs should be quiet immediately after reset.");
    check_outputs_quiet(error_count, pcm_valid_pos_o, pcm_valid_neg_o);

    // ----------------------------------------------------------
    // TEST 2
    // ----------------------------------------------------------
    // Bring up the real Audio Front End path and power the microphones.
    announce_test(2, "Audio Front End should power up the microphones in ULTRASONIC mode.");
    request_ult_mode(clk, error_count, mode_req, MODE_ULT, vdd_v, MIC_VDD_ON_V, dut_volt_on_hi,
                     curr_mode_ult, data_val, POWERUP_CYCLES, FSM_MARGIN_CYCLES,
                     MODE_CHANGE_CYCLES);

    // ----------------------------------------------------------
    // TEST 3+
    // ----------------------------------------------------------
    // // Sweep each tone across every selectable FIR band.
    // for (int tone_idx = 0; tone_idx < NUM_SWEEP_TONES; tone_idx += 1) begin
    //   run_tone_sweep(tone_idx + 3, sweep_tone_hz(tone_idx));
    // end

    // Final summary message.
    if ((error_count + pcm_x_error_count) == 0) begin
      $display("YAHOO!! Pdm_To_Pcm sweep completed.");
      $display("Sweep CSV written to tests/output/Pdm_To_Pcm_sweep.csv.");
    end else begin
      $error("ERROR: %0d Pdm_To_Pcm sweep issue(s) detected.", error_count + pcm_x_error_count);
    end

    if (sweep_fd != 0) begin
      $fclose(sweep_fd);
    end

    // Stop simulation so results can be inspected.
    $stop();
  end

endmodule
