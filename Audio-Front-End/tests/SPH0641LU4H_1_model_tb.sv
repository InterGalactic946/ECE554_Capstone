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
  logic select;
  tri   data;

  // Test parameters.
  localparam int unsigned FAST_SIM_DIV = 1_000;

  SPH0641LU4H_1_model #(
      .FAST_SIM(1'b1),
      .FAST_SIM_DIV(FAST_SIM_DIV)
  ) iDUT (
      .vdd_i(vdd),
      .clock_i(clk),
      .select_i(select),
      .data_o(data)
  );

  initial begin
    error_count = 0;
    vdd = 1'b0;
    clk = 1'b0;
    select = 1'b1;
    half_period_ns = 4_000;

    // TEST 1: Power-down keeps DATA high-Z.
    wait_n_posedges(clk, 4);

    if (data !== 1'bz) begin
      $error("ERROR: data_o is not high-Z when the microphone is powered down!");
      error_count += 1;
    end

    // TEST 2: Power-up with a sleep clock keeps DATA high-Z.
    vdd = 1'b1;
    wait_n_posedges(clk, 16);

    if (data !== 1'bz) begin
      $error("ERROR: data_o is not high-Z in SLEEP mode!");
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
    #1;
    if (data === 1'bz) begin
      $error(
          "ERROR: data_o did not recover on the selected rising edge after returning to STANDARD mode!");
      error_count += 1;
    end

    @(negedge clk);
    #1;
    if (data !== 1'bz) begin
      $error(
          "ERROR: data_o should return to high-Z on the non-selected falling edge in STANDARD mode!");
      error_count += 1;
    end

    // TEST 5: Move to LOW-POWER mode and ensure DATA drives on the selected edge.
    half_period_ns = 1_000;
    wait_n_posedges(clk, 24);

    @(posedge clk);
    #1;
    if (data === 1'bz) begin
      $error("ERROR: data_o is still high-Z on the selected rising edge in LOW-POWER mode!");
      error_count += 1;
    end

    @(negedge clk);
    #1;
    if (data !== 1'bz) begin
      $error("ERROR: data_o should return to high-Z on the non-selected falling edge!");
      error_count += 1;
    end

    // TEST 6: Flip SELECT and ensure DATA moves to the falling edge.
    select = 1'b0;
    wait_n_posedges(clk, 4);

    @(posedge clk);
    #1;
    if (data !== 1'bz) begin
      $error("ERROR: data_o should stay high-Z on the rising edge after SELECT goes low!");
      error_count += 1;
    end

    @(negedge clk);
    #1;
    if (data === 1'bz) begin
      $error("ERROR: data_o is still high-Z on the selected falling edge after SELECT goes low!");
      error_count += 1;
    end

    // TEST 7: Move to ULTRASONIC mode from an active legal mode and ensure DATA remains active.
    half_period_ns = 156;
    wait_n_posedges(clk, 40);

    @(negedge clk);
    #1;
    if (data === 1'bz) begin
      $error("ERROR: data_o is high-Z on the selected falling edge in ULTRASONIC mode!");
      error_count += 1;
    end

    // TEST 8: Power-down returns DATA to high-Z immediately.
    vdd = 1'b0;
    #1;

    if (data !== 1'bz) begin
      $error("ERROR: data_o is not high-Z after power-down!");
      error_count += 1;
    end

    if (error_count == 0) begin
      $display("YAHOO!! SPH0641LU4H_1_model bring up test passed.");
    end else begin
      $error("ERROR: %0d SPH0641LU4H_1_model bring up test(s) failed.", error_count);
    end

    $stop();
  end

  always #(half_period_ns) clk = ~clk;

endmodule
