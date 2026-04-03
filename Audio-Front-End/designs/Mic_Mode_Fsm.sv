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
    // If volt_on_i is high and mode_req_i[2]/mode_req_i[1] is low, the mic remains in SLEEP.
    // 00 = sleep
    // 01 = sleep
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
  import Mic_Time_pkg::*;

  // Parameters for DUT.
  parameter int unsigned SYS_CLK_HZ = 50_000_000;
  parameter bit FAST_SIM = 1'b0;
  parameter int unsigned FAST_SIM_DIV = 50_000;

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
    OFF   = 3'b000,
    SLEEP = 3'b100,
    STD   = 3'b110,
    ULT   = 3'b111
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
      mode <= OFF;
    end else if (clr_mode) begin
      mode <= OFF;
    end else if (load_mode) begin
      mode <= nxt_mode;
    end
  end

  // Keep track of the mode currently being driven onto the microphone clock path.
  always_ff @(posedge clk_i) begin
    if (rst_i) begin
      pending_mode <= OFF;
    end else if (clr_pending_mode) begin
      pending_mode <= OFF;
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
      req_mode = OFF;
    end else if (~mode_req_i[2] | ~mode_req_i[1]) begin
      req_mode = SLEEP;
    end else begin
      req_mode = mode_t'(mode_req_i);
    end
  end

  // Latch the mode requested as the final mode to ensure we reach the final
  // mode even during intermediate transitions, e.g., OFF -> ULT requires
  // OFF -> STD -> ULT only if FSM is done with a prior transaction.
  always_ff @(posedge clk_i) begin
    if (rst_i) begin
      final_mode <= OFF;
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
      is_active_mode = (mic_mode == STD) || (mic_mode == ULT);
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
        SLEEP: begin
          pending_mode_cfg = final_mode;
          wait_cycles_cfg  = WAKEUP_CYCLES;

          unique case (final_mode)
            SLEEP: begin
              wait_cycles_cfg = '0;
            end

            STD: begin  // No action
            end

            ULT: begin  // Ensure ULT goes to STD first from SLEEP.
              pending_mode_cfg = STD;
            end

            default: begin  // OFF
              wait_cycles_cfg = MODECHANGE_CYCLES;
            end
          endcase
        end

        STD: begin
          pending_mode_cfg = final_mode;
          wait_cycles_cfg  = MODECHANGE_CYCLES;

          unique case (final_mode)
            SLEEP: begin
              wait_cycles_cfg = FALLASLEEP_CYCLES;
            end

            STD: begin
              wait_cycles_cfg = '0;
            end

            ULT: begin  // No action
            end

            default: begin  // OFF - no action
            end
          endcase
        end

        ULT: begin
          pending_mode_cfg = final_mode;
          wait_cycles_cfg  = MODECHANGE_CYCLES;

          unique case (final_mode)
            SLEEP: begin
              wait_cycles_cfg = FALLASLEEP_CYCLES;
            end

            STD: begin  // No action
            end

            ULT: begin  // No action
              wait_cycles_cfg = '0;
            end

            default: begin  // OFF - no action
            end
          endcase
        end

        default: begin  // OFF
          pending_mode_cfg = final_mode;
          wait_cycles_cfg  = POWERUP_CYCLES;

          unique case (final_mode)
            SLEEP: begin  // No action
            end

            STD: begin  // No action
            end

            ULT: begin  // Ensure ULT goes to STD first from OFF.
              pending_mode_cfg = STD;
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
        nxt_state = (pending_mode == SLEEP) ? WAIT : CLK_EN;
      end

      CLK_EN: begin
        en = 1'b1;
        nxt_state = WAIT;
      end

      WAIT: begin
        if (volt_on_i) begin  // Ensure brownout did not occur.
          if (pll_locked_i) begin
            // The PLL is locked and the selected clock path is now latched through
            // to the microphone, so it is safe to start the settle countdown.
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
            // If the PLL loses lock while waiting on an active transition, restart
            // the transition from the current settled mode once the clocking
            // infrastructure becomes trustworthy again.
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
        // from the current settled mic mode and power is present.
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
