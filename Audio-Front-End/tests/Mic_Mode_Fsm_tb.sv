`timescale 1ns / 1ps
// ------------------------------------------------------------
// Testbench: Mic_Mode_Fsm_tb
// Description: Verifies Mic_Mode_Fsm behavior ensuring all
//              edge cases pass.
// Author: Srivibhav Jonnalagadda
// Date: 03-23-2026
// ------------------------------------------------------------
module Mic_Mode_Fsm_tb ();

  /////////////////////////////
  // Stimulus of type logic //
  ///////////////////////////
  logic clk;
  logic rst;
  logic volt_on;
  logic [2:0] mode_req;
  logic pll_locked;
  logic clk_en;
  logic [1:0] clk_sel;
  logic [1:0] curr_mode;
  logic data_val;
  int error_count;

  // Test parameters.
  localparam int unsigned SYS_CLK_HZ = 50_000_000;
  localparam bit FAST_SIM = 1'b1;
  localparam int unsigned FAST_SIM_DIV = 50_000;

  // Scales cycle count for different system clocks.
  function automatic int unsigned scale_cycles(input int unsigned cycles);
    int unsigned scaled_cycles;
    begin
      if (!FAST_SIM) begin
        scale_cycles = cycles;
      end else begin
        scaled_cycles = (cycles + FAST_SIM_DIV - 1) / FAST_SIM_DIV;
        scale_cycles  = (scaled_cycles == 0) ? 1 : scaled_cycles;
      end
    end
  endfunction

  // Datasheet parameters.
  localparam int unsigned POWERUP_CYCLES_REAL = (SYS_CLK_HZ * 50) / 1000;
  localparam int unsigned WAKEUP_CYCLES_REAL = (SYS_CLK_HZ * 15) / 1000;
  localparam int unsigned MODECHANGE_CYCLES_REAL = (SYS_CLK_HZ * 10) / 1000;
  localparam int unsigned FALLASLEEP_CYCLES_REAL = (SYS_CLK_HZ * 10) / 1000;

  localparam int unsigned POWERUP_CYCLES = scale_cycles(POWERUP_CYCLES_REAL);
  localparam int unsigned WAKEUP_CYCLES = scale_cycles(WAKEUP_CYCLES_REAL);
  localparam int unsigned MODECHANGE_CYCLES = scale_cycles(MODECHANGE_CYCLES_REAL);
  localparam int unsigned FALLASLEEP_CYCLES = scale_cycles(FALLASLEEP_CYCLES_REAL);
  localparam int unsigned FSM_MARGIN_CYCLES = 8;

  //////////////////////
  // Instantiate DUT //
  ////////////////////
  Mic_Mode_Fsm #(
      .SYS_CLK_HZ(SYS_CLK_HZ),
      .FAST_SIM(FAST_SIM),
      .FAST_SIM_DIV(FAST_SIM_DIV)
  ) iDUT (
      .clk_i(clk),
      .rst_i(rst),
      .volt_on_i(volt_on),
      .mode_req_i(mode_req),
      .pll_locked_i(pll_locked),
      .clk_rdy_i(pll_locked),

      .clk_en_o (clk_en),
      .clk_sel_o(clk_sel),

      .curr_mode_o(curr_mode),
      .data_val_o (data_val)
  );

  task automatic wait_n_negedges(input int unsigned num_edges);
    repeat (num_edges) @(negedge clk);
  endtask

  initial begin
    clk = 1'b0;
    rst = 1'b1;
    error_count = 0;
    pll_locked = 1'b0;
    volt_on = 1'b0;
    mode_req = 3'h0;

    // Wait for the first clock cycle to assert reset.
    @(posedge clk);

    // Assert reset.
    @(negedge clk) rst = 1'b1;

    // Deassert reset and start testing.
    @(negedge clk) rst = 1'b0;

    // TEST 1: Check outputs are at safe defaults upon reset.
    @(negedge clk) begin
      if (clk_en !== 1'b0) begin
        $error("ERROR: clk_en_o is not low upon reset!");
        error_count += 1;
      end

      if (clk_sel !== 2'h0) begin
        $error("ERROR: clk_sel_o is not 2'b00 upon reset!");
        error_count += 1;
      end

      if (curr_mode !== 2'h0) begin
        $error("ERROR: curr_mode_o is not 2'b00 upon reset!");
        error_count += 1;
      end

      if (data_val !== 1'b0) begin
        $error("ERROR: data_val_o is not low upon reset!");
        error_count += 1;
      end
    end

    // TEST 2: Assert volt_on with a disabled request. With power present, the
    // mic should still power into SLEEP mode.
    @(negedge clk) begin
      pll_locked = 1'b1;
      volt_on = 1'b1;
      mode_req = 3'h3;
    end

    wait_n_negedges(POWERUP_CYCLES + FSM_MARGIN_CYCLES);

    @(negedge clk) begin
      if (clk_en !== 1'b1) begin
        $error("ERROR: clk_en_o is not high when a disabled request maps to SLEEP!");
        error_count += 1;
      end

      if (clk_sel !== 2'h0) begin
        $error("ERROR: clk_sel_o is not 2'b00 when a disabled request maps to SLEEP!");
        error_count += 1;
      end

      if (curr_mode !== 2'h0) begin
        $error("ERROR: curr_mode_o is not 2'b00 when a disabled request maps to SLEEP!");
        error_count += 1;
      end

      if (data_val !== 1'b0) begin
        $error("ERROR: data_val_o is not low when a disabled request maps to SLEEP!");
        error_count += 1;
      end
    end

    // TEST 3: Assert mode_req as sleep, and verify that the correct clock is generated.
    @(negedge clk) mode_req = 3'h4;

    wait_n_negedges(POWERUP_CYCLES + FSM_MARGIN_CYCLES);

    @(negedge clk) begin
      if (clk_sel !== 2'h0) begin
        $error("ERROR: clk_sel_o is not 2'b00 when mic is enabled in SLEEP mode!");
        error_count += 1;
      end

      if (curr_mode !== 2'h0) begin
        $error("ERROR: curr_mode_o is not 2'b00 when mic is enabled in SLEEP mode!");
        error_count += 1;
      end

      if (clk_en !== 1'b1) begin
        $error("ERROR: clk_en_o is not high when mic is enabled in SLEEP mode!");
        error_count += 1;
      end

      if (data_val !== 1'b0) begin
        $error("ERROR: data_val_o is not low when mic is enabled in SLEEP mode!");
        error_count += 1;
      end
    end

    // TEST 4: Transition from SLEEP to LOW-POWER mode.
    @(negedge clk) mode_req = 3'h5;

    wait_n_negedges((WAKEUP_CYCLES / 2) + 2);

    @(negedge clk) begin
      if (clk_sel !== 2'h1) begin
        $error("ERROR: clk_sel_o did not switch to LOW-POWER during wake-up!");
        error_count += 1;
      end

      if (curr_mode !== 2'h0) begin
        $error("ERROR: curr_mode_o did not remain at the settled SLEEP mode during wake-up!");
        error_count += 1;
      end

      if (data_val !== 1'b0) begin
        $error("ERROR: data_val_o stayed high during the SLEEP to LOW-POWER transition!");
        error_count += 1;
      end
    end

    wait_n_negedges(WAKEUP_CYCLES + FSM_MARGIN_CYCLES);

    @(negedge clk) begin
      if (clk_sel !== 2'h1) begin
        $error("ERROR: clk_sel_o is not 2'b01 after entering LOW-POWER mode!");
        error_count += 1;
      end

      if (curr_mode !== 2'h1) begin
        $error("ERROR: curr_mode_o is not 2'b01 after entering LOW-POWER mode!");
        error_count += 1;
      end

      if (clk_en !== 1'b1) begin
        $error("ERROR: clk_en_o is not high after entering LOW-POWER mode!");
        error_count += 1;
      end

      if (data_val !== 1'b1) begin
        $error("ERROR: data_val_o is not high after entering LOW-POWER mode!");
        error_count += 1;
      end
    end

    // TEST 5: Transition from LOW-POWER to STANDARD mode.
    @(negedge clk) mode_req = 3'h6;

    wait_n_negedges((MODECHANGE_CYCLES / 2) + 2);

    @(negedge clk) begin
      if (clk_sel !== 2'h2) begin
        $error("ERROR: clk_sel_o did not switch to STANDARD during the mode change!");
        error_count += 1;
      end

      if (curr_mode !== 2'h1) begin
        $error(
            "ERROR: curr_mode_o did not remain at the settled LOW-POWER mode during the mode change!");
        error_count += 1;
      end

      if (data_val !== 1'b0) begin
        $error("ERROR: data_val_o stayed high during the LOW-POWER to STANDARD transition!");
        error_count += 1;
      end
    end

    wait_n_negedges(MODECHANGE_CYCLES + FSM_MARGIN_CYCLES);

    @(negedge clk) begin
      if (clk_sel !== 2'h2) begin
        $error("ERROR: clk_sel_o is not 2'b10 after entering STANDARD mode!");
        error_count += 1;
      end

      if (curr_mode !== 2'h2) begin
        $error("ERROR: curr_mode_o is not 2'b10 after entering STANDARD mode!");
        error_count += 1;
      end

      if (clk_en !== 1'b1) begin
        $error("ERROR: clk_en_o is not high after entering STANDARD mode!");
        error_count += 1;
      end

      if (data_val !== 1'b1) begin
        $error("ERROR: data_val_o is not high after entering STANDARD mode!");
        error_count += 1;
      end
    end

    // TEST 6: Transition from STANDARD to ULTRASONIC mode.
    @(negedge clk) mode_req = 3'h7;

    wait_n_negedges((MODECHANGE_CYCLES / 2) + 2);

    @(negedge clk) begin
      if (clk_sel !== 2'h3) begin
        $error("ERROR: clk_sel_o did not switch to ULTRASONIC during the mode change!");
        error_count += 1;
      end

      if (curr_mode !== 2'h2) begin
        $error(
            "ERROR: curr_mode_o did not remain at the settled STANDARD mode during the mode change!");
        error_count += 1;
      end

      if (data_val !== 1'b0) begin
        $error("ERROR: data_val_o stayed high during the STANDARD to ULTRASONIC transition!");
        error_count += 1;
      end
    end

    wait_n_negedges(MODECHANGE_CYCLES + FSM_MARGIN_CYCLES);

    @(negedge clk) begin
      if (clk_sel !== 2'h3) begin
        $error("ERROR: clk_sel_o is not 2'b11 after entering ULTRASONIC mode!");
        error_count += 1;
      end

      if (curr_mode !== 2'h3) begin
        $error("ERROR: curr_mode_o is not 2'b11 after entering ULTRASONIC mode!");
        error_count += 1;
      end

      if (clk_en !== 1'b1) begin
        $error("ERROR: clk_en_o is not high after entering ULTRASONIC mode!");
        error_count += 1;
      end

      if (data_val !== 1'b1) begin
        $error("ERROR: data_val_o is not high after entering ULTRASONIC mode!");
        error_count += 1;
      end
    end

    // TEST 7: Transition from ULTRASONIC to SLEEP mode.
    @(negedge clk) mode_req = 3'h4;

    wait_n_negedges((FALLASLEEP_CYCLES / 2) + 2);

    @(negedge clk) begin
      if (clk_sel !== 2'h0) begin
        $error("ERROR: clk_sel_o did not switch to SLEEP during the fall-asleep transition!");
        error_count += 1;
      end

      if (curr_mode !== 2'h3) begin
        $error(
            "ERROR: curr_mode_o did not remain at the settled ULTRASONIC mode during the fall-asleep transition!");
        error_count += 1;
      end

      if (data_val !== 1'b0) begin
        $error("ERROR: data_val_o stayed high during the ULTRASONIC to SLEEP transition!");
        error_count += 1;
      end
    end

    wait_n_negedges(FALLASLEEP_CYCLES + FSM_MARGIN_CYCLES);

    @(negedge clk) begin
      if (clk_sel !== 2'h0) begin
        $error("ERROR: clk_sel_o is not 2'b00 after entering SLEEP mode!");
        error_count += 1;
      end

      if (curr_mode !== 2'h0) begin
        $error("ERROR: curr_mode_o is not 2'b00 after entering SLEEP mode!");
        error_count += 1;
      end

      if (clk_en !== 1'b1) begin
        $error("ERROR: clk_en_o is not high after entering SLEEP mode!");
        error_count += 1;
      end

      if (data_val !== 1'b0) begin
        $error("ERROR: data_val_o is not low after entering SLEEP mode!");
        error_count += 1;
      end
    end

    // TEST 8: Verify SLEEP to ULTRASONIC goes through STANDARD first.
    @(negedge clk) mode_req = 3'h7;

    wait_n_negedges((WAKEUP_CYCLES / 2) + 2);

    @(negedge clk) begin
      if (clk_sel !== 2'h2) begin
        $error(
            "ERROR: clk_sel_o did not pass through STANDARD during the SLEEP to ULTRASONIC transition!");
        error_count += 1;
      end

      if (curr_mode !== 2'h0) begin
        $error(
            "ERROR: curr_mode_o did not remain at the settled SLEEP mode during the first leg of the SLEEP to ULTRASONIC transition!");
        error_count += 1;
      end

      if (data_val !== 1'b0) begin
        $error("ERROR: data_val_o went high before ULTRASONIC mode was fully reached!");
        error_count += 1;
      end
    end

    wait_n_negedges(WAKEUP_CYCLES + MODECHANGE_CYCLES + FSM_MARGIN_CYCLES);

    @(negedge clk) begin
      if (clk_sel !== 2'h3) begin
        $error("ERROR: clk_sel_o is not 2'b11 after the SLEEP to ULTRASONIC transition!");
        error_count += 1;
      end

      if (curr_mode !== 2'h3) begin
        $error("ERROR: curr_mode_o is not 2'b11 after the SLEEP to ULTRASONIC transition!");
        error_count += 1;
      end

      if (clk_en !== 1'b1) begin
        $error("ERROR: clk_en_o is not high after the SLEEP to ULTRASONIC transition!");
        error_count += 1;
      end

      if (data_val !== 1'b1) begin
        $error("ERROR: data_val_o is not high after the SLEEP to ULTRASONIC transition!");
        error_count += 1;
      end
    end

    // TEST 9: A disabled request with power present should return the mic to SLEEP.
    @(negedge clk) mode_req = 3'h0;

    wait_n_negedges(FALLASLEEP_CYCLES + FSM_MARGIN_CYCLES);

    @(negedge clk) begin
      if (clk_sel !== 2'h0) begin
        $error("ERROR: clk_sel_o is not 2'b00 after applying a disabled request!");
        error_count += 1;
      end

      if (curr_mode !== 2'h0) begin
        $error("ERROR: curr_mode_o is not 2'b00 after applying a disabled request!");
        error_count += 1;
      end

      if (clk_en !== 1'b1) begin
        $error("ERROR: clk_en_o is not high after a disabled request returns the mic to SLEEP!");
        error_count += 1;
      end

      if (data_val !== 1'b0) begin
        $error("ERROR: data_val_o is not low after a disabled request returns the mic to SLEEP!");
        error_count += 1;
      end
    end

    // TEST 10: Remove power to enter OFF, then verify OFF to ULTRASONIC goes
    // through STANDARD first after power returns.
    @(negedge clk) volt_on = 1'b0;

    wait_n_negedges(FSM_MARGIN_CYCLES);

    @(negedge clk) begin
      if (clk_sel !== 2'h0) begin
        $error("ERROR: clk_sel_o is not 2'b00 after removing power for an OFF transition!");
        error_count += 1;
      end

      if (curr_mode !== 2'h0) begin
        $error("ERROR: curr_mode_o is not 2'b00 after removing power for an OFF transition!");
        error_count += 1;
      end

      if (clk_en !== 1'b0) begin
        $error("ERROR: clk_en_o is not low after removing power for an OFF transition!");
        error_count += 1;
      end

      if (data_val !== 1'b0) begin
        $error("ERROR: data_val_o is not low after removing power for an OFF transition!");
        error_count += 1;
      end
    end

    @(negedge clk) begin
      volt_on  = 1'b1;
      mode_req = 3'h7;
    end

    wait_n_negedges((POWERUP_CYCLES / 2) + 2);

    @(negedge clk) begin
      if (clk_sel !== 2'h2) begin
        $error(
            "ERROR: clk_sel_o did not pass through STANDARD during the OFF to ULTRASONIC transition!");
        error_count += 1;
      end

      if (curr_mode !== 2'h0) begin
        $error(
            "ERROR: curr_mode_o did not remain at the settled OFF mode during the first leg of the OFF to ULTRASONIC transition!");
        error_count += 1;
      end

      if (data_val !== 1'b0) begin
        $error("ERROR: data_val_o went high before ULTRASONIC mode was fully reached from OFF!");
        error_count += 1;
      end
    end

    wait_n_negedges(POWERUP_CYCLES + MODECHANGE_CYCLES + FSM_MARGIN_CYCLES);

    @(negedge clk) begin
      if (clk_sel !== 2'h3) begin
        $error("ERROR: clk_sel_o is not 2'b11 after the OFF to ULTRASONIC transition!");
        error_count += 1;
      end

      if (curr_mode !== 2'h3) begin
        $error("ERROR: curr_mode_o is not 2'b11 after the OFF to ULTRASONIC transition!");
        error_count += 1;
      end

      if (clk_en !== 1'b1) begin
        $error("ERROR: clk_en_o is not high after the OFF to ULTRASONIC transition!");
        error_count += 1;
      end

      if (data_val !== 1'b1) begin
        $error("ERROR: data_val_o is not high after the OFF to ULTRASONIC transition!");
        error_count += 1;
      end
    end

    // TEST 11: Brownout during a transition should return the mic to a safe OFF state.
    @(negedge clk) mode_req = 3'h5;

    wait_n_negedges((MODECHANGE_CYCLES / 2) + 2);

    @(negedge clk) volt_on = 1'b0;

    wait_n_negedges(FSM_MARGIN_CYCLES);

    @(negedge clk) begin
      if (clk_sel !== 2'h0) begin
        $error("ERROR: clk_sel_o is not 2'b00 after a brownout!");
        error_count += 1;
      end

      if (curr_mode !== 2'h0) begin
        $error("ERROR: curr_mode_o is not 2'b00 after a brownout!");
        error_count += 1;
      end

      if (clk_en !== 1'b0) begin
        $error("ERROR: clk_en_o is not low after a brownout!");
        error_count += 1;
      end

      if (data_val !== 1'b0) begin
        $error("ERROR: data_val_o is not low after a brownout!");
        error_count += 1;
      end
    end

    // TEST 12: After a brownout, the FSM should recover cleanly once power returns.
    @(negedge clk) begin
      volt_on  = 1'b1;
      mode_req = 3'h5;
    end

    wait_n_negedges(POWERUP_CYCLES + FSM_MARGIN_CYCLES);

    @(negedge clk) begin
      if (clk_sel !== 2'h1) begin
        $error("ERROR: clk_sel_o is not 2'b01 after recovering from a brownout!");
        error_count += 1;
      end

      if (curr_mode !== 2'h1) begin
        $error("ERROR: curr_mode_o is not 2'b01 after recovering from a brownout!");
        error_count += 1;
      end

      if (clk_en !== 1'b1) begin
        $error("ERROR: clk_en_o is not high after recovering from a brownout!");
        error_count += 1;
      end

      if (data_val !== 1'b1) begin
        $error("ERROR: data_val_o is not high after recovering from a brownout!");
        error_count += 1;
      end
    end

    // TEST 13: Loss of PLL lock mid-transition should restart the wait and recover cleanly.
    @(negedge clk) mode_req = 3'h6;

    wait_n_negedges((MODECHANGE_CYCLES / 2) + 2);

    @(negedge clk) pll_locked = 1'b0;

    wait_n_negedges(3);

    @(negedge clk) begin
      if (data_val !== 1'b0) begin
        $error("ERROR: data_val_o is not low while PLL lock is lost mid-transition!");
        error_count += 1;
      end
    end

    @(negedge clk) pll_locked = 1'b1;

    wait_n_negedges(MODECHANGE_CYCLES + FSM_MARGIN_CYCLES);

    @(negedge clk) begin
      if (clk_sel !== 2'h2) begin
        $error("ERROR: clk_sel_o is not 2'b10 after recovering from PLL lock loss!");
        error_count += 1;
      end

      if (curr_mode !== 2'h2) begin
        $error("ERROR: curr_mode_o is not 2'b10 after recovering from PLL lock loss!");
        error_count += 1;
      end

      if (clk_en !== 1'b1) begin
        $error("ERROR: clk_en_o is not high after recovering from PLL lock loss!");
        error_count += 1;
      end

      if (data_val !== 1'b1) begin
        $error("ERROR: data_val_o is not high after recovering from PLL lock loss!");
        error_count += 1;
      end
    end

    // TEST 14: A new request during a busy transition should wait until the current transition completes.
    @(negedge clk) mode_req = 3'h7;

    wait_n_negedges((MODECHANGE_CYCLES / 2) + 2);

    @(negedge clk) mode_req = 3'h5;

    wait_n_negedges((MODECHANGE_CYCLES / 2) + 3);

    @(negedge clk) begin
      if (clk_sel !== 2'h3) begin
        $error(
            "ERROR: clk_sel_o did not finish the in-flight transition before honoring a new request!");
        error_count += 1;
      end

      if (curr_mode !== 2'h3) begin
        $error(
            "ERROR: curr_mode_o did not finish the in-flight transition before honoring a new request!");
        error_count += 1;
      end

      if (data_val !== 1'b1) begin
        $error("ERROR: data_val_o is not high after the in-flight transition completed!");
        error_count += 1;
      end
    end

    wait_n_negedges(MODECHANGE_CYCLES + FSM_MARGIN_CYCLES);

    @(negedge clk) begin
      if (clk_sel !== 2'h1) begin
        $error("ERROR: clk_sel_o is not 2'b01 after the deferred request is serviced!");
        error_count += 1;
      end

      if (curr_mode !== 2'h1) begin
        $error("ERROR: curr_mode_o is not 2'b01 after the deferred request is serviced!");
        error_count += 1;
      end

      if (clk_en !== 1'b1) begin
        $error("ERROR: clk_en_o is not high after the deferred request is serviced!");
        error_count += 1;
      end

      if (data_val !== 1'b1) begin
        $error("ERROR: data_val_o is not high after the deferred request is serviced!");
        error_count += 1;
      end
    end

    // Print status message at the end.
    if (error_count == 0) begin
      $display("YAHOO!! All tests passed.");
    end else begin
      $error("ERROR: %0d test(s) failed.", error_count);
    end

    $stop();
  end

  ///////////////////////////////////////////
  // Clock generation for synchronous DUT //
  /////////////////////////////////////////
  always #5 clk = ~clk;

endmodule
