`timescale 1ns / 1ps
// ------------------------------------------------------------
// Testbench: Pdm_To_Pcm_tb
// Description:
//   Integration-style testbench for the PDM-to-PCM path.
//
//   This testbench does all of the following:
//     - Uses the real Audio_Front_End to generate mic clock/data-valid
//     - Uses two microphone models sharing one PDM data wire
//     - Models downstream PCM backpressure with a small FIFO-like sink
//     - Captures PCM output samples for later analysis
//     - Checks that each selected FIR band passes/rejects expected tones
//
// Author: Srivibhav Jonnalagadda
// Date: 04-11-2026
// ------------------------------------------------------------
module Pdm_To_Pcm_tb ();

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

  // Test tones used to stress the selectable FIR bands.
  localparam int unsigned TONE_8_KHZ = 8_000;
  localparam int unsigned TONE_14_KHZ = 14_000;
  localparam int unsigned TONE_21P5_KHZ = 21_500;
  localparam int unsigned TONE_28P5_KHZ = 28_500;
  localparam int unsigned TONE_36_KHZ = 36_000;

  // Mic-model tone amplitude used for the integration test.
  localparam int unsigned TONE_AMPLITUDE = 16'd1024;

  // Maximum number of cycles the bench will wait for enough PCM samples.
  localparam int unsigned PCM_TIMEOUT_CYCLES = 700_000;

  // FIFO depth used by the downstream ready/valid sink model.
  localparam int unsigned FIFO_DEPTH = 8;

  // Number of system-clock cycles between one FIFO pop and the next.
  localparam int unsigned FIFO_READ_GAP_CYCLES = 96;

  // Maximum number of PCM samples stored per channel.
  localparam int unsigned MAX_PCM_SAMPLES = 768;

  // Number of initial samples ignored before checking the steady-state tone.
  localparam int unsigned TONE_WARMUP_SAMPLES = 256;

  // Number of samples used for final swing/correlation measurements.
  localparam int unsigned TONE_CHECK_SAMPLES = 256;

  // Total samples needed before the bench considers capture "ready".
  localparam int unsigned TONE_TOTAL_SAMPLES = TONE_WARMUP_SAMPLES + TONE_CHECK_SAMPLES;

  // Minimum acceptable swing for a tone that should pass.
  localparam int unsigned MIN_PASS_SWING = 8;

  // Minimum acceptable normalized tone correlation for a pass-band result.
  localparam real MIN_TONE_CORR = 0.15;

  // Maximum stop-band tone level allowed relative to the pass-band tone level.
  localparam real MAX_STOP_TONE_RATIO = 0.25;

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

  // Pulse used to clear captured PCM samples between tests.
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

  // Remembered pass-band tone strength for the positive channel.
  real pos_pass_tone;

  // Remembered pass-band tone strength for the negative channel.
  real neg_pass_tone;

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
  // Because these are tri nets, each model can drive the line according to
  // its own edge relationship / select behavior.
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
    pcm_samples_ready = (pos_sample_count >= TONE_TOTAL_SAMPLES) &&
                        (neg_sample_count >= TONE_TOTAL_SAMPLES);
  end

  ////////////////////////////////////////////////
  // FIFO-style downstream sink / backpressure  //
  ////////////////////////////////////////////////

  // The sink is ready when:
  //   - reset is deasserted
  //   - capture is not being cleared
  //   - the corresponding FIFO is not full
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
  // The DUT does not see this signal directly; instead it measures the rail
  // through the ADC serial feedback path.
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
    // Between thresholds, hold the previous state to model hysteresis-like behavior.
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

  // The bench uses the real AFE path instead of directly fabricating mic_clk
  // and data-valid timing. This makes the test more integration-realistic.
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

  // Left microphone:
  //   - sees the rail directly
  //   - uses the real AFE-generated mic clock
  //   - drives one half of the shared-wire PDM timing relationship
  SPH0641LU4H_1_model #(
      .FAST_SIM      (FAST_SIM),
      .FAST_SIM_DIV  (FAST_SIM_DIV),
      .TONE_FREQ_HZ  (TONE_14_KHZ),
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

  // Right microphone:
  //   - same rail and tone frequency
  //   - opposite select phase relative to the left microphone
  SPH0641LU4H_1_model #(
      .FAST_SIM      (FAST_SIM),
      .FAST_SIM_DIV  (FAST_SIM_DIV),
      .TONE_FREQ_HZ  (TONE_14_KHZ),
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
      // Reset the drain cadence during reset or between band tests.
      fifo_read_cntr <= 0;
    end else if (fifo_pop) begin
      // Once a pop occurs, restart the count.
      fifo_read_cntr <= 0;
    end else begin
      // Otherwise keep counting toward the next pop.
      fifo_read_cntr <= fifo_read_cntr + 1;
    end
  end

  ///////////////////////////////////////////
  // Positive FIFO occupancy model         //
  ///////////////////////////////////////////

  // Track how full the positive-channel downstream FIFO is.
  always_ff @(posedge clk) begin
    if (rst || clr_capture) begin
      // Empty the modeled FIFO on reset / capture clear.
      pos_fifo_level <= 0;
    end else begin
      // Cases:
      //   10 -> accepted sample, no pop      => occupancy +1
      //   01 -> no accept, pop existing data => occupancy -1
      //   11 -> accept and pop same cycle    => no net change
      //   00 -> idle                         => no net change
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
      // Empty the modeled FIFO on reset / capture clear.
      neg_fifo_level <= 0;
    end else begin
      // Same logic as positive channel, but for the negative stream.
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
  // This is separated from sample storage to keep responsibility clear.
  always_ff @(posedge clk) begin
    if (clr_x_errors) begin
      // Clear X counter at start of testing.
      pcm_x_error_count <= 0;
    end else if (pos_pcm_x || neg_pcm_x) begin
      // Report positive-channel X if present.
      if (pos_pcm_x) begin
        $error("ERROR: POS PCM sample has X when accepted by the FIFO!");
      end

      // Report negative-channel X if present.
      if (neg_pcm_x) begin
        $error("ERROR: NEG PCM sample has X when accepted by the FIFO!");
      end

      // Add the number of X events seen this cycle.
      pcm_x_error_count <= pcm_x_error_count + (pos_pcm_x ? 1 : 0) + (neg_pcm_x ? 1 : 0);
    end
  end

  ///////////////////////////////////////////
  // Positive-channel sample capture       //
  ///////////////////////////////////////////

  // Store accepted, non-X positive PCM samples and their timestamps.
  always_ff @(posedge clk) begin
    if (rst || clr_capture) begin
      // Start fresh on reset / capture clear.
      pos_sample_count <= 0;
    end else if (pos_pcm_accept && !pos_pcm_x && (pos_sample_count < MAX_PCM_SAMPLES)) begin
      // Save the accepted sample.
      pos_samples[pos_sample_count] <= pcm_pos_o;

      // Save the exact capture timestamp.
      pos_sample_time_ns[pos_sample_count] <= $realtime;

      // Advance sample count.
      pos_sample_count <= pos_sample_count + 1;
    end
  end

  ///////////////////////////////////////////
  // Negative-channel sample capture       //
  ///////////////////////////////////////////

  // Store accepted, non-X negative PCM samples and their timestamps.
  always_ff @(posedge clk) begin
    if (rst || clr_capture) begin
      // Start fresh on reset / capture clear.
      neg_sample_count <= 0;
    end else if (neg_pcm_accept && !neg_pcm_x && (neg_sample_count < MAX_PCM_SAMPLES)) begin
      // Save the accepted sample.
      neg_samples[neg_sample_count] <= pcm_neg_o;

      // Save the exact capture timestamp.
      neg_sample_time_ns[neg_sample_count] <= $realtime;

      // Advance sample count.
      neg_sample_count <= neg_sample_count + 1;
    end
  end

  //////////////////////////////////////////
  // Utility task: check both channels    //
  //////////////////////////////////////////

  // Evaluate both positive and negative channels for the current FIR band.
  task automatic check_band(input string label, input bit expect_pass);
    begin
      // Keep the directed flow here, but move the heavy tone-analysis math into a package.
      check_pcm_band(error_count, label, expect_pass, pos_samples, pos_sample_time_ns,
                     pos_sample_count, neg_samples, neg_sample_time_ns, neg_sample_count,
                     TONE_TOTAL_SAMPLES, TONE_CHECK_SAMPLES, int'(tone_freq_hz), MIN_PASS_SWING,
                     MIN_TONE_CORR, MAX_STOP_TONE_RATIO, pos_pass_tone, neg_pass_tone);
    end
  endtask

  //////////////////////////////////////////
  // Utility task: set test tone          //
  //////////////////////////////////////////

  // Change the microphone-model tone and clear the remembered pass reference.
  task automatic set_test_tone(input logic [31:0] next_tone_freq_hz);
    begin
      @(negedge clk) begin
        tone_freq_hz = next_tone_freq_hz;
        pos_pass_tone = 0.0;
        neg_pass_tone = 0.0;
      end
    end
  endtask

  //////////////////////////////////////////
  // Utility function: determine band pass//
  //////////////////////////////////////////
  function automatic bit band_should_pass(input int unsigned tone_freq_hz,
                                          input logic [2:0] band_sel);
    begin
      unique case (band_sel)
        BAND_0_10: band_should_pass = (tone_freq_hz < 10_000);

        BAND_10_18: band_should_pass = (tone_freq_hz >= 10_000) && (tone_freq_hz < 18_000);

        BAND_18_25: band_should_pass = (tone_freq_hz >= 18_000) && (tone_freq_hz < 25_000);

        BAND_25_32: band_should_pass = (tone_freq_hz >= 25_000) && (tone_freq_hz < 32_000);

        BAND_32_40: band_should_pass = (tone_freq_hz >= 32_000) && (tone_freq_hz <= 40_000);

        default: band_should_pass = 1'b0;
      endcase
    end
  endfunction

  //////////////////////////////////////////
  // Utility task: run one band test      //
  //////////////////////////////////////////

  // Select a new FIR band, clear old samples, collect fresh samples, then
  // evaluate whether that band passes or rejects the current tone.
  task automatic run_band_check(input int test_num, input logic [2:0] next_freq_sel,
                                input string label);
    bit expect_pass;
    begin
      // Determine automatically whether the selected band should pass
      // the current tone frequency.
      expect_pass = band_should_pass(tone_freq_hz, next_freq_sel);

      // Print a readable test header.
      announce_test(test_num, label);

      // Apply the new FIR band selection.
      @(negedge clk) freq_sel = next_freq_sel;

      // Clear any previously captured PCM samples.
      clear_pcm_capture(clk, clr_capture);

      // Wait until enough fresh samples have been collected.
      wait_for_pcm_samples(clk, error_count, pcm_samples_ready, PCM_TIMEOUT_CYCLES, {
                           label, " PCM samples"});

      // Evaluate the captured output.
      check_band(label, expect_pass);
    end
  endtask

  //////////////////////////////////////////
  // Utility task: run invalid band check //
  //////////////////////////////////////////

  // Invalid band selections should not produce accepted PCM samples.
  task automatic run_invalid_band_check(input int test_num, input logic [2:0] next_freq_sel,
                                        input string label);
    begin
      // Print a readable test header.
      announce_test(test_num, label);

      // Select an invalid FIR band and clear old captured samples.
      @(negedge clk) freq_sel = next_freq_sel;
      clear_pcm_capture(clk, clr_capture);

      // Wait long enough that a valid band would have produced samples.
      wait_n_negedges(clk, PCM_TIMEOUT_CYCLES / 8);

      // No samples should have been accepted from either channel.
      if ((pos_sample_count != 0) || (neg_sample_count != 0)) begin
        $error("ERROR: %s produced PCM samples for invalid freq_sel %0h!", label, next_freq_sel);
        error_count += 1;
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

    // Start with a tone inside the first FIR band.
    tone_freq_hz = TONE_14_KHZ;

    // Hold capture clear high until initialization is finished.
    clr_capture = 1'b1;

    // Hold X-error clear high during early initialization.
    clr_x_errors = 1'b1;

    // Start with zero accumulated generic errors.
    error_count = 0;

    // Pass-band reference tone metrics are not known yet.
    pos_pass_tone = 0.0;
    neg_pass_tone = 0.0;

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
    // TEST 3
    // ----------------------------------------------------------
    set_test_tone(TONE_8_KHZ);
    run_band_check(3, BAND_0_10, "8 kHz tone should pass the 0-10 kHz band.");

    // ----------------------------------------------------------
    // TEST 4
    // ----------------------------------------------------------
    run_invalid_band_check(4, 3'h5, "Invalid freq_sel 3'h5 should not produce PCM output.");

    // ----------------------------------------------------------
    // TEST 5
    // ----------------------------------------------------------
    run_invalid_band_check(5, 3'h6, "Invalid freq_sel 3'h6 should not produce PCM output.");

    // ----------------------------------------------------------
    // TEST 6
    // ----------------------------------------------------------
    run_invalid_band_check(6, 3'h7, "Invalid freq_sel 3'h7 should not produce PCM output.");

    // ----------------------------------------------------------
    // TEST 7
    // ----------------------------------------------------------
    set_test_tone(TONE_14_KHZ);
    run_band_check(7, BAND_10_18, "14 kHz tone should pass the 10-18 kHz band.");

    // ----------------------------------------------------------
    // TEST 8
    // ----------------------------------------------------------
    run_band_check(8, BAND_0_10, "14 kHz tone should be rejected by the 0-10 kHz band.");

    // ----------------------------------------------------------
    // TEST 9
    // ----------------------------------------------------------
    run_band_check(9, BAND_18_25, "14 kHz tone should be rejected by the 18-25 kHz band.");

    // ----------------------------------------------------------
    // TEST 10
    // ----------------------------------------------------------
    set_test_tone(TONE_21P5_KHZ);
    run_band_check(10, BAND_18_25, "21.5 kHz tone should pass the 18-25 kHz band.");

    // ----------------------------------------------------------
    // TEST 11
    // ----------------------------------------------------------
    run_band_check(11, BAND_10_18, "21.5 kHz tone should be rejected by the 10-18 kHz band.");

    // ----------------------------------------------------------
    // TEST 12
    // ----------------------------------------------------------
    run_band_check(12, BAND_25_32, "21.5 kHz tone should be rejected by the 25-32 kHz band.");

    // ----------------------------------------------------------
    // TEST 13
    // ----------------------------------------------------------
    set_test_tone(TONE_28P5_KHZ);
    run_band_check(13, BAND_25_32, "28.5 kHz tone should pass the 25-32 kHz band.");

    // ----------------------------------------------------------
    // TEST 14
    // ----------------------------------------------------------
    run_band_check(14, BAND_18_25, "28.5 kHz tone should be rejected by the 18-25 kHz band.");

    // ----------------------------------------------------------
    // TEST 15
    // ----------------------------------------------------------
    run_band_check(15, BAND_32_40, "28.5 kHz tone should be rejected by the 32-40 kHz band.");

    // ----------------------------------------------------------
    // TEST 16
    // ----------------------------------------------------------
    set_test_tone(TONE_36_KHZ);
    run_band_check(16, BAND_32_40, "36 kHz tone should pass the 32-40 kHz band.");

    // ----------------------------------------------------------
    // TEST 17
    // ----------------------------------------------------------
    run_band_check(17, BAND_25_32, "36 kHz tone should be rejected by the 25-32 kHz band.");

    // Final summary message.
    if ((error_count + pcm_x_error_count) == 0) begin
      $display("YAHOO!! All Pdm_To_Pcm tests passed.");
    end else begin
      $error("ERROR: %0d Pdm_To_Pcm test(s) failed.", error_count + pcm_x_error_count);
    end

    // Stop simulation so results can be inspected.
    $stop();
  end

endmodule
