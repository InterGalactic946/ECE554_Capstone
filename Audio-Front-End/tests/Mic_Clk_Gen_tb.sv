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
  logic [2:0] mode_req;
  logic data_val;
  tri data_l;
  tri data_r;
  tri data;
  logic [1:0] curr_mode;
  logic mic_clk;
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

  ///////////////////
  // TB utilities //
  /////////////////
  task automatic wait_n_negedges(input int unsigned num_edges);
    repeat (num_edges) @(negedge clk);
  endtask : wait_n_negedges

  task automatic clear_capture_state();
    begin
      left_sample_count = 0;
      right_sample_count = 0;
      left_toggle_count = 0;
      right_toggle_count = 0;
      left_prev_bit = 1'b0;
      right_prev_bit = 1'b0;
      left_prev_valid = 1'b0;
      right_prev_valid = 1'b0;
    end
  endtask : clear_capture_state

  task automatic set_vdd(input real new_vdd_v);
    begin
      vdd_v = new_vdd_v;
      #1;
    end
  endtask : set_vdd

  task automatic wait_n_mic_edges(input int unsigned num_edges);
    int unsigned edge_idx;
    begin
      for (edge_idx = 0; edge_idx < num_edges; edge_idx += 1) begin
        @(posedge mic_clk or negedge mic_clk);
      end
    end
  endtask : wait_n_mic_edges

  task automatic TimeoutTask(input logic sig, input int clks2wait, input string signal);
    fork
      begin : timeout
        repeat (clks2wait) @(posedge clk);
        $error("ERROR: %s not getting asserted and/or held at its value.", signal);
        error_count += 1;
        $stop();
      end : timeout
      begin
        @(posedge sig) disable timeout;
      end
    join
  endtask : TimeoutTask

  task automatic ramp_vdd(input real start_v, input real stop_v, input real step_v,
                          input int unsigned settle_cycles_per_step);
    real vdd_step;
    begin
      vdd_step = start_v;
      set_vdd(vdd_step);

      if (stop_v >= start_v) begin
        while (vdd_step < stop_v) begin
          wait_n_negedges(settle_cycles_per_step);
          vdd_step = vdd_step + step_v;

          if (vdd_step > stop_v) begin
            vdd_step = stop_v;
          end

          set_vdd(vdd_step);
        end
      end else begin
        while (vdd_step > stop_v) begin
          wait_n_negedges(settle_cycles_per_step);
          vdd_step = vdd_step - step_v;

          if (vdd_step < stop_v) begin
            vdd_step = stop_v;
          end

          set_vdd(vdd_step);
        end
      end
    end
  endtask : ramp_vdd

  task automatic expect_clock_quiet(input int unsigned observe_cycles, input string label);
    int start_edge_count;
    begin
      start_edge_count = mic_clk_edge_count;
      wait_n_negedges(observe_cycles);

      if (mic_clk_edge_count != start_edge_count) begin
        $error("ERROR: mic_clk_o toggled unexpectedly during %s!", label);
        error_count += 1;
      end
    end
  endtask : expect_clock_quiet

  task automatic expect_clock_activity(input int unsigned observe_cycles, input string label);
    int start_edge_count;
    begin
      start_edge_count = mic_clk_edge_count;
      wait_n_negedges(observe_cycles);

      if (mic_clk_edge_count == start_edge_count) begin
        $error("ERROR: mic_clk_o did not toggle during %s!", label);
        error_count += 1;
      end
    end
  endtask : expect_clock_activity

  task automatic wait_for_dual_channel_samples(input int unsigned samples_per_channel,
                                               input int unsigned timeout_cycles,
                                               input string label);
    logic dual_samples_ready;
    begin
      dual_samples_ready = 1'b0;

      fork
        begin
          while ((left_sample_count < samples_per_channel) ||
                 (right_sample_count < samples_per_channel)) begin
            @(negedge clk);
          end
          dual_samples_ready = 1'b1;
        end
        begin
          TimeoutTask(dual_samples_ready, timeout_cycles, $sformatf(
                      "left/right mic samples during %s", label));
        end
      join_any
      disable fork;

    end
  endtask : wait_for_dual_channel_samples

  task automatic check_bus_high_z(input int unsigned edge_pairs, input string label);
    int unsigned pair_idx;
    begin
      for (pair_idx = 0; pair_idx < edge_pairs; pair_idx += 1) begin
        @(posedge mic_clk);
        #1;
        if (data !== 1'bz) begin
          $error("ERROR: Shared data bus was not high-Z on a right-channel edge during %s!", label);
          error_count += 1;
        end

        @(negedge mic_clk);
        #1;
        if (data !== 1'bz) begin
          $error("ERROR: Shared data bus was not high-Z on a left-channel edge during %s!", label);
          error_count += 1;
        end
      end
    end
  endtask : check_bus_high_z

  task automatic announce_test(input int unsigned test_num, input string description);
    begin
      $display("------------------------------------------------------------");
      $display("TEST %0d STARTING @ %0t: %s", test_num, $time, description);
      $display("------------------------------------------------------------");
    end
  endtask : announce_test

  initial begin
    error_count = 0;
    mic_clk_edge_count = 0;
    clear_capture_state();

    clk = 1'b0;
    rst = 1'b1;
    mode_req = 3'h1;
    vdd_v = 0.0;

    wait_n_negedges(5);
    rst = 1'b0;

    // TEST 1: Below-threshold VDD should keep the mic path OFF.
    announce_test(1, "Below-threshold VDD should keep the mic path OFF.");
    @(negedge clk) begin
      mode_req = 3'h6;
      set_vdd(1.55);
    end

    wait_n_negedges(POWERUP_CYCLES + FSM_MARGIN_CYCLES);

    if (volt_on !== 1'b0) begin
      $error("ERROR: volt_on_i asserted below the 1.62 V threshold!");
      error_count += 1;
    end

    if (data_val !== 1'b0) begin
      $error("ERROR: data_val_o went high while VDD was below threshold!");
      error_count += 1;
    end

    expect_clock_quiet(CLOCK_ACTIVITY_OBSERVE_CYCLES, "below-threshold VDD");

    // TEST 2: With power present, request 3'b001 should still map to SLEEP.
    announce_test(2, "With power present, request 3'b001 should still map to SLEEP.");
    @(negedge clk) begin
      mode_req = 3'h1;
    end

    ramp_vdd(1.55, 1.72, 0.03, 2);
    wait_n_negedges(POWERUP_CYCLES + FSM_MARGIN_CYCLES);

    if (volt_on !== 1'b1) begin
      $error("ERROR: volt_on_i did not assert after VDD crossed the threshold!");
      error_count += 1;
    end

    if (curr_mode !== 2'h0) begin
      $error("ERROR: curr_mode_o is not SLEEP after powering up with mode request 3'b001!");
      error_count += 1;
    end

    if (data_val !== 1'b0) begin
      $error("ERROR: data_val_o is not low in SLEEP mode!");
      error_count += 1;
    end

    expect_clock_quiet(CLOCK_ACTIVITY_OBSERVE_CYCLES, "sleep mode after a disabled request");

    // TEST 3: Wake into STANDARD mode and read data from both microphones.
    announce_test(3, "Wake into STANDARD mode and read data from both microphones.");
    clear_capture_state();
    @(negedge clk) mode_req = 3'h6;

    wait_n_negedges(WAKEUP_CYCLES + FSM_MARGIN_CYCLES);

    if (curr_mode !== 2'h2) begin
      $error("ERROR: curr_mode_o is not STANDARD after requesting STANDARD mode!");
      error_count += 1;
    end

    if (data_val !== 1'b1) begin
      $error("ERROR: data_val_o is not high after entering STANDARD mode!");
      error_count += 1;
    end

    wait_for_dual_channel_samples(24, SAMPLE_TIMEOUT_CYCLES, "STANDARD mode");

    // TEST 4: Brownout mid-transition should clear the mic path safely.
    announce_test(4, "Brownout mid-transition should clear the mic path safely.");
    clear_capture_state();
    @(negedge clk) mode_req = 3'h7;

    wait_n_negedges((MODECHANGE_CYCLES / 2) + 2);
    ramp_vdd(vdd_v, 1.55, 0.04, 1);
    wait_n_negedges(FSM_MARGIN_CYCLES);

    if (volt_on !== 1'b0) begin
      $error("ERROR: volt_on_i did not drop after a brownout!");
      error_count += 1;
    end

    if (data_val !== 1'b0) begin
      $error("ERROR: data_val_o did not clear after a brownout!");
      error_count += 1;
    end

    expect_clock_quiet(CLOCK_ACTIVITY_OBSERVE_CYCLES, "brownout recovery");

    // TEST 5: Threshold chatter should not prevent eventual recovery into STANDARD mode.
    announce_test(5, "Threshold chatter should not prevent eventual recovery into STANDARD mode.");
    clear_capture_state();
    @(negedge clk) mode_req = 3'h6;

    set_vdd(1.60);
    wait_n_negedges(2);
    set_vdd(1.63);
    wait_n_negedges(2);
    set_vdd(1.61);
    wait_n_negedges(2);
    set_vdd(1.68);

    wait_n_negedges(POWERUP_CYCLES + FSM_MARGIN_CYCLES);

    if (curr_mode !== 2'h2) begin
      $error("ERROR: curr_mode_o is not STANDARD after threshold chatter recovery!");
      error_count += 1;
    end

    if (data_val !== 1'b1) begin
      $error("ERROR: data_val_o is not high after threshold chatter recovery!");
      error_count += 1;
    end

    wait_for_dual_channel_samples(24, SAMPLE_TIMEOUT_CYCLES, "STANDARD recovery");

    // TEST 6: Direct OFF->ULTRASONIC request should still produce valid stereo data.
    announce_test(6, "Direct OFF->ULTRASONIC request should still produce valid stereo data.");
    clear_capture_state();
    @(negedge clk) begin
      mode_req = 3'h7;
      set_vdd(0.0);
    end

    wait_n_negedges(FSM_MARGIN_CYCLES);
    ramp_vdd(0.0, 1.80, 0.06, 2);
    wait_n_negedges(POWERUP_CYCLES + MODECHANGE_CYCLES + FSM_MARGIN_CYCLES);

    if (curr_mode !== 2'h3) begin
      $error("ERROR: curr_mode_o is not ULTRASONIC after OFF->ULTRASONIC sequencing!");
      error_count += 1;
    end

    if (data_val !== 1'b1) begin
      $error("ERROR: data_val_o is not high after OFF->ULTRASONIC sequencing!");
      error_count += 1;
    end

    wait_for_dual_channel_samples(24, SAMPLE_TIMEOUT_CYCLES, "OFF->ULTRASONIC");

    // TEST 7: A powered request of 3'b001 should return to SLEEP and release the PDM bus.
    announce_test(7, "A powered request of 3'b001 should return to SLEEP and release the PDM bus.");
    clear_capture_state();
    @(negedge clk) mode_req = 3'h1;

    wait_n_negedges(FALLASLEEP_CYCLES + FSM_MARGIN_CYCLES);

    if (curr_mode !== 2'h0) begin
      $error("ERROR: curr_mode_o is not SLEEP after requesting mode 3'b001 while powered!");
      error_count += 1;
    end

    if (data_val !== 1'b0) begin
      $error("ERROR: data_val_o is not low after returning to SLEEP!");
      error_count += 1;
    end

    expect_clock_quiet(CLOCK_ACTIVITY_OBSERVE_CYCLES, "sleep after disabling while powered");

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
