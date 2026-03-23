// ------------------------------------------------------------
// Module: Mic_Mode_Fsm
// Description: The Mic_Mode_Fsm controls the microphone’s
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

    // Requested mode: (mode_req_i[2] -> enable, else off)
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

  // System clock frequency of the FPGA in Hz.
  parameter int unsigned SYS_CLK_HZ = 50_000_000;

  // ============================================================
  // Datasheet timing
  // Power-up = 50 ms
  // Wake-up  = 15 ms (from sleep to active)
  // Mode chg = 10 ms
  // Sleep in = 10 ms (from active to sleep)
  // ============================================================
  localparam int unsigned POWERUP_CYCLES = (SYS_CLK_HZ * 50) / 1000;
  localparam int unsigned WAKEUP_CYCLES = (SYS_CLK_HZ * 15) / 1000;
  localparam int unsigned MODECHANGE_CYCLES = (SYS_CLK_HZ * 10) / 1000;
  localparam int unsigned FALLASLEEP_CYCLES = (SYS_CLK_HZ * 10) / 1000;

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
  logic trans_comp, tmr_empty;
  mode_t prev_mode, mode, nxt_mode, final_mode;
  logic load, dec;  // Asserts load for 1 pulse to latch counter val, dec asserted till cntr == 0.
  logic inc_cnt, clr_cnt;  // Switch counter signals to ensure smooth switching between clks.
  logic mic_en, en, dis;  // Enables or disables the clken.
  logic set_data_val, clr_data_val;
  state_t state, nxt_state;
  //////////////////////////////////////////////

  // Keep track of mode mic was in throughout runtime, intially we assume
  // mic is OFF upon reset.
  always_ff @(posedge clk_i) begin
    if (rst_i) begin
      mode <= OFF_SLEEP;
      prev_mode <= OFF_SLEEP;
    end else begin
      mode <= nxt_mode;
      prev_mode <= mode;
    end
  end

  // We completed a transaction when we reached the final mode.
  assign trans_comp = mode == final_mode;

  // Latch the mode requested as the final mode to ensure we reach the final
  // mode even during intermediate transitions, e.g., OFF -> ULT requires
  // OFF -> STD -> ULT only if FSM is done with a prior transaction.
  always_ff @(posedge clk_i) begin
    if (rst_i) final_mode <= OFF_SLEEP;
    else if (!fsm_busy) final_mode <= mode_t'(mode_req_i);
  end

  // Treat mic as enabled only if bit 2 is high.
  assign mic_en = final_mode[2];

  // Count down from the loaded value till it reaches 0 when dec is asserted, otherwise
  // latch the value meant to be counted.
  always_ff @(posedge clk_i) begin
    if (rst_i) wait_cntr <= '0;
    else if (load) wait_cntr <= wait_cycles;
    else if (dec & !tmr_empty) wait_cntr <= wait_cntr - 1'b1;
  end

  // Counter is empty when we have reached 0.
  assign tmr_empty = wait_cntr == '0;

  // Output the clk_en based on dis/en.
  always_ff @(posedge clk_i) begin
    if (rst_i) clk_en_o <= 1'b0;
    else if (dis) clk_en_o <= 1'b0;
    else if (en & mic_en) clk_en_o <= 1'b1;
  end

  // Output the clk_select (curr_mode) based on the current mode.
  assign curr_mode_o = mode[1:0];
  assign clk_sel_o   = curr_mode_o;

  // ====================================================================
  // Functions to help manage state transitions and mode change requests
  // ====================================================================
  function automatic logic is_active_mode(input mode_t mode);
    begin
      is_active_mode = (mode == ON_LOW_PWR) || (mode == ON_STD) || (mode == ON_ULT);
    end
  endfunction

  // Computes the next mode and wait cycles according to the current mode and final mode requested.
  function automatic void comp_nxt_mode_config(input mode_t mode, input mode_t final_mode,
                                               output mode_t nxt_mode,
                                               output logic [WAIT_COUNTER_W-1:0] wait_cycles);
    begin
      nxt_mode = mode;
      wait_cycles = MODECHANGE_CYCLES;

      unique case (mode)
        ON_SLEEP: begin
          nxt_mode = final_mode;
          wait_cycles = WAKEUP_CYCLES;

          unique case (final_mode)
            ON_SLEEP: begin
              wait_cycles = '0;
            end

            ON_LOW_PWR: begin  // No action
            end

            ON_STD: begin  // No action
            end

            ON_ULT: begin  // Ensure ULT goes to STD first from SLEEP.
              nxt_mode = ON_STD;
            end

            default: begin  // OFF state
              wait_cycles = MODECHANGE_CYCLES;
            end
          endcase
        end

        ON_LOW_PWR: begin
          nxt_mode = final_mode;
          wait_cycles = MODECHANGE_CYCLES;

          unique case (final_mode)
            ON_SLEEP: begin
              wait_cycles = FALLASLEEP_CYCLES;
            end

            ON_LOW_PWR: begin
              wait_cycles = '0;
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
          nxt_mode = final_mode;
          wait_cycles = MODECHANGE_CYCLES;

          unique case (final_mode)
            ON_SLEEP: begin
              wait_cycles = FALLASLEEP_CYCLES;
            end

            ON_LOW_PWR: begin  // No action
            end

            ON_STD: begin
              wait_cycles = '0;
            end

            ON_ULT: begin  // No action
            end

            default: begin  // OFF state - no action
            end
          endcase
        end

        ON_ULT: begin
          nxt_mode = final_mode;
          wait_cycles = MODECHANGE_CYCLES;

          unique case (final_mode)
            ON_SLEEP: begin
              wait_cycles = FALLASLEEP_CYCLES;
            end

            ON_LOW_PWR: begin  // No action
            end

            ON_STD: begin  // No action
            end

            ON_ULT: begin  // No action
              wait_cycles = '0;
            end

            default: begin  // OFF state - no action
            end
          endcase
        end

        default: begin  // OFF states
          nxt_mode = final_mode;
          wait_cycles = POWERUP_CYCLES;

          unique case (final_mode)
            ON_SLEEP: begin  // No action
            end

            ON_LOW_PWR: begin  // No action
            end

            ON_STD: begin  // No action
            end

            ON_ULT: begin  // Ensure ULT goes to STD first from OFF.
              nxt_mode = ON_STD;
            end

            default: begin  // OFF - stay in OFF.
              wait_cycles = '0;
            end
          endcase
        end
      endcase
    end
  endfunction

  /////////////////////////////////////
  // Implements State Machine Logic //
  ///////////////////////////////////
  always_ff @(posedge clk_i) begin
    if (rst_i) state <= IDLE;
    else state <= nxt_state;
  end

  // Ensures the busy signal is set accordingly.
  always_ff @(posedge clk_i) begin
    if (rst_i) fsm_busy <= 1'b0;
    else if (clr_fsm_busy) fsm_busy <= 1'b0;
    else if (set_fsm_busy) fsm_busy <= 1'b1;
  end

  // Output data valid when reached final mode requested.
  always_ff @(posedge clk_i) begin
    if (rst_i) data_val_o <= 1'b0;
    else if (clr_data_val) data_val_o <= 1'b0;
    else if (set_data_val) data_val_o <= is_active_mode(mode);
  end

  //////////////////////////////////////////////////////////////////////////////////////////
  // Implements the combinational state transition and output logic of the state machine.//
  ////////////////////////////////////////////////////////////////////////////////////////
  always_comb begin
    nxt_state = state;
    nxt_mode = mode;
    wait_cycles = '0;
    clr_fsm_busy = 1'b0;
    set_fsm_busy = 1'b0;
    load = 1'b0;
    dec = 1'b0;
    en = 1'b0;
    dis = 1'b0;
    set_data_val = 1'b0;
    clr_data_val = 1'b0;
    inc_cnt = 1'b0;
    clr_cnt = 1'b0;

    case (state)
      CLK_DIS: begin
        dis = 1'b1;
        nxt_state = CLK_SEL;
      end

      CLK_SEL: begin  // Passthrough state to ensure we select the correct clock to output.
        nxt_state = CLK_EN;
      end

      CLK_EN: begin
        en = 1'b1;
        nxt_state = WAIT;
      end

      WAIT: begin
        if (volt_on_i) begin  // Ensure brownout did not occur.
          if (pll_locked_i) begin  // Ensure clk is locked before counting.
            dec = 1'b1;

            // Only go to the RUN state if we reached the final mode after waiting,
            // else wait again to finish intermediate transition.
            if (tmr_empty & trans_comp) begin
              clr_fsm_busy = 1'b1;
              set_data_val = 1'b1;
              nxt_state = RUN;
            end else if (tmr_empty) begin
              // Get the nxt mode config.
              comp_nxt_mode_config(mode, final_mode, nxt_mode, wait_cycles);

              // load the next counter to wait for.
              load = 1'b1;

              // Disable the old clock, enable the new clock.
              nxt_state = CLK_DIS;
            end
          end else begin
            // Ensure we start over the counter if we lost lock based on the previous mode we were in.
            comp_nxt_mode_config(prev_mode, final_mode, nxt_mode, wait_cycles);

            // load the next counter to wait for.
            load = 1'b1;

            // Disable the old clock, enable the new clock.
            nxt_state = CLK_DIS;
          end
        end else begin
          // Go back to idle, resetting the mode back to OFF.
          nxt_mode  = OFF_SLEEP;
          nxt_state = IDLE;
        end
      end

      RUN: begin
        if (volt_on_i) begin
          if (pll_locked_i) begin
            if (!trans_comp) begin
              // Clear the data_valid signal.
              clr_data_val = 1'b1;

              // Set the busy signal.
              set_fsm_busy = 1'b1;

              // Go to the new requested mode.
              comp_nxt_mode_config(mode, final_mode, nxt_mode, wait_cycles);

              // load the next counter to wait for.
              load = 1'b1;

              // Disable the old clock, enable the new clock.
              nxt_state = CLK_DIS;
            end
          end else begin
            // Clear the data_valid signal.
            clr_data_val = 1'b1;

            // Ensure we start over the counter if we lost lock based on the previous mode we were in.
            comp_nxt_mode_config(prev_mode, final_mode, nxt_mode, wait_cycles);

            // Set the busy signal.
            set_fsm_busy = 1'b1;

            // load the next counter to wait for.
            load = 1'b1;

            // Disable the old clock, enable the new clock.
            nxt_state = CLK_DIS;
          end
        end else begin
          // Go back to idle, resetting the mode back to OFF.
          clr_data_val = 1'b1;
          nxt_mode = OFF_SLEEP;
          nxt_state = IDLE;
        end
      end

      default: begin  // IDLE
        // Wait till power is steady and mic is enabled.
        if (volt_on_i & mic_en) begin
          // FSM is now busy.
          set_fsm_busy = 1'b1;

          // Get the nxt mode config.
          comp_nxt_mode_config(mode, final_mode, nxt_mode, wait_cycles);

          // Load the counter value computed.
          load = 1'b1;

          nxt_state = CLK_DIS;
        end
      end
    endcase
  end
endmodule
