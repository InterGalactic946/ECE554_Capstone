`timescale 1ns / 1ps
// ------------------------------------------------------------
// Module: SPH0641LU4H_1_model
// Description: The SPH0641LU4H_1_model models the digital
//              behavior of the Knowles SPH0641LU4H-1
//              microphone for simulation. It measures the
//              applied clock, classifies the requested mode,
//              enforces datasheet settling delays, and drives
//              a behavioral PDM stream on the selected edge.
//              VDD is modeled as a digital power-good signal
//              here, not as a true analog supply.
// Author: Srivibhav Jonnalagadda
// Date: 03-24-2026
// ------------------------------------------------------------
import Mic_Time_pkg::*;
import Tb_Util_pkg::*;
module SPH0641LU4H_1_model #(
    parameter bit FAST_SIM = 1'b0,
    parameter int unsigned FAST_SIM_DIV = 1,
    parameter int unsigned TONE_FREQ_HZ = 1_000,
    parameter int unsigned TONE_AMPLITUDE = 16'd32767,
    parameter realtime MIC_DATA_ASSERT_TIME_NS = Tb_Util_pkg::MIC_TIMING_WORST_DATA_ASSERT_NS,
    parameter realtime MIC_DATA_HIGH_Z_TIME_NS = Tb_Util_pkg::MIC_TIMING_WORST_DATA_HIGH_Z_NS
) (
    input logic vdd_i,    // Digital abstraction of microphone supply being present.
    input logic clock_i,  // Applied microphone clock.
    input logic select_i, // Chooses which clock edge DATA is driven on.
    input logic [31:0] tone_freq_hz_i,  // Runtime behavioral tone frequency.
    output tri data_o     // Microphone DATA pin. Driven only on the selected edge.
);

  ///////////////////////////////////////
  // Declare state type as enumerated //
  /////////////////////////////////////
  typedef enum logic [2:0] {
    IDLE,
    MEASURE,
    WAIT,
    RUN,
    FAULT
  } state_t;

  //////////////////////////////////////
  // Declare mode type as enumerated //
  ////////////////////////////////////
  typedef enum logic [2:0] {
    MODE_OFF,
    MODE_SLEEP,
    MODE_LOW_PWR,
    MODE_STD,
    MODE_ULT,
    MODE_INVALID
  } mic_mode_t;

  ///////////////////////////////////////////////////////////
  // Declare internal state and control signals as logic  //
  /////////////////////////////////////////////////////////
  state_t state, nxt_state;  // Holds the current mic-model state machine state.
  mic_mode_t mode, nxt_mode;  // Holds the current settled microphone mode.
  mic_mode_t pending_mode, nxt_pending_mode;  // Holds the mode being waited on in WAIT state.
  mic_mode_t requested_mode;  // Holds the filtered mode decoded from measured clock periods.
  mic_mode_t mode_sample;  // Holds the latest raw mode candidate being qualified.
  logic request_valid;  // Indicates the decoded mode has been stable long enough to use.
  logic illegal_transition;  // Indicates a direct OFF/SLEEP -> ULT request.
  logic model_active;  // Indicates DATA may be actively driven.
  logic warning_issued;  // Prevents repeated illegal-transition warnings.
  logic first_edge_seen;  // Indicates the first clock posedge after power-up was seen.
  logic period_valid;  // Indicates a valid clock period measurement exists.
  logic data_drive_en;  // Enables the DATA output driver.
  logic data_drive_val;  // Value driven onto DATA when enabled.
  logic data_o_drv;  // Delayed registered DATA pin driver.
  logic set_warning, clr_warning;  // Set/clear signals for illegal-transition warning latch.
  logic load, dec;  // Load/decrement controls for settle counter.
  logic tmr_empty;  // Indicates the settle counter is empty.
  logic [15:0] pdm_accum;  // First-order pulse-density accumulator.
  logic [15:0] tone_phase;  // Phase accumulator for the internal triangle-wave test tone.
  int unsigned wait_cntr, wait_cycles;  // Settle counter and value to load into it.
  int unsigned mode_sample_count;  // Counts consecutive periods with the same raw mode.
  realtime last_posedge_ns;  // Stores the timestamp of the previous clock posedge.
  realtime clock_period_ns;  // Stores the most recently measured clock period.
  event clock_stopped_sleep_ev;  // Triggered when a powered microphone has no clock for long enough to be SLEEP.
  //////////////////////////////////////////////////////////

  localparam realtime MIC_SLEEP_CLOCK_MAX_PERIOD_NS = 4_000.0;
  localparam realtime MIC_STOPPED_CLOCK_DETECT_NS = MIC_SLEEP_CLOCK_MAX_PERIOD_NS + 1.0;
  localparam realtime MIC_FREQ_CLASS_TOL_HZ = 500.0;  // Allows small PLL/period quantization near band edges.
  localparam int unsigned MIC_MODE_STABLE_PERIODS = 4;  // Qualify mode requests across multiple clock periods.

  // Drive DATA from a delayed registered pin driver.
  assign data_o = data_o_drv;

  // ====================================================================
  // Functions to help manage state transitions and mode change requests
  // ====================================================================
  // Checks if the mic is in an active operating mode.
  function automatic bit is_active_mode(input mic_mode_t mic_mode);
    begin
      is_active_mode = (mic_mode === MODE_LOW_PWR) || (mic_mode === MODE_STD) || (mic_mode === MODE_ULT);
    end
  endfunction : is_active_mode

  // Computes the phase increment required to keep the behavioral test tone at
  // the requested frequency regardless of the active microphone clock rate.
  function automatic logic [15:0] tone_phase_step(input realtime period_ns,
                                                  input logic [31:0] tone_freq_hz);
    realtime raw_step;
    int unsigned active_tone_freq_hz;
    begin
      active_tone_freq_hz = (tone_freq_hz == 0) ? TONE_FREQ_HZ : tone_freq_hz;

      if (period_ns <= 0.0) begin
        tone_phase_step = 16'h0001;
      end else begin
        raw_step = (active_tone_freq_hz * 65536.0 * period_ns) / 1.0e9;

        if (raw_step < 1.0) begin
          tone_phase_step = 16'h0001;
        end else if (raw_step > 65535.0) begin
          tone_phase_step = 16'hFFFF;
        end else begin
          tone_phase_step = int'(raw_step);
        end
      end
    end
  endfunction : tone_phase_step

  // Converts the internal phase ramp into an unsigned sine-wave sample.
  // The first-order PDM accumulator expects an unsigned density target, so
  // the sine is centered at mid-scale with a configurable test amplitude.
  function automatic logic [15:0] sine_sample(input logic [15:0] phase);
    real phase_radians;
    real sine_value;
    int  sample_value;
    begin
      phase_radians = (6.283185307179586 * real'(phase)) / 65536.0;
      sine_value = $sin(phase_radians);
      sample_value = int'(32768.0 + (sine_value * real'(TONE_AMPLITUDE)) + 0.5);

      if (sample_value < 0) begin
        sine_sample = 16'h0000;
      end else if (sample_value > 65535) begin
        sine_sample = 16'hFFFF;
      end else begin
        sine_sample = sample_value[15:0];
      end
    end
  endfunction : sine_sample

  // Scale a wall-clock delay for FAST_SIM the same way we shorten datasheet waits elsewhere.
  function automatic realtime scale_wait_ns(input realtime wait_ns);
    realtime scaled_wait_ns;
    begin
      if ((wait_ns <= 0.0) || !FAST_SIM || (FAST_SIM_DIV == 0)) begin
        scale_wait_ns = wait_ns;
      end else begin
        scaled_wait_ns = wait_ns / FAST_SIM_DIV;
        scale_wait_ns  = (scaled_wait_ns < 1.0) ? 1.0 : scaled_wait_ns;
      end
    end
  endfunction : scale_wait_ns

  // When the applied clock stops, the model must still be able to settle into
  // SLEEP after the appropriate datasheet delay. The stopped-clock detector
  // itself already waits one SLEEP-clock period, so subtract that portion from
  // the remaining settle time.
  function automatic realtime stopped_clock_sleep_wait_ns(input mic_mode_t from_mode);
    realtime total_wait_ns;
    begin
      unique case (from_mode)
        MODE_OFF:     total_wait_ns = scale_wait_ns(MIC_POWERUP_TIME_NS);
        MODE_SLEEP:   total_wait_ns = 0.0;
        MODE_LOW_PWR: total_wait_ns = scale_wait_ns(MIC_FALLASLEEP_TIME_NS);
        MODE_STD:     total_wait_ns = scale_wait_ns(MIC_FALLASLEEP_TIME_NS);
        MODE_ULT:     total_wait_ns = scale_wait_ns(MIC_FALLASLEEP_TIME_NS);
        MODE_INVALID: total_wait_ns = 0.0;
        default:      total_wait_ns = 0.0;
      endcase

      if (total_wait_ns <= MIC_STOPPED_CLOCK_DETECT_NS) begin
        stopped_clock_sleep_wait_ns = 0.0;
      end else begin
        stopped_clock_sleep_wait_ns = total_wait_ns - MIC_STOPPED_CLOCK_DETECT_NS;
      end
    end
  endfunction : stopped_clock_sleep_wait_ns

  // Classifies the mic's operating mode based on the frequency of the clock input.
  function automatic mic_mode_t classify_mode(input logic vdd_on, input realtime period_ns);
    real freq_hz;
    begin
      if (!vdd_on) begin
        classify_mode = MODE_OFF;  // No power means the mic is OFF.
      end else if (period_ns <= 0.0) begin
        classify_mode = MODE_SLEEP;  // A stopped clock is treated as SLEEP when power is present.
      end else begin
        freq_hz = 1.0e9 / period_ns;

        if (freq_hz <= (250_000.0 + MIC_FREQ_CLASS_TOL_HZ)) begin
          classify_mode = MODE_SLEEP;
        end else if ((freq_hz >= (351_000.0 - MIC_FREQ_CLASS_TOL_HZ)) &&
                     (freq_hz <= (815_000.0 + MIC_FREQ_CLASS_TOL_HZ))) begin
          classify_mode = MODE_LOW_PWR;
        end else if ((freq_hz >= (1_024_000.0 - MIC_FREQ_CLASS_TOL_HZ)) &&
                     (freq_hz <= (2_475_000.0 + MIC_FREQ_CLASS_TOL_HZ))) begin
          classify_mode = MODE_STD;
        end else if ((freq_hz >= (3_072_000.0 - MIC_FREQ_CLASS_TOL_HZ)) &&
                     (freq_hz <= (4_800_000.0 + MIC_FREQ_CLASS_TOL_HZ))) begin
          classify_mode = MODE_ULT;
        end else begin
          classify_mode = MODE_INVALID;  // Clock is outside all legal datasheet ranges.
        end
      end
    end
  endfunction : classify_mode

  // Detect illegal transitions for safety (OFF/SLEEP -> ULTRA).
  function automatic bit is_illegal_transition(input mic_mode_t from_mode,
                                               input mic_mode_t to_mode);
    begin
      is_illegal_transition =
          ((from_mode === MODE_OFF) || (from_mode === MODE_SLEEP)) &&
          (to_mode === MODE_ULT);
    end
  endfunction : is_illegal_transition

  // Compute the wait time needed for the transition.
  function automatic int unsigned transition_cycles(
      input mic_mode_t from_mode, input mic_mode_t to_mode, input realtime period_ns);
    realtime wait_ns;
    int unsigned raw_cycles;
    begin
      wait_ns = 0.0;

      // In the datasheet-accurate model, MODE_OFF represents VDD = 0.
      unique case (from_mode)
        MODE_OFF: begin
          unique case (to_mode)
            MODE_OFF:     wait_ns = 0.0;
            MODE_SLEEP:   wait_ns = MIC_POWERUP_TIME_NS;
            MODE_LOW_PWR: wait_ns = MIC_POWERUP_TIME_NS;
            MODE_STD:     wait_ns = MIC_POWERUP_TIME_NS;
            MODE_ULT:     wait_ns = MIC_POWERUP_TIME_NS;
            default:      wait_ns = 0.0;
          endcase
        end

        MODE_SLEEP: begin
          unique case (to_mode)
            MODE_OFF:     wait_ns = 0.0;
            MODE_SLEEP:   wait_ns = 0.0;
            MODE_LOW_PWR: wait_ns = MIC_WAKEUP_TIME_NS;
            MODE_STD:     wait_ns = MIC_WAKEUP_TIME_NS;
            MODE_ULT:     wait_ns = MIC_WAKEUP_TIME_NS;
            default:      wait_ns = 0.0;
          endcase
        end

        MODE_LOW_PWR, MODE_STD, MODE_ULT: begin
          unique case (to_mode)
            MODE_OFF:     wait_ns = 0.0;  // Powered-down mode is entered by removing VDD.
            MODE_SLEEP:   wait_ns = MIC_FALLASLEEP_TIME_NS;
            MODE_LOW_PWR: wait_ns = (from_mode === MODE_LOW_PWR) ? 0.0 : MIC_MODECHANGE_TIME_NS;
            MODE_STD:     wait_ns = (from_mode === MODE_STD) ? 0.0 : MIC_MODECHANGE_TIME_NS;
            MODE_ULT:     wait_ns = (from_mode === MODE_ULT) ? 0.0 : MIC_MODECHANGE_TIME_NS;
            default:      wait_ns = 0.0;
          endcase
        end

        MODE_INVALID: begin
          unique case (to_mode)
            MODE_OFF:     wait_ns = 0.0;
            MODE_SLEEP:   wait_ns = 0.0;
            MODE_LOW_PWR: wait_ns = MIC_POWERUP_TIME_NS;
            MODE_STD:     wait_ns = MIC_POWERUP_TIME_NS;
            MODE_ULT:     wait_ns = MIC_POWERUP_TIME_NS;
            default:      wait_ns = 0.0;
          endcase
        end

        default: wait_ns = 0.0;
      endcase

      if ((wait_ns == 0.0) || (period_ns <= 0.0)) begin
        transition_cycles = 0;
      end else begin
        raw_cycles = int'($ceil(wait_ns / period_ns));
        transition_cycles = mic_scale_cycles(raw_cycles, FAST_SIM, FAST_SIM_DIV);
      end
    end
  endfunction : transition_cycles

  // Check if we are on the active clock edge appropriate to the select signal.
  function automatic bit is_active_edge(input logic select, input logic clock_level);
    begin
      is_active_edge = (select && clock_level) || (!select && !clock_level);
    end
  endfunction : is_active_edge

  // Detect illegal direct entry into ultrasonic from OFF or SLEEP.
  assign illegal_transition = is_illegal_transition(mode, requested_mode);

  // DATA may only be driven once the mic is settled in RUN state and the settled
  // mode is one of the active operating modes.
  assign model_active = (state === RUN) && is_active_mode(mode);

  /////////////////////////////////////
  // Implements State Machine Logic //
  ///////////////////////////////////
  // Holds the current state or next state, accordingly.
  always @(posedge clock_i or clock_stopped_sleep_ev or negedge vdd_i) begin
    if (!vdd_i) state <= IDLE;
    else if (clock_stopped_sleep_ev.triggered) state <= RUN;
    else state <= nxt_state;
  end

  // Holds the current settled microphone mode.
  always @(posedge clock_i or clock_stopped_sleep_ev or negedge vdd_i) begin
    if (!vdd_i) mode <= MODE_OFF;
    else if (clock_stopped_sleep_ev.triggered) mode <= MODE_SLEEP;
    else mode <= nxt_mode;
  end

  // Holds the destination mode that the model is waiting to settle into.
  always @(posedge clock_i or clock_stopped_sleep_ev or negedge vdd_i) begin
    if (!vdd_i) pending_mode <= MODE_OFF;
    else if (clock_stopped_sleep_ev.triggered) pending_mode <= MODE_SLEEP;
    else pending_mode <= nxt_pending_mode;
  end

  // Holds the settle counter while the mic is transitioning between modes.
  always @(posedge clock_i or clock_stopped_sleep_ev or negedge vdd_i) begin
    if (!vdd_i) wait_cntr <= 0;
    else if (clock_stopped_sleep_ev.triggered) wait_cntr <= 0;
    else if (load) wait_cntr <= wait_cycles;
    else if (dec && !tmr_empty) wait_cntr <= wait_cntr - 1'b1;
  end

  // Counter is empty when we have reached 0.
  assign tmr_empty = (wait_cntr === 0);

  // Holds whether an illegal transition warning has already been reported.
  always @(posedge clock_i or clock_stopped_sleep_ev or negedge vdd_i) begin
    if (!vdd_i) begin
      warning_issued <= 1'b0;
    end else if (clock_stopped_sleep_ev.triggered) begin
      warning_issued <= 1'b0;
    end else if (clr_warning) begin
      warning_issued <= 1'b0;
    end else if (set_warning) begin
      if (!warning_issued) begin
        $warning(
            "SPH0641LU4H_1_model: illegal direct OFF/SLEEP -> ULT request at time %0t; forcing DATA high-Z until clock returns to a legal mode.",
            $time);
      end
      warning_issued <= 1'b1;
    end
  end

  // Measures the applied microphone clock period. The first edge after power-up
  // only initializes the timestamp. The second and later edges update the measured
  // period, then qualify the decoded mode across consecutive periods so a single
  // clock-mux bubble does not look like a real mode request.
  always @(posedge clock_i or clock_stopped_sleep_ev or negedge vdd_i) begin
    realtime measured_period_ns;
    mic_mode_t measured_mode;
    int unsigned next_sample_count;

    if (!vdd_i) begin
      first_edge_seen <= 1'b0;
      period_valid <= 1'b0;
      request_valid <= 1'b0;
      requested_mode <= MODE_OFF;
      mode_sample <= MODE_OFF;
      mode_sample_count <= 0;
      last_posedge_ns <= 0.0;
      clock_period_ns <= 0.0;
    end else if (clock_stopped_sleep_ev.triggered) begin
      first_edge_seen <= 1'b0;
      period_valid <= 1'b0;
      request_valid <= 1'b0;
      requested_mode <= MODE_SLEEP;
      mode_sample <= MODE_SLEEP;
      mode_sample_count <= 0;
      last_posedge_ns <= 0.0;
      clock_period_ns <= 0.0;
    end else begin
      if (first_edge_seen) begin
        measured_period_ns = $realtime - last_posedge_ns;
        measured_mode = classify_mode(vdd_i, measured_period_ns);

        clock_period_ns <= measured_period_ns;
        period_valid <= 1'b1;

        if (measured_mode === mode_sample) begin
          next_sample_count = (mode_sample_count < MIC_MODE_STABLE_PERIODS) ?
                              (mode_sample_count + 1) : mode_sample_count;
          mode_sample_count <= next_sample_count;

          if (next_sample_count >= MIC_MODE_STABLE_PERIODS) begin
            requested_mode <= measured_mode;
            request_valid  <= 1'b1;
          end else begin
            request_valid <= 1'b0;
          end
        end else begin
          mode_sample <= measured_mode;
          mode_sample_count <= 1;
          request_valid <= 1'b0;
        end
      end else begin
        first_edge_seen <= 1'b1;
        request_valid   <= 1'b0;
      end

      last_posedge_ns <= $realtime;
    end
  end

  // Detect when a powered microphone no longer sees any clock edges. This lets
  // the behavioral model settle into SLEEP and release DATA even after the
  // external clock is stopped completely.
  always begin : stopped_clock_watchdog_proc
    realtime settle_wait_ns;

    if (!vdd_i) begin
      @(posedge vdd_i);
    end

    fork : stopped_clock_window
      begin : stopped_clock_edge_proc
        // If we see any clock edge, the clock is not stopped, so we can just restart the watchdog.
        @(posedge clock_i or negedge clock_i or negedge vdd_i);
      end
      begin : stopped_clock_timeout_proc
        // Wait for the stopped-clock timeout duration. If that elapses without seeing a clock edge, we may need to settle into SLEEP.
        #(MIC_STOPPED_CLOCK_DETECT_NS);

        // If we are still powered and not already in SLEEP with DATA released, start the SLEEP settle process.
        if (vdd_i && ((state !== RUN) || (mode !== MODE_SLEEP) || data_drive_en)) begin
          // Determine how long we need to wait for the mic to settle into SLEEP based on the last settled mode, and subtract the time we've already waited in the watchdog.
          settle_wait_ns = stopped_clock_sleep_wait_ns(mode);

          // If the remaining settle time is already elapsed by the time we detect the stopped clock, settle into SLEEP immediately. Otherwise, wait for the remaining settle time while still monitoring for any clock edges that would restart the process.
          if (settle_wait_ns <= 0.0) begin
            ->>clock_stopped_sleep_ev;
          end else begin
            fork : stopped_clock_settle_window
              begin : stopped_clock_settle_proc
                // Wait for the remaining settle time required to enter SLEEP after a stopped clock, then trigger the SLEEP event if we are still powered. Any clock edge or power loss during this window restarts the watchdog instead of settling.
                #(settle_wait_ns);

                // If we are still powered, we have successfully settled into SLEEP after the stopped clock, so trigger the event to update the state machine and release DATA.
                if (vdd_i) begin
                  ->>clock_stopped_sleep_ev;
                end
              end
              begin : stopped_clock_restart_proc
                @(posedge clock_i or negedge clock_i or negedge vdd_i);
              end
            join_any
            disable stopped_clock_settle_window;
          end
        end
      end
    join_any
    disable stopped_clock_window;
  end : stopped_clock_watchdog_proc

  //////////////////////////////////////////////////////////////////////////////////////////
  // Implements the combinational state transition and output logic of the state machine. //
  ////////////////////////////////////////////////////////////////////////////////////////
  always_comb begin
    nxt_state = state;  // By default, assume we remain in the current state.
    nxt_mode = mode;  // By default, keep the current settled mode.
    nxt_pending_mode = pending_mode;  // By default, keep the current pending mode.
    wait_cycles = 0;  // By default, no transition wait is loaded.
    load = 1'b0;  // By default, do not load the settle counter.
    dec = 1'b0;  // By default, do not decrement the settle counter.
    set_warning = 1'b0;  // By default, do not set the illegal-transition warning latch.
    clr_warning = 1'b0;  // By default, do not clear the illegal-transition warning latch.

    unique case (state)
      IDLE: begin
        nxt_mode = MODE_OFF;  // No power means the mic is OFF.
        nxt_pending_mode = MODE_OFF;  // No pending destination while the mic is OFF.
        clr_warning = 1'b1;  // Clear stale illegal-transition warnings after power loss.

        // Wait for VDD to be present, then start measuring the applied clock.
        if (vdd_i) begin
          nxt_state = MEASURE;
        end
      end

      MEASURE: begin
        // Wait until a full input clock period has been measured.
        if (request_valid) begin
          if (illegal_transition) begin
            nxt_mode = MODE_INVALID;  // Illegal direct ULT entry forces a faulted mic mode.
            nxt_pending_mode = MODE_INVALID;  // No legal pending destination while faulted.
            set_warning = 1'b1;  // Report the illegal transition once.
            nxt_state = FAULT;
          end else begin
            nxt_pending_mode = requested_mode;
            wait_cycles = transition_cycles(mode, requested_mode, clock_period_ns);

            if (wait_cycles === 0) begin
              nxt_mode  = requested_mode;  // Immediate transitions become settled right away.
              nxt_state = RUN;
            end else begin
              load = 1'b1;  // Load the settle counter for the measured transition.
              nxt_state = WAIT;
            end
          end
        end
      end

      WAIT: begin
        // If the applied clock changed while we were waiting, restart the timing based on
        // the original settled mode and the newly requested destination mode.
        if (request_valid) begin
          if (illegal_transition) begin
            nxt_mode = MODE_INVALID;  // Illegal direct ULT entry forces a faulted mic mode.
            nxt_pending_mode = MODE_INVALID;  // No legal pending destination while faulted.
            set_warning = 1'b1;  // Report the illegal transition once.
            nxt_state = FAULT;
          end else if (requested_mode !== pending_mode) begin
            nxt_pending_mode = requested_mode;
            wait_cycles = transition_cycles(mode, requested_mode, clock_period_ns);

            if (wait_cycles === 0) begin
              nxt_mode  = requested_mode;  // Immediate transitions do not need WAIT state.
              nxt_state = RUN;
            end else begin
              load = 1'b1;  // Restart the settle timer for the new request.
            end
          end else if (wait_cntr === 1) begin
            dec = 1'b1;  // Consume the final wait cycle.
            nxt_mode = pending_mode;  // The pending mode becomes the new settled mode now.
            nxt_state = RUN;
          end else if (!tmr_empty) begin
            dec = 1'b1;  // Continue counting down until the transition settles.
          end else begin
            nxt_mode  = pending_mode;  // Zero-cycle corner case: settle immediately.
            nxt_state = RUN;
          end
        end
      end

      RUN: begin
        // Monitor the measured clock continuously. Any mode request change restarts the
        // transition timing from the current settled mode.
        if (request_valid && (requested_mode !== mode)) begin
          if (illegal_transition) begin
            nxt_mode = MODE_INVALID;  // Illegal direct ULT entry forces a faulted mic mode.
            nxt_pending_mode = MODE_INVALID;  // No legal pending destination while faulted.
            set_warning = 1'b1;  // Report the illegal transition once.
            nxt_state = FAULT;
          end else begin
            nxt_pending_mode = requested_mode;
            wait_cycles = transition_cycles(mode, requested_mode, clock_period_ns);

            if (wait_cycles === 0) begin
              nxt_mode = requested_mode;  // Immediate transitions update the settled mode directly.
            end else begin
              load = 1'b1;  // Load the settle timer for the requested mode change.
              nxt_state = WAIT;
            end
          end
        end
      end

      FAULT: begin
        // Stay faulted until the applied clock returns to a legal non-ultrasonic mode.
        // This keeps DATA high-Z after illegal direct OFF/SLEEP -> ULT entry.
        if (request_valid && (requested_mode !== MODE_INVALID) && (requested_mode !== MODE_ULT)) begin
          clr_warning = 1'b1;  // Allow a future illegal request to be reported again.
          nxt_pending_mode = requested_mode;
          wait_cycles = transition_cycles(MODE_INVALID, requested_mode, clock_period_ns);

          if (wait_cycles === 0) begin
            nxt_mode  = requested_mode;  // Recover immediately if no wait is required.
            nxt_state = RUN;
          end else begin
            load = 1'b1;  // Recover through the normal settle timer.
            nxt_state = WAIT;
          end
        end
      end

      default: begin
        nxt_state = IDLE;  // Return to IDLE if the state machine becomes corrupted.
        nxt_mode = MODE_OFF;  // Force the mic back to OFF on an invalid state.
        nxt_pending_mode = MODE_OFF;  // Clear the pending destination on an invalid state.
        wait_cycles = 0;  // Do not leave a stale wait count loaded.
        load = 1'b0;
        dec = 1'b0;
        set_warning = 1'b0;
        clr_warning = 1'b1;
      end
    endcase
  end

  ///////////////////////////////////////////////////////////////
  // Drive DATA on the SELECT-chosen edge when the model is    //
  // settled in an active mic mode. This is intentionally a    //
  // behavioral dual-edge model of the microphone interface.   //
  //                                                           //
  // PDM algorithm used here:                                  //
  // 1. Advance an internal phase accumulator at a fixed       //
  //    behavioral tone frequency.                             //
  // 2. Convert that phase into an unsigned sine-wave          //
  //    sample.                                                //
  // 3. Feed the sample into a first-order accumulator         //
  //    modulator.                                             //
  // 4. Drive the carry-out bit as the next 1-bit PDM output.  //
  //                                                           //
  // This is still a behavioral source, not an acoustic MEMS   //
  // model, but it is a true time-varying PDM stream.          //
  ///////////////////////////////////////////////////////////////
  always @(posedge clock_i or negedge clock_i or clock_stopped_sleep_ev or negedge vdd_i) begin : data_drive_proc
    logic [16:0] pdm_sum;
    logic [15:0] phase_next;
    logic [15:0] tone_sample_now;

    if (!vdd_i) begin
      data_drive_en  <= 1'b0;  // Release DATA when power is removed.
      data_drive_val <= 1'b0;  // Clear the last driven value.
      data_o_drv     <= 1'bz;  // Powered-off mic releases DATA.
      pdm_accum      <= 16'h0000;  // Reset the pulse-density accumulator.
      tone_phase     <= 16'h0000;  // Reset the internal tone phase.
    end else if (clock_stopped_sleep_ev.triggered) begin
      data_drive_en  <= 1'b0;  // Release DATA once a stopped clock has settled into SLEEP.
      data_drive_val <= 1'b0;
      data_o_drv     <= #(MIC_DATA_HIGH_Z_TIME_NS) 1'bz;
      pdm_accum      <= 16'h0000;
      tone_phase     <= 16'h0000;
    end else if (!model_active) begin
      data_drive_en <= 1'b0;  // Keep DATA high-Z in OFF, SLEEP, INVALID, WAIT, or FAULT.
      data_drive_val <= 1'b0;
      data_o_drv <= #(MIC_DATA_HIGH_Z_TIME_NS) 1'bz;
      pdm_accum <= 16'h0000;  // Restart the PDM stream when the mic becomes active again.
      tone_phase <= 16'h0000;  // Restart the internal tone phase when the mic becomes active again.
    end else if (is_active_edge(select_i, clock_i)) begin
      // Advance the internal test tone and emit a 1-bit PDM representation of it.
      phase_next      = tone_phase + tone_phase_step(clock_period_ns, tone_freq_hz_i);
      tone_sample_now = sine_sample(phase_next);
      pdm_sum         = {1'b0, pdm_accum} + {1'b0, tone_sample_now};
      pdm_accum      <= pdm_sum[15:0];
      tone_phase     <= phase_next;
      data_drive_val <= pdm_sum[16];
      data_drive_en  <= 1'b1;
      data_o_drv     <= #(MIC_DATA_ASSERT_TIME_NS) pdm_sum[16];
    end else begin
      data_drive_en <= 1'b0;  // Release DATA on the non-selected edge.
      data_o_drv    <= #(MIC_DATA_HIGH_Z_TIME_NS) 1'bz;
    end
  end : data_drive_proc
endmodule : SPH0641LU4H_1_model
