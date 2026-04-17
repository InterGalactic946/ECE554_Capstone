`timescale 1ns / 1ps
// ------------------------------------------------------------
// Package: Mic_Time_pkg
// Description: The Mic_Time_pkg centralizes the microphone
//              timing constants and helper functions used by
//              the audio front end. It keeps datasheet timing
//              and FAST_SIM scaling consistent across RTL and
//              testbench files.
// Author: Srivibhav Jonnalagadda
// Date: 04-02-2026
// ------------------------------------------------------------
package Mic_Time_pkg;

  // ============================================================
  // Datasheet timing
  // Power-up = 50 ms
  // Wake-up  = 15 ms (from sleep to active)
  // Mode chg = 10 ms
  // Sleep in = 10 ms (from active to sleep)
  // ============================================================
  localparam int unsigned MIC_POWERUP_MS = 50;
  localparam int unsigned MIC_WAKEUP_MS = 15;
  localparam int unsigned MIC_MODECHANGE_MS = 10;
  localparam int unsigned MIC_FALLASLEEP_MS = 10;
  localparam int unsigned MIC_SETTLE_GUARD_CYCLES = 256;

  localparam realtime MIC_POWERUP_TIME_NS = 50_000_000.0;
  localparam realtime MIC_WAKEUP_TIME_NS = 15_000_000.0;
  localparam realtime MIC_MODECHANGE_TIME_NS = 10_000_000.0;
  localparam realtime MIC_FALLASLEEP_TIME_NS = 10_000_000.0;

  // Scale cycle counts using the same ceil-divide behavior everywhere so
  // FAST_SIM shortens delays without ever collapsing a non-zero wait to 0.
  function automatic int unsigned mic_scale_cycles(input int unsigned cycles, input bit fast_sim,
                                                   input int unsigned fast_sim_div);
    int unsigned scaled_cycles;
    begin
      if (!fast_sim || (fast_sim_div == 0)) begin
        mic_scale_cycles = cycles;
      end else begin
        scaled_cycles = (cycles + fast_sim_div - 1) / fast_sim_div;
        mic_scale_cycles = (scaled_cycles == 0) ? 1 : scaled_cycles;
      end
    end
  endfunction : mic_scale_cycles

  // Convert a datasheet delay in milliseconds to the number of clk cycles
  // required at SYS_CLK_HZ, then apply FAST_SIM scaling if requested.
  // Add a small guard band so the FSM never under-waits relative to the
  // datasheet-derived minimum settle requirement.
  function automatic int unsigned mic_cycles_from_ms(
      input int unsigned sys_clk_hz, input int unsigned delay_ms, input bit fast_sim,
      input int unsigned fast_sim_div);
    longint unsigned raw_cycles;
    int unsigned raw_cycles_int;
    begin
      raw_cycles = (longint'(sys_clk_hz) * delay_ms) / 1000;
      raw_cycles_int = raw_cycles;
      mic_cycles_from_ms = mic_scale_cycles(raw_cycles_int, fast_sim, fast_sim_div);

      if (mic_cycles_from_ms != 0) begin
        mic_cycles_from_ms = mic_cycles_from_ms + MIC_SETTLE_GUARD_CYCLES;
      end
    end
  endfunction : mic_cycles_from_ms

endpackage : Mic_Time_pkg
