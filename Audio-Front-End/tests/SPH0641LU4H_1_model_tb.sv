`timescale 1ns / 1ps
// ------------------------------------------------------------
// Testbench: SPH0641LU4H_1_model_tb
// Description: Bring up test for the behavioral SPH0641LU4H-1
//              microphone model using only the datasheet pins.
// Author: Srivibhav Jonnalagadda
// Date: 03-26-2026
// ------------------------------------------------------------
module SPH0641LU4H_1_model_tb ();
  import Tb_Util_pkg::*;

  /////////////////////////////
  // Stimulus of type logic //
  ///////////////////////////
  int   error_count;
  int   half_period_ns;
  logic vdd;
  logic clk;
  logic clk_en;
  logic select;
  tri   data;
  tri   data_worst;

  // Test parameters.
  localparam int unsigned FAST_SIM_DIV = 1_000;
  localparam int unsigned TONE_FREQ_HZ = 20_000;
  localparam realtime MIC_DATA_ASSERT_TIME_NS = MIC_TIMING_TYP_DATA_ASSERT_NS;
  localparam realtime MIC_DATA_HIGH_Z_TIME_NS = MIC_TIMING_TYP_DATA_HIGH_Z_NS;
  localparam realtime MIC_WORST_DATA_ASSERT_TIME_NS = MIC_TIMING_WORST_DATA_ASSERT_NS;
  localparam realtime MIC_WORST_DATA_HIGH_Z_TIME_NS = MIC_TIMING_WORST_DATA_HIGH_Z_NS;
  localparam realtime MIC_DATA_SAMPLE_MARGIN_NS = 1.0;
  localparam realtime MIC_STOPPED_CLOCK_TEST_WAIT_NS = 16_000.0;
  localparam int unsigned SINE_WINDOW_COUNT = 8;
  localparam int unsigned SINE_WINDOW_SAMPLES = 32;

  SPH0641LU4H_1_model #(
      .FAST_SIM(1'b1),
      .FAST_SIM_DIV(FAST_SIM_DIV),
      .TONE_FREQ_HZ(TONE_FREQ_HZ),
      .MIC_DATA_ASSERT_TIME_NS(MIC_DATA_ASSERT_TIME_NS),
      .MIC_DATA_HIGH_Z_TIME_NS(MIC_DATA_HIGH_Z_TIME_NS)
  ) iDUT (
      .vdd_i(vdd),
      .clock_i(clk),
      .select_i(select),
      .data_o(data)
  );

  SPH0641LU4H_1_model #(
      .FAST_SIM(1'b1),
      .FAST_SIM_DIV(FAST_SIM_DIV),
      .TONE_FREQ_HZ(TONE_FREQ_HZ),
      .MIC_DATA_ASSERT_TIME_NS(MIC_WORST_DATA_ASSERT_TIME_NS),
      .MIC_DATA_HIGH_Z_TIME_NS(MIC_WORST_DATA_HIGH_Z_TIME_NS)
  ) iDUT_WORST (
      .vdd_i(vdd),
      .clock_i(clk),
      .select_i(select),
      .data_o(data_worst)
  );

  // Capture PDM bits on whichever clock edge SELECT makes active.
  task automatic capture_selected_edge_stats(input int unsigned sample_count, output int ones_count,
                                             output int zeros_count, input string label);
    int unsigned sample_idx;
    begin
      ones_count  = 0;
      zeros_count = 0;

      for (sample_idx = 0; sample_idx < sample_count; sample_idx += 1) begin
        if (select) begin
          @(posedge clk);
        end else begin
          @(negedge clk);
        end

        #(MIC_DATA_ASSERT_TIME_NS + MIC_DATA_SAMPLE_MARGIN_NS);

        if (data === 1'b1) begin
          ones_count += 1;
        end else if (data === 1'b0) begin
          zeros_count += 1;
        end else begin
          $error("ERROR: data_o was not driven during %s sample %0d!", label, sample_idx);
          error_count += 1;
        end
      end
    end
  endtask : capture_selected_edge_stats

  // A sine-backed PDM stream should contain both polarities and changing local density.
  task automatic check_sine_pdm_density(input int unsigned window_count,
                                        input int unsigned window_samples, input string label);
    int unsigned window_idx;
    int ones_count;
    int zeros_count;
    int total_ones;
    int total_zeros;
    int density_min;
    int density_max;
    begin
      total_ones  = 0;
      total_zeros = 0;
      density_min = window_samples;
      density_max = 0;

      // Capture multiple windows of the PDM stream and track the number of 1s vs 0s in each to check
      // that the density changes as expected for a sine wave. We also track the total number of 1s
      // and 0s across all windows to check that both polarities are present.
      for (window_idx = 0; window_idx < window_count; window_idx += 1) begin
        capture_selected_edge_stats(window_samples, ones_count, zeros_count, label);
        total_ones += ones_count;
        total_zeros += zeros_count;

        if (ones_count < density_min) begin
          density_min = ones_count;
        end

        if (ones_count > density_max) begin
          density_max = ones_count;
        end
      end

      if ((total_ones == 0) || (total_zeros == 0)) begin
        $error("ERROR: %s did not produce both 0 and 1 PDM bits!", label);
        error_count += 1;
      end

      // For a 20 kHz sine wave sampled at 50 kHz, the density should vary from near 0 to near 
      // 32 across a window of 32 samples. Allow some margin for the discrete nature of the samples,
      // but flag if the density variation is too small.
      if ((density_max - density_min) < (window_samples / 4)) begin
        $error("ERROR: %s did not show enough sine-wave PDM density variation!", label);
        error_count += 1;
      end
    end
  endtask : check_sine_pdm_density

  initial begin
    error_count = 0;
    vdd = 1'b0;
    clk = 1'b0;
    clk_en = 1'b1;
    select = 1'b1;
    half_period_ns = 4_000;

    // TEST 1: Power-down keeps DATA high-Z.
    wait_n_posedges(clk, 4);

    if (data !== 1'bz) begin
      $error("ERROR: data_o is not high-Z when the microphone is powered down!");
      error_count += 1;
    end

    if (data_worst !== 1'bz) begin
      $error("ERROR: worst-case data_o is not high-Z when the microphone is powered down!");
      error_count += 1;
    end

    // TEST 2: Power-up with a sleep clock keeps DATA high-Z.
    vdd = 1'b1;
    wait_n_posedges(clk, 16);

    if (data !== 1'bz) begin
      $error("ERROR: data_o is not high-Z in SLEEP mode!");
      error_count += 1;
    end

    if (data_worst !== 1'bz) begin
      $error("ERROR: worst-case data_o is not high-Z in SLEEP mode!");
      error_count += 1;
    end

    // TEST 3: Direct power-up into ULTRASONIC is treated as illegal and stays high-Z.
    vdd = 1'b0;
    wait_n_posedges(clk, 4);
    half_period_ns = 156;
    vdd = 1'b1;
    wait_n_posedges(clk, 24);

    @(posedge clk);
    #1;
    if (data !== 1'bz) begin
      $error("ERROR: data_o should stay high-Z after illegal direct ULTRASONIC power-up!");
      error_count += 1;
    end

    // TEST 4: Recover with a legal STANDARD clock and ensure DATA becomes active.
    half_period_ns = 400;
    wait_n_posedges(clk, 96);

    @(posedge clk);
    #(MIC_DATA_ASSERT_TIME_NS + MIC_DATA_SAMPLE_MARGIN_NS);
    if (data === 1'bz) begin
      $error(
          "ERROR: data_o did not recover on the selected rising edge after returning to STANDARD mode!");
      error_count += 1;
    end

    @(negedge clk);
    #(MIC_DATA_HIGH_Z_TIME_NS + MIC_DATA_SAMPLE_MARGIN_NS);
    if (data !== 1'bz) begin
      $error(
          "ERROR: data_o should return to high-Z on the non-selected falling edge in STANDARD mode!");
      error_count += 1;
    end

    // TEST 5: Move to LOW-POWER mode and ensure DATA drives on the selected edge.
    half_period_ns = 1_000;
    wait_n_posedges(clk, 24);

    @(posedge clk);
    #(MIC_DATA_ASSERT_TIME_NS + MIC_DATA_SAMPLE_MARGIN_NS);
    if (data === 1'bz) begin
      $error("ERROR: data_o is still high-Z on the selected rising edge in LOW-POWER mode!");
      error_count += 1;
    end

    @(negedge clk);
    #(MIC_DATA_HIGH_Z_TIME_NS + MIC_DATA_SAMPLE_MARGIN_NS);
    if (data !== 1'bz) begin
      $error("ERROR: data_o should return to high-Z on the non-selected falling edge!");
      error_count += 1;
    end

    // TEST 6: Flip SELECT and ensure DATA moves to the falling edge.
    select = 1'b0;
    wait_n_posedges(clk, 4);

    @(posedge clk);
    #(MIC_DATA_HIGH_Z_TIME_NS + MIC_DATA_SAMPLE_MARGIN_NS);
    if (data !== 1'bz) begin
      $error("ERROR: data_o should stay high-Z on the rising edge after SELECT goes low!");
      error_count += 1;
    end

    @(negedge clk);
    #(MIC_DATA_ASSERT_TIME_NS + MIC_DATA_SAMPLE_MARGIN_NS);
    if (data === 1'bz) begin
      $error("ERROR: data_o is still high-Z on the selected falling edge after SELECT goes low!");
      error_count += 1;
    end

    // TEST 7: Move to ULTRASONIC mode from an active legal mode and ensure DATA remains active.
    half_period_ns = 156;
    wait_n_posedges(clk, 40);

    @(negedge clk);
    #(MIC_DATA_ASSERT_TIME_NS + MIC_DATA_SAMPLE_MARGIN_NS);
    if (data === 1'bz) begin
      $error("ERROR: data_o is high-Z on the selected falling edge in ULTRASONIC mode!");
      error_count += 1;
    end

    // TEST 8: Timing corners should hold DATA before tDD and release after tDZ.
    @(posedge clk);
    #(MIC_WORST_DATA_HIGH_Z_TIME_NS + MIC_DATA_SAMPLE_MARGIN_NS);

    if (data !== 1'bz) begin
      $error("ERROR: typical data_o did not release before timing-corner check!");
      error_count += 1;
    end

    if (data_worst !== 1'bz) begin
      $error("ERROR: worst-case data_o did not release before timing-corner check!");
      error_count += 1;
    end

    @(negedge clk);
    #(MIC_DATA_ASSERT_TIME_NS - MIC_DATA_SAMPLE_MARGIN_NS);

    if (data !== 1'bz) begin
      $error("ERROR: typical data_o asserted before tDD elapsed!");
      error_count += 1;
    end

    if (data_worst !== 1'bz) begin
      $error("ERROR: worst-case data_o asserted before tDD elapsed!");
      error_count += 1;
    end

    #(2.0 * MIC_DATA_SAMPLE_MARGIN_NS);

    if (data === 1'bz) begin
      $error("ERROR: typical data_o did not assert after typical tDD elapsed!");
      error_count += 1;
    end

    if (data_worst !== 1'bz) begin
      $error("ERROR: worst-case data_o asserted before worst-case tDD elapsed!");
      error_count += 1;
    end

    #(MIC_WORST_DATA_ASSERT_TIME_NS - MIC_DATA_ASSERT_TIME_NS + MIC_DATA_SAMPLE_MARGIN_NS);

    if (data_worst === 1'bz) begin
      $error("ERROR: worst-case data_o did not assert after worst-case tDD elapsed!");
      error_count += 1;
    end

    @(posedge clk);
    #(MIC_DATA_HIGH_Z_TIME_NS + MIC_DATA_SAMPLE_MARGIN_NS);

    if (data !== 1'bz) begin
      $error("ERROR: typical data_o did not release after typical tDZ elapsed!");
      error_count += 1;
    end

    if (data_worst === 1'bz) begin
      $error("ERROR: worst-case data_o released before worst-case tDZ elapsed!");
      error_count += 1;
    end

    #(MIC_WORST_DATA_HIGH_Z_TIME_NS - MIC_DATA_HIGH_Z_TIME_NS + MIC_DATA_SAMPLE_MARGIN_NS);

    if (data_worst !== 1'bz) begin
      $error("ERROR: worst-case data_o did not release after worst-case tDZ elapsed!");
      error_count += 1;
    end

    // TEST 9: Sine-wave PDM should produce both bit values and changing density.
    check_sine_pdm_density(SINE_WINDOW_COUNT, SINE_WINDOW_SAMPLES, "sine-wave PDM stream");

    // TEST 10: Power-down returns DATA to high-Z immediately while active.
    vdd = 1'b0;
    #1;

    if (data !== 1'bz) begin
      $error("ERROR: data_o is not high-Z after power-down!");
      error_count += 1;
    end

    if (data_worst !== 1'bz) begin
      $error("ERROR: worst-case data_o is not high-Z after power-down!");
      error_count += 1;
    end

    // TEST 11: A stopped active clock should settle the mic into SLEEP and release DATA.
    select = 1'b1;
    half_period_ns = 400;
    wait_n_posedges(clk, 4);
    vdd = 1'b1;
    wait_n_posedges(clk, 96);

    @(posedge clk);
    #(MIC_DATA_ASSERT_TIME_NS + MIC_DATA_SAMPLE_MARGIN_NS);
    if (data === 1'bz) begin
      $error("ERROR: data_o was not active before the stopped-clock sleep test!");
      error_count += 1;
    end

    clk_en = 1'b0;
    #(MIC_STOPPED_CLOCK_TEST_WAIT_NS);

    if (data !== 1'bz) begin
      $error("ERROR: data_o did not release after the active microphone clock stopped!");
      error_count += 1;
    end

    if (data_worst !== 1'bz) begin
      $error("ERROR: worst-case data_o did not release after the active microphone clock stopped!");
      error_count += 1;
    end

    if (error_count == 0) begin
      $display("YAHOO!! SPH0641LU4H_1_model stress test passed.");
    end else begin
      $error("ERROR: %0d SPH0641LU4H_1_model bring up test(s) failed.", error_count);
    end

    $stop();
  end

  always #(half_period_ns) begin
    if (clk_en) begin
      clk = ~clk;
    end
  end

endmodule
