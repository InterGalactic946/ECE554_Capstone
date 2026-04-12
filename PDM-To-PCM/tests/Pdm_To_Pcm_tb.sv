`timescale 1ns / 1ps
// ------------------------------------------------------------
// Testbench: Pdm_To_Pcm_tb
// Description: Verifies the PDM-to-PCM path using the real
//              Audio Front End clock path, two SPH0641LU4H-1
//              microphone models, FIFO-style PCM backpressure,
//              and the selectable FIR frequency bands.
// Author: Srivibhav Jonnalagadda
// Date: 04-11-2026
// ------------------------------------------------------------
module Pdm_To_Pcm_tb ();
  import Mic_Time_pkg::*;
  import Tb_Util_pkg::*;

  /////////////////////////
  // Test configuration //
  ///////////////////////
  localparam int unsigned SYS_CLK_HZ = 50_000_000;
  localparam bit FAST_SIM = 1'b1;
  localparam int unsigned FAST_SIM_DIV = 1000;
  localparam int unsigned FSM_MARGIN_CYCLES = 256;

  localparam logic [1:0] MODE_STD = 2'h2;
  localparam logic [1:0] BAND_10_18 = 2'b00;
  localparam logic [1:0] BAND_18_25 = 2'b01;
  localparam logic [1:0] BAND_25_32 = 2'b10;
  localparam logic [1:0] BAND_32_40 = 2'b11;

  localparam int unsigned TONE_FREQ_HZ = 15_000;
  localparam int unsigned PCM_TIMEOUT_CYCLES = 700_000;
  localparam int unsigned FIFO_DEPTH = 8;
  localparam int unsigned FIFO_READ_GAP_CYCLES = 96;
  localparam int unsigned MAX_PCM_SAMPLES = 768;
  localparam int unsigned TONE_WARMUP_SAMPLES = 256;
  localparam int unsigned TONE_CHECK_SAMPLES = 256;
  localparam int unsigned TONE_TOTAL_SAMPLES = TONE_WARMUP_SAMPLES + TONE_CHECK_SAMPLES;
  localparam int unsigned MIN_PASS_SWING = 8;
  localparam real MIN_TONE_CORR = 0.15;
  localparam real MAX_STOP_TONE_RATIO = 0.25;
  localparam real MIC_VDD_ON_V = 1.80;

  localparam int unsigned POWERUP_CYCLES = mic_cycles_from_ms(
      SYS_CLK_HZ, MIC_POWERUP_MS, FAST_SIM, FAST_SIM_DIV
  );

  /////////////////////////////
  // Stimulus of type logic //
  ///////////////////////////
  logic clk;
  logic rst;
  logic [1:0] mode_req;
  logic [1:0] freq_sel;
  logic adc_data_out;
  logic adc_cs;
  logic adc_sclk;
  logic adc_data_in;
  logic data_val;
  logic [1:0] curr_mode;
  logic mic_clk;
  logic dut_volt_on;
  logic dut_volt_on_hi;
  logic curr_mode_std;
  logic mic_vdd_on;
  logic pcm_samples_ready;
  logic clr_capture;
  logic clr_x_errors;
  real vdd_v;

  tri data_l;
  tri data_r;
  tri data;

  /////////////////////////////////
  // PCM FIFO capture interface //
  ///////////////////////////////
  logic pos_pcm_cap_rdy_i;
  logic neg_pcm_cap_rdy_i;
  logic signed [15:0] pcm_pos_o;
  logic pcm_valid_pos_o;
  logic signed [15:0] pcm_neg_o;
  logic pcm_valid_neg_o;

  logic pos_pcm_accept;
  logic neg_pcm_accept;
  logic fifo_pop;
  logic pos_pcm_x;
  logic neg_pcm_x;

  int error_count;
  int pcm_x_error_count;
  int fifo_read_cntr;
  int pos_fifo_level, neg_fifo_level;
  int pos_sample_count, neg_sample_count;
  real pos_pass_tone, neg_pass_tone;
  logic signed [15:0] pos_samples[0:MAX_PCM_SAMPLES-1];
  logic signed [15:0] neg_samples[0:MAX_PCM_SAMPLES-1];
  realtime pos_sample_time_ns[0:MAX_PCM_SAMPLES-1];
  realtime neg_sample_time_ns[0:MAX_PCM_SAMPLES-1];

  ///////////////////////////////////////////
  // Clock, bus resolution, and wait flags //
  /////////////////////////////////////////
  always #10 clk = ~clk;

  // The two mic models share one physical PDM DATA wire.
  assign data = data_l;
  assign data = data_r;

  // These one-bit helpers let WaitTask watch normal logic signals.
  always_comb begin
    dut_volt_on_hi = (dut_volt_on === 1'b1);
    curr_mode_std = (curr_mode === MODE_STD);
    pcm_samples_ready = (pos_sample_count >= TONE_TOTAL_SAMPLES) &&
                        (neg_sample_count >= TONE_TOTAL_SAMPLES);
  end

  //////////////////////////////////
  // FIFO-style PCM sink model   //
  ////////////////////////////////
  // Ready stays high while there is FIFO space. The bench drains one entry
  // every FIFO_READ_GAP_CYCLES to exercise normal backpressure behavior.
  assign pos_pcm_cap_rdy_i = !rst && !clr_capture && (pos_fifo_level < FIFO_DEPTH);
  assign neg_pcm_cap_rdy_i = !rst && !clr_capture && (neg_fifo_level < FIFO_DEPTH);
  assign pos_pcm_accept = pcm_valid_pos_o && pos_pcm_cap_rdy_i;
  assign neg_pcm_accept = pcm_valid_neg_o && neg_pcm_cap_rdy_i;
  assign fifo_pop = (fifo_read_cntr == (FIFO_READ_GAP_CYCLES - 1));
  assign pos_pcm_x = pos_pcm_accept && (^pcm_pos_o === 1'bx);
  assign neg_pcm_x = neg_pcm_accept && (^pcm_neg_o === 1'bx);

  // The mic models see the real rail directly. The DUT must discover that
  // same rail through the ADC serial return path below.
  always_ff @(posedge clk) begin
    if (rst) mic_vdd_on <= 1'b0;
    else if (vdd_v < 1.611) mic_vdd_on <= 1'b0;
    else if (vdd_v > 1.624) mic_vdd_on <= 1'b1;
  end

  //////////////////////
  // Instantiate DUT //
  ////////////////////
  Pdm_To_Pcm iDUT (
      .clk_i            (clk),
      .rst_i            (rst),
      .mic_clk_i        (mic_clk),
      .mic_clk_val_i    (data_val),
      .freq_sel_i       (freq_sel),
      .mic_data_i       (data),
      .pos_pcm_cap_rdy_i(pos_pcm_cap_rdy_i),
      .neg_pcm_cap_rdy_i(neg_pcm_cap_rdy_i),

      .pcm_pos_o      (pcm_pos_o),
      .pcm_valid_pos_o(pcm_valid_pos_o),
      .pcm_neg_o      (pcm_neg_o),
      .pcm_valid_neg_o(pcm_valid_neg_o)
  );

  // Audio Front End generates the mic clock exactly like the integrated design.
  Audio_Front_End #(
      .SYS_CLK_HZ(SYS_CLK_HZ),
      .FAST_SIM(FAST_SIM),
      .FAST_SIM_DIV(FAST_SIM_DIV)
  ) iAFE (
      .clk_i(clk),
      .rst_i(rst),
      .mode_req_i(mode_req),

      .ADC_data_out_i(adc_data_out),
      .ADC_CS_o(adc_cs),
      .ADC_SCLK_o(adc_sclk),
      .ADC_data_in_o(adc_data_in),

      .data_val_o (data_val),
      .curr_mode_o(curr_mode),
      .mic_clk_o  (mic_clk)
  );

  assign dut_volt_on = iAFE.volt_on;

  // Left mic drives DATA on falling clock edges.
  SPH0641LU4H_1_model #(
      .FAST_SIM(FAST_SIM),
      .FAST_SIM_DIV(FAST_SIM_DIV),
      .TONE_FREQ_HZ(TONE_FREQ_HZ)
  ) iMIC_MODEL_L (
      .vdd_i(mic_vdd_on),
      .clock_i(mic_clk),
      .select_i(1'b0),

      .data_o(data_l)
  );

  // Right mic drives DATA on rising clock edges.
  SPH0641LU4H_1_model #(
      .FAST_SIM(FAST_SIM),
      .FAST_SIM_DIV(FAST_SIM_DIV),
      .TONE_FREQ_HZ(TONE_FREQ_HZ)
  ) iMIC_MODEL_R (
      .vdd_i(mic_vdd_on),
      .clock_i(mic_clk),
      .select_i(1'b1),

      .data_o(data_r)
  );

  /////////////////////////////////////
  // ADC and PCM capture monitoring //
  ///////////////////////////////////
  // Convert the bench VDD into the 12-bit code returned by the ADC model.
  function automatic logic [11:0] voltage_to_adc_code(input real voltage_v);
    real clamped_v;
    integer scaled_code;
    begin
      clamped_v = voltage_v;

      if (clamped_v < 0.0) begin
        clamped_v = 0.0;
      end else if (clamped_v > 5.0) begin
        clamped_v = 5.0;
      end

      scaled_code = $rtoi(((clamped_v / 5.0) * 4095.0) + 0.5);
      voltage_to_adc_code = scaled_code[11:0];
    end
  endfunction

  // Return the requested channel sample from the capture arrays.
  function automatic int signed get_sample(input bit pos_channel, input int unsigned idx);
    get_sample = pos_channel ? pos_samples[idx] : neg_samples[idx];
  endfunction

  // Return the sample timestamp so the tone check uses measured output timing.
  function automatic realtime get_sample_time(input bit pos_channel, input int unsigned idx);
    get_sample_time = pos_channel ? pos_sample_time_ns[idx] : neg_sample_time_ns[idx];
  endfunction

  // Feed the DUT's ADC controller whenever it starts a conversion.
  always @(negedge adc_cs) begin
    simulate_adc_reading(adc_cs, adc_sclk, adc_data_out, voltage_to_adc_code(vdd_v));
  end

  // Store accepted PCM samples and update the simple FIFO level model.
  always_ff @(posedge clk) begin
    if (clr_x_errors) begin
      pcm_x_error_count <= 0;
    end else if (rst || clr_capture) begin
      fifo_read_cntr <= 0;
      pos_fifo_level <= 0;
      neg_fifo_level <= 0;
      pos_sample_count <= 0;
      neg_sample_count <= 0;
    end else begin
      if (fifo_pop) fifo_read_cntr <= 0;
      else fifo_read_cntr <= fifo_read_cntr + 1;

      unique case ({pos_pcm_accept, fifo_pop && (pos_fifo_level != 0)})
        2'b10: pos_fifo_level <= pos_fifo_level + 1;
        2'b01: pos_fifo_level <= pos_fifo_level - 1;
        default: pos_fifo_level <= pos_fifo_level;
      endcase

      unique case ({neg_pcm_accept, fifo_pop && (neg_fifo_level != 0)})
        2'b10: neg_fifo_level <= neg_fifo_level + 1;
        2'b01: neg_fifo_level <= neg_fifo_level - 1;
        default: neg_fifo_level <= neg_fifo_level;
      endcase

      if (pos_pcm_accept) begin
        if (pos_pcm_x) begin
          $error("ERROR: POS PCM sample has X when accepted by the FIFO!");
          pcm_x_error_count <= pcm_x_error_count + 1;
        end else if (pos_sample_count < MAX_PCM_SAMPLES) begin
          pos_samples[pos_sample_count] <= pcm_pos_o;
          pos_sample_time_ns[pos_sample_count] <= $realtime;
          pos_sample_count <= pos_sample_count + 1;
        end
      end

      if (neg_pcm_accept) begin
        if (neg_pcm_x) begin
          $error("ERROR: NEG PCM sample has X when accepted by the FIFO!");
          pcm_x_error_count <= pcm_x_error_count + 1;
        end else if (neg_sample_count < MAX_PCM_SAMPLES) begin
          neg_samples[neg_sample_count] <= pcm_neg_o;
          neg_sample_time_ns[neg_sample_count] <= $realtime;
          neg_sample_count <= neg_sample_count + 1;
        end
      end
    end
  end

  //////////////////////////
  // Testbench utilities //
  ////////////////////////
  task automatic clear_pcm_capture();
    begin
      @(negedge clk);
      clr_capture = 1'b1;
      @(negedge clk);
      clr_capture = 1'b0;
    end
  endtask

  task automatic wait_for_pcm_samples(input string label);
    WaitTask(clk, error_count, pcm_samples_ready, PCM_TIMEOUT_CYCLES, label);
  endtask

  task automatic check_outputs_quiet();
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
  endtask

  task automatic request_std_mode();
    begin
      @(negedge clk) begin
        mode_req = MODE_STD;
        set_vdd(vdd_v, MIC_VDD_ON_V);
      end

      WaitTask(clk, error_count, dut_volt_on_hi, POWERUP_CYCLES + FSM_MARGIN_CYCLES,
               "Audio Front End ADC-derived volt_on");
      WaitTask(clk, error_count, curr_mode_std, POWERUP_CYCLES + FSM_MARGIN_CYCLES,
               "STANDARD mic mode");
      WaitTask(clk, error_count, data_val, POWERUP_CYCLES + FSM_MARGIN_CYCLES,
               "STANDARD mic data valid");
    end
  endtask

  // Calculate peak-to-peak swing over the last TONE_CHECK_SAMPLES samples.
  function automatic real calc_swing(input bit pos_channel);
    int sample_count;
    int start_idx;
    int stop_idx;
    int idx;
    real sample_value;
    real min_sample;
    real max_sample;
    begin
      sample_count = pos_channel ? pos_sample_count : neg_sample_count;
      stop_idx = sample_count;
      start_idx = sample_count - TONE_CHECK_SAMPLES;
      min_sample = real'(get_sample(pos_channel, start_idx));
      max_sample = min_sample;

      for (idx = start_idx; idx < stop_idx; idx += 1) begin
        sample_value = real'(get_sample(pos_channel, idx));
        if (sample_value < min_sample) min_sample = sample_value;
        if (sample_value > max_sample) max_sample = sample_value;
      end

      calc_swing = max_sample - min_sample;
    end
  endfunction

  // Correlate captured PCM samples against the known mic-model tone.
  function automatic real calc_tone_corr(input bit pos_channel);
    int sample_count;
    int start_idx;
    int stop_idx;
    int idx;
    real mean;
    real centered_sample;
    real angle_rad;
    real sin_accum;
    real cos_accum;
    real sample_energy;
    real ref_energy;
    real time_s;
    begin
      sample_count = pos_channel ? pos_sample_count : neg_sample_count;
      stop_idx = sample_count;
      start_idx = sample_count - TONE_CHECK_SAMPLES;
      mean = 0.0;
      sin_accum = 0.0;
      cos_accum = 0.0;
      sample_energy = 0.0;
      ref_energy = 0.0;

      for (idx = start_idx; idx < stop_idx; idx += 1) begin
        mean += real'(get_sample(pos_channel, idx));
      end

      mean = mean / real'(TONE_CHECK_SAMPLES);

      for (idx = start_idx; idx < stop_idx; idx += 1) begin
        centered_sample = real'(get_sample(pos_channel, idx)) - mean;
        time_s = get_sample_time(pos_channel, idx) * 1.0e-9;
        angle_rad = 6.283185307179586 * real'(TONE_FREQ_HZ) * time_s;

        sin_accum += centered_sample * $sin(angle_rad);
        cos_accum += centered_sample * $cos(angle_rad);
        sample_energy += centered_sample * centered_sample;
        ref_energy += 1.0;
      end

      if ((sample_energy == 0.0) || (ref_energy == 0.0)) begin
        calc_tone_corr = 0.0;
      end else begin
        calc_tone_corr = $sqrt((sin_accum * sin_accum) + (cos_accum * cos_accum)) /
                         $sqrt(sample_energy * ref_energy);
      end
    end
  endfunction

  task automatic check_channel(input bit pos_channel, input bit expect_pass, input real pass_tone,
                               input string label, output real measured_swing,
                               output real measured_tone);
    int sample_count;
    real tone_corr;
    real stop_limit;
    begin
      sample_count = pos_channel ? pos_sample_count : neg_sample_count;

      if (sample_count < TONE_TOTAL_SAMPLES) begin
        $error("ERROR: %s captured only %0d PCM samples.", label, sample_count);
        error_count += 1;
        measured_swing = 0.0;
        measured_tone = 0.0;
        return;
      end

      measured_swing = calc_swing(pos_channel);
      tone_corr = calc_tone_corr(pos_channel);
      measured_tone = measured_swing * tone_corr;
      stop_limit = pass_tone * MAX_STOP_TONE_RATIO;

      $display("%s swing: %.1f, 15 kHz correlation: %.3f, tone level: %.1f.", label,
               measured_swing, tone_corr, measured_tone);

      if (expect_pass) begin
        if (measured_swing < real'(MIN_PASS_SWING)) begin
          $error("ERROR: %s PCM swing is too small for the pass band.", label);
          error_count += 1;
        end

        if (tone_corr < MIN_TONE_CORR) begin
          $error("ERROR: %s does not correlate with the expected %0d Hz tone.", label,
                 TONE_FREQ_HZ);
          error_count += 1;
        end
      end else if (measured_tone > stop_limit) begin
        $error("ERROR: %s did not attenuate the %0d Hz tone enough.", label, TONE_FREQ_HZ);
        error_count += 1;
      end
    end
  endtask

  task automatic check_band(input string label, input bit expect_pass);
    real pos_swing;
    real neg_swing;
    real pos_tone;
    real neg_tone;
    begin
      check_channel(1'b1, expect_pass, pos_pass_tone, {label, " POS channel"}, pos_swing,
                    pos_tone);
      check_channel(1'b0, expect_pass, neg_pass_tone, {label, " NEG channel"}, neg_swing,
                    neg_tone);

      if (expect_pass) begin
        pos_pass_tone = pos_tone;
        neg_pass_tone = neg_tone;
      end
    end
  endtask

  task automatic run_band_check(input int test_num, input logic [1:0] next_freq_sel,
                                input bit expect_pass, input string label);
    begin
      announce_test(test_num, label);

      @(negedge clk) freq_sel = next_freq_sel;
      clear_pcm_capture();
      wait_for_pcm_samples({label, " PCM samples"});
      check_band(label, expect_pass);
    end
  endtask

  ////////////////////////
  // Main test sequence //
  //////////////////////
  initial begin
    clk = 1'b0;
    rst = 1'b1;
    mode_req = MODE_STD;
    freq_sel = BAND_10_18;
    adc_data_out = 1'b0;
    vdd_v = 0.0;
    clr_capture = 1'b1;
    clr_x_errors = 1'b1;
    error_count = 0;
    pos_pass_tone = 0.0;
    neg_pass_tone = 0.0;

    wait_n_negedges(clk, 8);
    clr_x_errors = 1'b0;
    rst = 1'b0;
    wait_n_negedges(clk, 4);
    clr_capture = 1'b0;

    // TEST 1: Outputs should stay quiet immediately after reset.
    announce_test(1, "Outputs should be quiet immediately after reset.");
    check_outputs_quiet();

    // TEST 2: Bring up the real AFE path so the mic models produce PDM.
    announce_test(2, "Audio Front End should power up the microphones in STANDARD mode.");
    request_std_mode();

    // TEST 3: A 15 kHz tone should pass through the 10-18 kHz band.
    run_band_check(3, BAND_10_18, 1'b1, "10-18 kHz band should pass the 15 kHz tone.");

    // TEST 4-6: The same 15 kHz tone should be rejected by higher bands.
    run_band_check(4, BAND_18_25, 1'b0, "18-25 kHz band should cut the 15 kHz tone.");
    run_band_check(5, BAND_25_32, 1'b0, "25-32 kHz band should cut the 15 kHz tone.");
    run_band_check(6, BAND_32_40, 1'b0, "32-40 kHz band should cut the 15 kHz tone.");

    if ((error_count + pcm_x_error_count) == 0) begin
      $display("YAHOO!! All Pdm_To_Pcm tests passed.");
    end else begin
      $error("ERROR: %0d Pdm_To_Pcm test(s) failed.", error_count + pcm_x_error_count);
    end

    $stop();
  end

endmodule
