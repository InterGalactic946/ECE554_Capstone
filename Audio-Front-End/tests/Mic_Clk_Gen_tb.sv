`timescale 1ns / 1ps
// ------------------------------------------------------------
// Testbench: Mic_Clk_Gen_tb
// Description: Verifies Mic_Clk_Gen behavior in conjunction
//              with the mic model. This bench models VDD as a
//              real-valued supply and derives volt_on from
//              the 1.62 V threshold used by the microphone.
//              It also checks edge cases such as threshold
//              chatter, brownouts, and direct ultrasonic
//              requests while reading left/right mic data from
//              the shared PDM line.
// Author: Srivibhav Jonnalagadda
// Date: 03-24-2026
// ------------------------------------------------------------
module Mic_Clk_Gen_tb ();
  import Mic_Time_pkg::*;
  import Tb_Util_pkg::*;

  localparam int unsigned SYS_CLK_HZ = 50_000_000;
  localparam bit FAST_SIM = 1'b1;
  localparam int unsigned FAST_SIM_DIV = 1000;
  localparam real VDD_ON_THRESHOLD_V = 1.62;
  localparam int unsigned FSM_MARGIN_CYCLES = 256;
  localparam int unsigned CLOCK_ACTIVITY_OBSERVE_CYCLES = 256;
  localparam int unsigned SAMPLE_TIMEOUT_CYCLES = 50_000;

  /////////////////////////////
  // Stimulus of type logic //
  ///////////////////////////
  logic clk;
  logic rst;
  logic volt_on;
  logic [1:0] mode_req;
  logic data_val;
  tri data_l;
  tri data_r;
  tri data;
  logic data_bus_mon;
  logic [1:0] curr_mode;
  logic mic_clk;
  logic dual_samples_ready;
  real vdd_v;
  int error_count;

  ////////////////////////////////////////////////////
  // Data capture state for left/right microphones //
  //////////////////////////////////////////////////
  int mic_clk_edge_count;
  int left_sample_count, right_sample_count;
  int left_toggle_count, right_toggle_count;
  logic left_prev_bit, right_prev_bit;
  logic left_prev_valid, right_prev_valid;

  localparam int unsigned POWERUP_CYCLES = mic_cycles_from_ms(
      SYS_CLK_HZ, MIC_POWERUP_MS, FAST_SIM, FAST_SIM_DIV
  );
  localparam int unsigned WAKEUP_CYCLES = mic_cycles_from_ms(
      SYS_CLK_HZ, MIC_WAKEUP_MS, FAST_SIM, FAST_SIM_DIV
  );
  localparam int unsigned MODECHANGE_CYCLES = mic_cycles_from_ms(
      SYS_CLK_HZ, MIC_MODECHANGE_MS, FAST_SIM, FAST_SIM_DIV
  );
  localparam int unsigned FALLASLEEP_CYCLES = mic_cycles_from_ms(
      SYS_CLK_HZ, MIC_FALLASLEEP_MS, FAST_SIM, FAST_SIM_DIV
  );

  // Convert the analog-style supply to the digital power-good input used by the DUT.
  always_comb begin
    volt_on = (vdd_v >= VDD_ON_THRESHOLD_V);
  end

  // 50 MHz reference clock for the clock generator.
  always #10 clk = ~clk;


  // Track that the generated mic clock is alive or quiescent as expected.
  always @(posedge mic_clk or negedge mic_clk) begin
    mic_clk_edge_count += 1;
  end

  // Resolve the individual microphone drivers onto the shared PDM wire.
  assign data = data_l;
  assign data = data_r;

  // Mirror shared-bus activity and sample-ready status onto logic signals.
  always_comb begin
    data_bus_mon = data;
    dual_samples_ready = (left_sample_count >= 24) && (right_sample_count >= 24);
  end

  // Sample the left microphone on falling mic-clock edges.
  always @(negedge mic_clk) begin
    if (data_val && iMIC_MODEL_L.model_active) begin
      #1;
      if ((data_l !== 1'b0) && (data_l !== 1'b1)) begin
        $error("ERROR: Left microphone did not drive DATA on its active edge!");
        error_count += 1;
      end

      if (data_r !== 1'bz) begin
        $error("ERROR: Right microphone was not high-Z on the left microphone edge!");
        error_count += 1;
      end

      if ((data_l === 1'b0) || (data_l === 1'b1)) begin
        if (data !== data_l) begin
          $error(
              "ERROR: Shared data bus did not resolve to the left microphone on its active edge!");
          error_count += 1;
        end

        left_sample_count += 1;

        if (left_prev_valid && (data_l != left_prev_bit)) begin
          left_toggle_count += 1;
        end

        left_prev_bit   = data_l;
        left_prev_valid = 1'b1;
      end
    end
  end

  // Sample the right microphone on rising mic-clock edges.
  always @(posedge mic_clk) begin
    if (data_val && iMIC_MODEL_R.model_active) begin
      #1;
      if ((data_r !== 1'b0) && (data_r !== 1'b1)) begin
        $error("ERROR: Right microphone did not drive DATA on its active edge!");
        error_count += 1;
      end

      if (data_l !== 1'bz) begin
        $error("ERROR: Left microphone was not high-Z on the right microphone edge!");
        error_count += 1;
      end

      if ((data_r === 1'b0) || (data_r === 1'b1)) begin
        if (data !== data_r) begin
          $error(
              "ERROR: Shared data bus did not resolve to the right microphone on its active edge!");
          error_count += 1;
        end

        right_sample_count += 1;

        if (right_prev_valid && (data_r != right_prev_bit)) begin
          right_toggle_count += 1;
        end

        right_prev_bit   = data_r;
        right_prev_valid = 1'b1;
      end
    end
  end

  // Instantiate Clock Generator
  Mic_Clk_Gen #(
      .SYS_CLK_HZ(SYS_CLK_HZ),
      .FAST_SIM(FAST_SIM),
      .FAST_SIM_DIV(FAST_SIM_DIV)
  ) iCLK_GEN (
      .clk_i(clk),
      .rst_i(rst),
      .volt_on_i(volt_on),
      .mode_req_i(mode_req),

      .data_val_o (data_val),
      .curr_mode_o(curr_mode),
      .mic_clk_o  (mic_clk)
  );

  // Instantiate left mic.
  SPH0641LU4H_1_model #(
      .FAST_SIM(FAST_SIM),
      .FAST_SIM_DIV(FAST_SIM_DIV)
  ) iMIC_MODEL_L (
      .vdd_i(volt_on),
      .clock_i(mic_clk),
      .select_i(1'b0),

      .data_o(data_l)
  );

  // Instantiate right mic.
  SPH0641LU4H_1_model #(
      .FAST_SIM(FAST_SIM),
      .FAST_SIM_DIV(FAST_SIM_DIV)
  ) iMIC_MODEL_R (
      .vdd_i(volt_on),
      .clock_i(mic_clk),
      .select_i(1'b1),

      .data_o(data_r)
  );

  initial begin
    error_count = 0;
    mic_clk_edge_count = 0;
    clear_capture_state(left_sample_count, right_sample_count, left_toggle_count,
                        right_toggle_count, left_prev_bit, right_prev_bit, left_prev_valid,
                        right_prev_valid);

    clk = 1'b0;
    rst = 1'b1;
    mode_req = 2'h1;
    vdd_v = 0.0;

    wait_n_negedges(clk, 5);
    rst = 1'b0;

    // TEST 1: Below-threshold VDD should keep the mic path OFF.
    announce_test(1, "Below-threshold VDD should keep the mic path OFF.");
    @(negedge clk) begin
      mode_req = 2'h2;
      set_vdd(vdd_v, 1.55);
    end

    wait_n_negedges(clk, POWERUP_CYCLES + FSM_MARGIN_CYCLES);

    if (volt_on !== 1'b0) begin
      $error("ERROR: volt_on_i asserted below the 1.62 V threshold!");
      error_count += 1;
    end

    if (data_val !== 1'b0) begin
      $error("ERROR: data_val_o went high while VDD was below threshold!");
      error_count += 1;
    end

    expect_clock_quiet(clk, mic_clk_edge_count, error_count, CLOCK_ACTIVITY_OBSERVE_CYCLES,
                       "below-threshold VDD");

    // TEST 2: With power present, request 2'b01 should still map to SLEEP.
    announce_test(2, "With power present, request 2'b00 should still map to SLEEP.");
    @(negedge clk) begin
      mode_req = 2'h0;
    end

    ramp_vdd(clk, vdd_v, 1.55, 1.72, 0.03, 2);
    wait_n_negedges(clk, POWERUP_CYCLES + FSM_MARGIN_CYCLES);

    if (volt_on !== 1'b1) begin
      $error("ERROR: volt_on_i did not assert after VDD crossed the threshold!");
      error_count += 1;
    end

    if (curr_mode !== 2'h1) begin
      $error("ERROR: curr_mode_o is not SLEEP after powering up with mode request 2'b01!");
      error_count += 1;
    end

    if (data_val !== 1'b0) begin
      $error("ERROR: data_val_o is not low in SLEEP mode!");
      error_count += 1;
    end

    expect_clock_quiet(clk, mic_clk_edge_count, error_count, CLOCK_ACTIVITY_OBSERVE_CYCLES,
                       "sleep mode after a disabled request");

    // TEST 3: Wake into STANDARD mode and read data from both microphones.
    announce_test(3, "Wake into STANDARD mode and read data from both microphones.");
    clear_capture_state(left_sample_count, right_sample_count, left_toggle_count,
                        right_toggle_count, left_prev_bit, right_prev_bit, left_prev_valid,
                        right_prev_valid);
    @(negedge clk) mode_req = 2'h2;

    wait_n_negedges(clk, WAKEUP_CYCLES + FSM_MARGIN_CYCLES);

    if (curr_mode !== 2'h2) begin
      $error("ERROR: curr_mode_o is not STANDARD after requesting STANDARD mode!");
      error_count += 1;
    end

    if (data_val !== 1'b1) begin
      $error("ERROR: data_val_o is not high after entering STANDARD mode!");
      error_count += 1;
    end

    WaitTask(clk, error_count, dual_samples_ready, SAMPLE_TIMEOUT_CYCLES,
             "left/right mic samples during STANDARD mode");

    // TEST 4: Brownout mid-transition should clear the mic path safely.
    announce_test(4, "Brownout mid-transition should clear the mic path safely.");
    clear_capture_state(left_sample_count, right_sample_count, left_toggle_count,
                        right_toggle_count, left_prev_bit, right_prev_bit, left_prev_valid,
                        right_prev_valid);
    @(negedge clk) mode_req = 2'h3;

    wait_n_negedges(clk, (MODECHANGE_CYCLES / 2) + 2);
    ramp_vdd(clk, vdd_v, vdd_v, 1.55, 0.04, 1);
    wait_n_negedges(clk, FSM_MARGIN_CYCLES);

    if (volt_on !== 1'b0) begin
      $error("ERROR: volt_on_i did not drop after a brownout!");
      error_count += 1;
    end

    if (data_val !== 1'b0) begin
      $error("ERROR: data_val_o did not clear after a brownout!");
      error_count += 1;
    end

    expect_clock_quiet(clk, mic_clk_edge_count, error_count, CLOCK_ACTIVITY_OBSERVE_CYCLES,
                       "brownout recovery");

    // TEST 5: Threshold chatter should not prevent eventual recovery into STANDARD mode.
    announce_test(5, "Threshold chatter should not prevent eventual recovery into STANDARD mode.");
    clear_capture_state(left_sample_count, right_sample_count, left_toggle_count,
                        right_toggle_count, left_prev_bit, right_prev_bit, left_prev_valid,
                        right_prev_valid);
    @(negedge clk) mode_req = 2'h2;

    set_vdd(vdd_v, 1.60);
    wait_n_negedges(clk, 2);
    set_vdd(vdd_v, 1.63);
    wait_n_negedges(clk, 2);
    set_vdd(vdd_v, 1.61);
    wait_n_negedges(clk, 2);
    set_vdd(vdd_v, 1.68);

    wait_n_negedges(clk, POWERUP_CYCLES + FSM_MARGIN_CYCLES);

    if (curr_mode !== 2'h2) begin
      $error("ERROR: curr_mode_o is not STANDARD after threshold chatter recovery!");
      error_count += 1;
    end

    if (data_val !== 1'b1) begin
      $error("ERROR: data_val_o is not high after threshold chatter recovery!");
      error_count += 1;
    end

    WaitTask(clk, error_count, dual_samples_ready, SAMPLE_TIMEOUT_CYCLES,
             "left/right mic samples during STANDARD recovery");

    // TEST 6: Direct OFF->ULTRASONIC request should still produce valid stereo data.
    announce_test(6, "Direct OFF->ULTRASONIC request should still produce valid stereo data.");
    clear_capture_state(left_sample_count, right_sample_count, left_toggle_count,
                        right_toggle_count, left_prev_bit, right_prev_bit, left_prev_valid,
                        right_prev_valid);
    @(negedge clk) begin
      mode_req = 2'h3;
      set_vdd(vdd_v, 0.0);
    end

    wait_n_negedges(clk, FSM_MARGIN_CYCLES);
    ramp_vdd(clk, vdd_v, 0.0, 1.80, 0.06, 2);
    wait_n_negedges(clk, POWERUP_CYCLES + MODECHANGE_CYCLES + FSM_MARGIN_CYCLES);

    if (curr_mode !== 2'h3) begin
      $error("ERROR: curr_mode_o is not ULTRASONIC after OFF->ULTRASONIC sequencing!");
      error_count += 1;
    end

    if (data_val !== 1'b1) begin
      $error("ERROR: data_val_o is not high after OFF->ULTRASONIC sequencing!");
      error_count += 1;
    end

    WaitTask(clk, error_count, dual_samples_ready, SAMPLE_TIMEOUT_CYCLES,
             "left/right mic samples during OFF->ULTRASONIC");

    // TEST 7: A powered request of 2'b01 should return to SLEEP and release the PDM bus.
    announce_test(7, "A powered request of 2'b01 should return to SLEEP and release the PDM bus.");
    clear_capture_state(left_sample_count, right_sample_count, left_toggle_count,
                        right_toggle_count, left_prev_bit, right_prev_bit, left_prev_valid,
                        right_prev_valid);
    @(negedge clk) mode_req = 2'h1;

    wait_n_negedges(clk, FALLASLEEP_CYCLES + FSM_MARGIN_CYCLES);

    if (curr_mode !== 2'h1) begin
      $error("ERROR: curr_mode_o is not SLEEP after requesting mode 2'b01 while powered!");
      error_count += 1;
    end

    if (data_val !== 1'b0) begin
      $error("ERROR: data_val_o is not low after returning to SLEEP!");
      error_count += 1;
    end

    expect_clock_quiet(clk, mic_clk_edge_count, error_count, CLOCK_ACTIVITY_OBSERVE_CYCLES,
                       "sleep after disabling while powered");

    #1;
    if (data_l !== 1'bz) begin
      $error("ERROR: Left microphone did not release DATA after returning to SLEEP!");
      error_count += 1;
    end

    if (data_r !== 1'bz) begin
      $error("ERROR: Right microphone did not release DATA after returning to SLEEP!");
      error_count += 1;
    end

    if (data !== 1'bz) begin
      $error("ERROR: Shared PDM bus did not return to high-Z after returning to SLEEP!");
      error_count += 1;
    end

    if (error_count == 0) begin
      $display("YAHOO!! All tests passed.");
    end else begin
      $display("ERROR: %0d test(s) failed.", error_count);
    end

    $stop();
  end
endmodule
