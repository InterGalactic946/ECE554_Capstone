`timescale 1ns / 1ps
// ------------------------------------------------------------
// Package: Tb_Util_pkg
// Description: Shared testbench helpers for the Audio Front End
//              verification benches.
// Author: Srivibhav Jonnalagadda
// Date: 04-07-2026
// ------------------------------------------------------------
package Tb_Util_pkg;

  // SPH0641LU4H-1 DATA output timing corners from the datasheet.
  // tDD has a typical and max value; tDZ only provides min/max, so
  // the typical corner uses the fast/min release and worst uses max.
  localparam realtime MIC_TIMING_TYP_DATA_ASSERT_NS = 28.0;
  localparam realtime MIC_TIMING_TYP_DATA_HIGH_Z_NS = 3.0;
  localparam realtime MIC_TIMING_WORST_DATA_ASSERT_NS = 40.0;
  localparam realtime MIC_TIMING_WORST_DATA_HIGH_Z_NS = 16.0;
  localparam realtime MIC_TIMING_DATA_SAMPLE_SKEW_NS = MIC_TIMING_WORST_DATA_ASSERT_NS + 1.0;

  // Allow either sleep-style clock select encoding while transitions settle.
  function automatic bit verify_clk_sel(input logic [1:0] val);
    verify_clk_sel = (val === 2'h0) || (val === 2'h1);
  endfunction

  // Small clock wait used by several directed checks.
  task automatic wait_n_negedges(ref logic clk, input int unsigned num_edges);
    repeat (num_edges) @(negedge clk);
  endtask : wait_n_negedges

  // Small clock wait used by several directed checks.
  task automatic wait_n_posedges(ref logic clk, input int unsigned num_edges);
    repeat (num_edges) @(posedge clk);
  endtask

  // Reset per-channel capture bookkeeping between tests.
  task automatic clear_capture_state(ref int left_sample_count, ref int right_sample_count,
                                     ref int left_toggle_count, ref int right_toggle_count,
                                     ref logic left_prev_bit, ref logic right_prev_bit,
                                     ref logic left_prev_valid, ref logic right_prev_valid);
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

  // Update the analog supply and give dependent logic a delta cycle to settle.
  task automatic set_vdd(ref real vdd_v, input real new_vdd_v);
    begin
      vdd_v = new_vdd_v;
      #1;
    end
  endtask : set_vdd

  // Count both phases because left and right mics drive on opposite edges.
  task automatic wait_n_mic_edges(ref logic mic_clk, input int unsigned num_edges);
    int unsigned edge_idx;
    begin
      for (edge_idx = 0; edge_idx < num_edges; edge_idx += 1) begin
        @(posedge mic_clk or negedge mic_clk);
      end
    end
  endtask : wait_n_mic_edges

  // One-shot timeout helper for asserted-signal waits.
  task automatic TimeoutTask(ref logic clk, ref int error_count, ref logic sig,
                             input int unsigned clks2wait, input string signal);
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

  // Wrapper around TimeoutTask that returns immediately when the condition is already true.
  task automatic WaitTask(ref logic clk, ref int error_count, ref logic sig,
                          input int unsigned clks2wait, input string signal);
    begin
      if (sig === 1'b1) begin
        return;
      end
      TimeoutTask(clk, error_count, sig, clks2wait, signal);
    end
  endtask : WaitTask

  // Model a gradual rail ramp with a fixed dwell at each voltage step.
  task automatic ramp_vdd(ref logic clk, ref real vdd_v, input real start_v, input real stop_v,
                          input real step_v, input int unsigned settle_cycles_per_step);
    real vdd_step;
    begin
      vdd_step = start_v;
      set_vdd(vdd_v, vdd_step);

      if (stop_v >= start_v) begin
        while (vdd_step < stop_v) begin
          wait_n_negedges(clk, settle_cycles_per_step);
          vdd_step = vdd_step + step_v;

          if (vdd_step > stop_v) begin
            vdd_step = stop_v;
          end

          set_vdd(vdd_v, vdd_step);
        end
      end else begin
        while (vdd_step > stop_v) begin
          wait_n_negedges(clk, settle_cycles_per_step);
          vdd_step = vdd_step - step_v;

          if (vdd_step < stop_v) begin
            vdd_step = stop_v;
          end

          set_vdd(vdd_v, vdd_step);
        end
      end
    end
  endtask : ramp_vdd

  // Compare edge-count snapshots instead of sampling the generated clock directly.
  task automatic expect_clock_quiet(ref logic clk, ref int mic_clk_edge_count, ref int error_count,
                                    input int unsigned observe_cycles, input string label);
    int start_edge_count;
    begin
      start_edge_count = mic_clk_edge_count;
      wait_n_negedges(clk, observe_cycles);

      if (mic_clk_edge_count !== start_edge_count) begin
        $error("ERROR: mic_clk_o toggled unexpectedly during %s!", label);
        error_count += 1;
      end
    end
  endtask : expect_clock_quiet

  // Compare edge-count snapshots instead of sampling the generated clock directly.
  task automatic expect_clock_activity(ref logic clk, ref int mic_clk_edge_count,
                                       ref int error_count, input int unsigned observe_cycles,
                                       input string label);
    int start_edge_count;
    begin
      start_edge_count = mic_clk_edge_count;
      wait_n_negedges(clk, observe_cycles);

      if (mic_clk_edge_count === start_edge_count) begin
        $error("ERROR: mic_clk_o did not toggle during %s!", label);
        error_count += 1;
      end
    end
  endtask : expect_clock_activity

  // When the mics are idle, the shared data bus should release on both phases.
  task automatic check_bus_high_z(ref logic mic_clk, ref logic data_bus_mon, ref int error_count,
                                  input int unsigned edge_pairs, input string label);
    int unsigned pair_idx;
    begin
      for (pair_idx = 0; pair_idx < edge_pairs; pair_idx += 1) begin
        @(posedge mic_clk);
        #(MIC_TIMING_DATA_SAMPLE_SKEW_NS);
        if (data_bus_mon !== 1'bz) begin
          $error("ERROR: Shared data bus was not high-Z on a right-channel edge during %s!", label);
          error_count += 1;
        end

        @(negedge mic_clk);
        #(MIC_TIMING_DATA_SAMPLE_SKEW_NS);
        if (data_bus_mon !== 1'bz) begin
          $error("ERROR: Shared data bus was not high-Z on a left-channel edge during %s!", label);
          error_count += 1;
        end
      end
    end
  endtask : check_bus_high_z

  // Common test banner for easier transcript scanning.
  task automatic announce_test(input int unsigned test_num, input string description);
    begin
      $display("------------------------------------------------------------");
      $display("TEST %0d STARTING @ %0t: %s", test_num, $time, description);
      $display("------------------------------------------------------------");
    end
  endtask : announce_test

  // Simple serial ADC responder: present the MSB at CS low, then shift on SCLK.
  task automatic simulate_adc_reading(ref logic adc_cs, ref logic adc_sclk, ref logic adc_data_out,
                                      input logic [11:0] voltage);
    int bit_idx;
    begin
      wait (adc_cs === 1'b0);
      adc_data_out = voltage[11];

      for (bit_idx = 10; bit_idx >= 0; bit_idx -= 1) begin
        @(negedge adc_sclk);
        adc_data_out = voltage[bit_idx];
      end

      wait (adc_cs === 1'b1);
      adc_data_out = 1'b0;
    end
  endtask : simulate_adc_reading
endpackage : Tb_Util_pkg
