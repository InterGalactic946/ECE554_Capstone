`timescale 1ns / 1ps
// ------------------------------------------------------------
// Module: Mic_Mode_Fsm
// Description: The Mic_Mode_Fsm controls the microphone's
//              operating mode by selecting the correct clock
//              and sequencing transitions. It enforces required
//              timing delays for power-up, wake-up, and mode
//              changes. It also prevents illegal transitions by
//              inserting intermediate modes when needed. Finally,
//              it indicates when the microphone output is stable
//              using data_valid.
// Author: Srivibhav Jonnalagadda
// Date: 03-21-2026
// ------------------------------------------------------------
module Mic_Mode_Fsm (
    input logic clk_i,
    input logic rst_i,

    // Minimum voltage threshold reached for mic to power on.
    input logic volt_on_i,

    // Requested mode:
    // If volt_on_i is high and mode_req_i[2] is low, the mic remains in SLEEP.
    // 00 = sleep
    // 01 = low-power
    // 10 = standard
    // 11 = ultrasonic
    input logic [2:0] mode_req_i,

    // PLL lock is used to decide when the selected clock is trustworthy.
    input logic pll_locked_i,

    // Control outputs to clock-control block.
    output logic clk_en_o,
    output logic [1:0] clk_sel_o,

    // Status outputs.
    output logic [1:0] curr_mode_o,
    output logic data_val_o
);

  // Parameters for DUT.
  parameter int unsigned SYS_CLK_HZ = 50_000_000;
  parameter bit FAST_SIM = 1'b0;
  parameter int unsigned FAST_SIM_DIV = 50_000;

  // ============================================================
  // Datasheet timing
  // Power-up = 50 ms
  // Wake-up  = 15 ms (from sleep to active)
  // Mode chg = 10 ms
  // Sleep in = 10 ms (from active to sleep)
  // ============================================================
  localparam int unsigned POWERUP_CYCLES_REAL = (SYS_CLK_HZ * 50) / 1000;
  localparam int unsigned WAKEUP_CYCLES_REAL = (SYS_CLK_HZ * 15) / 1000;
  localparam int unsigned MODECHANGE_CYCLES_REAL = (SYS_CLK_HZ * 10) / 1000;
  localparam int unsigned FALLASLEEP_CYCLES_REAL = (SYS_CLK_HZ * 10) / 1000;

  // Ensure we scale cycle count appropriately based on FAST_SIM_DIV.
  function automatic int unsigned scale_cycles(input int unsigned cycles);
    int unsigned scaled_cycles;
    begin
      if (!FAST_SIM) begin
        scale_cycles = cycles;
      end else begin
        // Round up during fast simulation so a shortened delay never becomes 0 cycles.
        scaled_cycles = (cycles + FAST_SIM_DIV - 1) / FAST_SIM_DIV;
        scale_cycles  = (scaled_cycles == 0) ? 1 : scaled_cycles;
      end
    end
  endfunction : scale_cycles

  localparam int unsigned POWERUP_CYCLES = scale_cycles(POWERUP_CYCLES_REAL);
  localparam int unsigned WAKEUP_CYCLES = scale_cycles(WAKEUP_CYCLES_REAL);
  localparam int unsigned MODECHANGE_CYCLES = scale_cycles(MODECHANGE_CYCLES_REAL);
  localparam int unsigned FALLASLEEP_CYCLES = scale_cycles(FALLASLEEP_CYCLES_REAL);

  // Maximum counter width is decided by power up cycle count.
  localparam int unsigned WAIT_COUNTER_W = $clog2(POWERUP_CYCLES + 1);

  ////////////////////////////////////////
  // Declare state types as enumerated //
  //////////////////////////////////////
  typedef enum logic [2:0] {
    IDLE,
    CLK_DIS,
    CLK_SEL,
    CLK_EN,
    WAIT,
    RUN
  } state_t;

  //////////////////////////////////
  // Declare modes as enumerated //
  ////////////////////////////////
  typedef enum logic [2:0] {
    OFF_SLEEP,
    OFF_LOW_PWR,
    OFF_STD,
    OFF_ULT,
    ON_SLEEP,
    ON_LOW_PWR,
    ON_STD,
    ON_ULT
  } mode_t;

  /////////////////////////////////////////////////
  // Declare any internal signals as type logic //
  ///////////////////////////////////////////////
  logic [WAIT_COUNTER_W-1:0] wait_cntr, wait_cycles;
  logic set_fsm_busy, fsm_busy, clr_fsm_busy;  // Indicates the FSM is busy processing a mode_req.
  logic settled_trans_comp, pending_trans_comp, tmr_empty;
  mode_t mode, nxt_mode;  // Holds the last fully settled mic mode.
  mode_t pending_mode, nxt_pending_mode;  // Holds the mode currently being applied to the clock.
  mode_t req_mode;  // Holds the combinational physical request decoded from voltage and mode_req_i.
  mode_t final_mode;  // Holds the final requested mode that the FSM is working toward.
  logic load_mode, clr_mode;
  logic load_pending_mode, clr_pending_mode;
  logic load, dec;  // Asserts load for 1 pulse to latch counter value, dec counts till cntr == 0.
  logic en, dis;  // Enables or disables the clock enable output.
  logic set_data_val, clr_data_val;
  state_t state, nxt_state;
  //////////////////////////////////////////////

  // Keep track of the last fully settled microphone mode.
  always_ff @(posedge clk_i) begin
    if (rst_i) begin
      mode <= OFF_SLEEP;
    end else if (clr_mode) begin
      mode <= OFF_SLEEP;
    end else if (load_mode) begin
      mode <= nxt_mode;
    end
  end

  // Keep track of the mode currently being driven onto the microphone clock path.
  always_ff @(posedge clk_i) begin
    if (rst_i) begin
      pending_mode <= OFF_SLEEP;
    end else if (clr_pending_mode) begin
      pending_mode <= OFF_SLEEP;
    end else if (load_pending_mode) begin
      pending_mode <= nxt_pending_mode;
    end
  end

  // We completed a transaction when the settled mode reached the final request.
  assign settled_trans_comp = (mode == final_mode);

  // We are on the final transition leg when the pending mode is the final request.
  assign pending_trans_comp = (pending_mode == final_mode);

  // Decode the requested physical mic mode. With power applied, a disabled
  // request still maps to SLEEP because the datasheet defines sleep as VDD high
  // with a low-frequency microphone clock.
  always_comb begin
    if (!volt_on_i) begin
      req_mode = OFF_SLEEP;
    end else if (!mode_req_i[2]) begin
      req_mode = ON_SLEEP;
    end else begin
      req_mode = mode_t'(mode_req_i);
    end
  end

  // Latch the mode requested as the final mode to ensure we reach the final
  // mode even during intermediate transitions, e.g., OFF -> ULT requires
  // OFF -> STD -> ULT only if FSM is done with a prior transaction.
  always_ff @(posedge clk_i) begin
    if (rst_i) begin
      final_mode <= OFF_SLEEP;
    end else if (!fsm_busy) begin
      final_mode <= req_mode;
    end
  end

  // Count down from the loaded value till it reaches 0 when dec is asserted, otherwise
  // latch the value meant to be counted.
  always_ff @(posedge clk_i) begin
    if (rst_i) begin
      wait_cntr <= '0;
    end else if (load) begin
      wait_cntr <= wait_cycles;
    end else if (dec & ~tmr_empty) begin
      wait_cntr <= wait_cntr - 1'b1;
    end
  end

  // Counter is empty when we have reached 0.
  assign tmr_empty = (wait_cntr == '0);

  // Output the clk_en based on dis/en.
  always_ff @(posedge clk_i) begin
    if (rst_i) begin
      clk_en_o <= 1'b0;
    end else if (dis) begin
      clk_en_o <= 1'b0;
    end else if (en) begin
      clk_en_o <= 1'b1;
    end
  end

  // Output the settled mode as status and the pending mode as the clock-select request.
  assign curr_mode_o = mode[1:0];
  assign clk_sel_o   = pending_mode[1:0];

  // ====================================================================
  // Functions to help manage state transitions and mode change requests
  // ====================================================================
  function automatic logic is_active_mode(input mode_t mic_mode);
    begin
      is_active_mode = (mic_mode == ON_LOW_PWR) || (mic_mode == ON_STD) || (mic_mode == ON_ULT);
    end
  endfunction : is_active_mode

  // Computes the next pending mode and wait cycles according to the current settled mode
  // and final mode requested.
  function automatic void comp_pending_mode_config(
      input mode_t mode, input mode_t final_mode, output mode_t pending_mode_cfg,
      output logic [WAIT_COUNTER_W-1:0] wait_cycles_cfg);
    begin
      pending_mode_cfg = mode;
      wait_cycles_cfg  = MODECHANGE_CYCLES;

      unique case (mode)
        ON_SLEEP: begin
          pending_mode_cfg = final_mode;
          wait_cycles_cfg  = WAKEUP_CYCLES;

          unique case (final_mode)
            ON_SLEEP: begin
              wait_cycles_cfg = '0;
            end

            ON_LOW_PWR: begin  // No action
            end

            ON_STD: begin  // No action
            end

            ON_ULT: begin  // Ensure ULT goes to STD first from SLEEP.
              pending_mode_cfg = ON_STD;
            end

            default: begin  // OFF state
              wait_cycles_cfg = MODECHANGE_CYCLES;
            end
          endcase
        end

        ON_LOW_PWR: begin
          pending_mode_cfg = final_mode;
          wait_cycles_cfg  = MODECHANGE_CYCLES;

          unique case (final_mode)
            ON_SLEEP: begin
              wait_cycles_cfg = FALLASLEEP_CYCLES;
            end

            ON_LOW_PWR: begin
              wait_cycles_cfg = '0;
            end

            ON_STD: begin  // No action
            end

            ON_ULT: begin  // No action
            end

            default: begin  // OFF state - no action
            end
          endcase
        end

        ON_STD: begin
          pending_mode_cfg = final_mode;
          wait_cycles_cfg  = MODECHANGE_CYCLES;

          unique case (final_mode)
            ON_SLEEP: begin
              wait_cycles_cfg = FALLASLEEP_CYCLES;
            end

            ON_LOW_PWR: begin  // No action
            end

            ON_STD: begin
              wait_cycles_cfg = '0;
            end

            ON_ULT: begin  // No action
            end

            default: begin  // OFF state - no action
            end
          endcase
        end

        ON_ULT: begin
          pending_mode_cfg = final_mode;
          wait_cycles_cfg  = MODECHANGE_CYCLES;

          unique case (final_mode)
            ON_SLEEP: begin
              wait_cycles_cfg = FALLASLEEP_CYCLES;
            end

            ON_LOW_PWR: begin  // No action
            end

            ON_STD: begin  // No action
            end

            ON_ULT: begin  // No action
              wait_cycles_cfg = '0;
            end

            default: begin  // OFF state - no action
            end
          endcase
        end

        default: begin  // OFF states
          pending_mode_cfg = final_mode;
          wait_cycles_cfg  = POWERUP_CYCLES;

          unique case (final_mode)
            ON_SLEEP: begin  // No action
            end

            ON_LOW_PWR: begin  // No action
            end

            ON_STD: begin  // No action
            end

            ON_ULT: begin  // Ensure ULT goes to STD first from OFF.
              pending_mode_cfg = ON_STD;
            end

            default: begin  // OFF - stay in OFF.
              wait_cycles_cfg = '0;
            end
          endcase
        end
      endcase
    end
  endfunction : comp_pending_mode_config

  /////////////////////////////////////
  // Implements State Machine Logic //
  ///////////////////////////////////
  always_ff @(posedge clk_i) begin
    if (rst_i) begin
      state <= IDLE;
    end else begin
      state <= nxt_state;
    end
  end

  // Ensures the busy signal is set accordingly.
  always_ff @(posedge clk_i) begin
    if (rst_i) begin
      fsm_busy <= 1'b0;
    end else if (clr_fsm_busy) begin
      fsm_busy <= 1'b0;
    end else if (set_fsm_busy) begin
      fsm_busy <= 1'b1;
    end
  end

  // Output data valid only when the newly settled mode is active.
  always_ff @(posedge clk_i) begin
    if (rst_i) begin
      data_val_o <= 1'b0;
    end else if (clr_data_val) begin
      data_val_o <= 1'b0;
    end else if (set_data_val) begin
      data_val_o <= is_active_mode(nxt_mode);
    end
  end

  //////////////////////////////////////////////////////////////////////////////////////////
  // Implements the combinational state transition and output logic of the state machine. //
  ////////////////////////////////////////////////////////////////////////////////////////
  always_comb begin
    nxt_state = state;
    nxt_mode = mode;
    nxt_pending_mode = pending_mode;
    wait_cycles = '0;
    clr_fsm_busy = 1'b0;
    set_fsm_busy = 1'b0;
    load_mode = 1'b0;
    clr_mode = 1'b0;
    load_pending_mode = 1'b0;
    clr_pending_mode = 1'b0;
    load = 1'b0;
    dec = 1'b0;
    en = 1'b0;
    dis = 1'b0;
    set_data_val = 1'b0;
    clr_data_val = 1'b0;

    case (state)
      CLK_DIS: begin
        dis = 1'b1;
        nxt_state = CLK_SEL;
      end

      CLK_SEL: begin
        // Enable the clock only if required to otherwise don't.
        nxt_state = (pending_mode[2]) ? CLK_EN : WAIT;
      end

      CLK_EN: begin
        en = 1'b1;
        nxt_state = WAIT;
      end

      WAIT: begin
        if (volt_on_i) begin  // Ensure brownout did not occur.
          // OFF-mode transitions do not require a valid PLL lock because the
          // clock stays disabled on that transition leg.
          if (~pending_mode[2] | pll_locked_i) begin
            dec = 1'b1;

            // Only go to the RUN state if we reached the final mode after waiting,
            // else wait again to finish an intermediate transition.
            if (tmr_empty & pending_trans_comp) begin
              load_mode = 1'b1;
              nxt_mode = pending_mode;
              clr_fsm_busy = 1'b1;
              set_data_val = 1'b1;
              nxt_state = RUN;
            end else if (tmr_empty) begin
              // First settle into the completed pending mode.
              load_mode = 1'b1;
              nxt_mode  = pending_mode;

              // Then compute the next pending mode based on the newly settled mode.
              comp_pending_mode_config(pending_mode, final_mode, nxt_pending_mode, wait_cycles);
              load_pending_mode = 1'b1;

              // Load the next counter to wait for.
              load = 1'b1;

              // Disable the old clock, enable the new clock.
              nxt_state = CLK_DIS;
            end
          end else begin
            // Ensure we start over the counter using the current settled mode if we lost lock.
            comp_pending_mode_config(mode, final_mode, nxt_pending_mode, wait_cycles);
            load_pending_mode = 1'b1;

            // Load the next counter to wait for.
            load = 1'b1;

            // Disable the old clock, enable the new clock.
            nxt_state = CLK_DIS;
          end
        end else begin
          // Brownout: drive the outputs back to a safe OFF state.
          dis = 1'b1;
          clr_data_val = 1'b1;
          clr_fsm_busy = 1'b1;
          clr_mode = 1'b1;
          clr_pending_mode = 1'b1;
          nxt_state = IDLE;
        end
      end

      RUN: begin
        if (volt_on_i) begin
          if (pll_locked_i) begin
            if (!settled_trans_comp) begin
              // Clear the data_valid signal.
              clr_data_val = 1'b1;

              // Set the busy signal.
              set_fsm_busy = 1'b1;

              // Compute the pending mode to begin driving while we wait to settle.
              comp_pending_mode_config(mode, final_mode, nxt_pending_mode, wait_cycles);
              load_pending_mode = 1'b1;

              // Load the counter value computed.
              load = 1'b1;

              // Disable the old clock, enable the new clock.
              nxt_state = CLK_DIS;
            end
          end else begin
            // Clear the data_valid signal.
            clr_data_val = 1'b1;

            // Re-drive the settled mode and wait for the clock path to become trustworthy again.
            comp_pending_mode_config(mode, final_mode, nxt_pending_mode, wait_cycles);
            load_pending_mode = 1'b1;

            // Set the busy signal.
            set_fsm_busy = 1'b1;

            // Load the counter value computed.
            load = 1'b1;

            // Disable the old clock, enable the new clock.
            nxt_state = CLK_DIS;
          end
        end else begin
          // Brownout: drive the outputs back to a safe OFF state.
          dis = 1'b1;
          clr_data_val = 1'b1;
          clr_fsm_busy = 1'b1;
          clr_mode = 1'b1;
          clr_pending_mode = 1'b1;
          nxt_state = IDLE;
        end
      end

      default: begin  // IDLE
        // Start a transaction whenever the decoded physical request differs
        // from the current settled mic mode.
        if (!settled_trans_comp) begin
          // FSM is now busy.
          set_fsm_busy = 1'b1;

          // Get the first pending mode config.
          comp_pending_mode_config(mode, final_mode, nxt_pending_mode, wait_cycles);
          load_pending_mode = 1'b1;

          // Load the counter value computed.
          load = 1'b1;

          nxt_state = CLK_DIS;
        end
      end
    endcase
  end
endmodule
