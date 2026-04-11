`timescale 1ns / 1ps
// ------------------------------------------------------------
// Testbench: FIR_tb
// Description: Basic sanity checks for the generated FIR IP.
//              Exercises reset, input handshake, output
//              backpressure, and mid-stream reset.
// Author: Codex
// Date: 04-10-2026
//
// DUT to instantiate in your design:
//   FIR
//
// Main DUT files needed for mixed-language simulation:
//   ../FIR.v
//   ../FIR/altera_avalon_sc_fifo.v
//   ../FIR/dspba_library_package.vhd
//   ../FIR/dspba_library.vhd
//   ../FIR/auk_dspip_math_pkg_hpfir.vhd
//   ../FIR/auk_dspip_lib_pkg_hpfir.vhd
//   ../FIR/auk_dspip_avalon_streaming_controller_hpfir.vhd
//   ../FIR/auk_dspip_avalon_streaming_sink_hpfir.vhd
//   ../FIR/auk_dspip_avalon_streaming_source_hpfir.vhd
//   ../FIR/auk_dspip_roundsat_hpfir.vhd
//   ../FIR/FIR_0002_rtl_core.vhd
//   ../FIR/FIR_0002_ast.vhd
//   ../FIR/FIR_0002.vhd
// ------------------------------------------------------------
module FIR_tb ();

  localparam int IN_WIDTH = 18;
  localparam int OUT_WIDTH = 41;
  localparam int MAX_RESPONSE_CYCLES = 1500;

  logic                        clk;
  logic                        reset_n;
  logic        [ IN_WIDTH-1:0] ast_sink_data;
  logic                        ast_sink_valid;
  logic        [          1:0] ast_sink_error;
  logic                        ast_sink_ready;
  logic        [OUT_WIDTH-1:0] ast_source_data;
  logic                        ast_source_valid;
  logic        [          1:0] ast_source_error;
  logic                        ast_source_ready;

  int                          error_count;
  int                          input_count;
  int                          output_count;

  logic signed [OUT_WIDTH-1:0] held_output_data;
  logic                        held_output_valid;

  FIR iDUT (
      .clk             (clk),
      .reset_n         (reset_n),
      .ast_sink_data   (ast_sink_data),
      .ast_sink_valid  (ast_sink_valid),
      .ast_sink_error  (ast_sink_error),
      .ast_sink_ready  (ast_sink_ready),
      .ast_source_data (ast_source_data),
      .ast_source_valid(ast_source_valid),
      .ast_source_error(ast_source_error),
      .ast_source_ready(ast_source_ready)
  );

  always #5 clk = ~clk;

  always @(posedge clk) begin
    if (!reset_n) begin
      output_count      <= 0;
      held_output_data  <= '0;
      held_output_valid <= 1'b0;
    end else begin
      if (ast_source_valid && ast_source_ready) begin
        output_count <= output_count + 1;
      end

      if (ast_source_valid) begin
        if (^ast_source_data === 1'bx) begin
          $error("ERROR: ast_source_data contains X when ast_source_valid is asserted.");
          error_count = error_count + 1;
        end

        if (ast_source_error !== 2'b00) begin
          $error("ERROR: ast_source_error is not 2'b00 when ast_source_valid is asserted.");
          error_count = error_count + 1;
        end
      end

      if (ast_source_valid && !ast_source_ready && !held_output_valid) begin
        held_output_data  <= ast_source_data;
        held_output_valid <= 1'b1;
      end else if (ast_source_valid && ast_source_ready) begin
        held_output_valid <= 1'b0;
      end
    end
  end

  task automatic drive_sample(input logic signed [IN_WIDTH-1:0] sample);
    begin
      @(negedge clk);
      ast_sink_data  <= sample;
      ast_sink_valid <= 1'b1;
      ast_sink_error <= 2'b00;

      while (ast_sink_ready !== 1'b1) begin
        @(negedge clk);
      end

      @(posedge clk);
      input_count <= input_count + 1;

      @(negedge clk);
      ast_sink_valid <= 1'b0;
      ast_sink_data  <= '0;
    end
  endtask

  task automatic wait_cycles(input int cycles);
    repeat (cycles) @(posedge clk);
  endtask

  task automatic expect_output_activity(input int max_cycles, input string test_name);
    int start_count;
    begin
      start_count = output_count;
      repeat (max_cycles) begin
        @(posedge clk);
        if (output_count > start_count) begin
          return;
        end
      end

      $error("ERROR: %s did not produce any accepted output within %0d cycles.", test_name,
             max_cycles);
      error_count += 1;
    end
  endtask

  task automatic expect_output_count_greater_than(input int baseline_count, input int max_cycles,
                                                  input string test_name);
    begin
      if (output_count > baseline_count) begin
        return;
      end

      repeat (max_cycles) begin
        @(posedge clk);
        if (output_count > baseline_count) begin
          return;
        end
      end

      $error("ERROR: %s did not increase the accepted output count within %0d cycles.", test_name,
             max_cycles);
      error_count += 1;
    end
  endtask

  task automatic wait_for_output_valid(input int max_cycles, input string test_name);
    begin
      repeat (max_cycles) begin
        @(posedge clk);
        if (ast_source_valid === 1'b1) begin
          return;
        end
      end

      $error("ERROR: %s never asserted ast_source_valid within %0d cycles.", test_name, max_cycles);
      error_count += 1;
    end
  endtask

  initial begin
    int baseline_outputs;

    clk              = 1'b0;
    reset_n          = 1'b0;
    ast_sink_data    = '0;
    ast_sink_valid   = 1'b0;
    ast_sink_error   = 2'b00;
    ast_source_ready = 1'b1;
    error_count      = 0;
    input_count      = 0;
    output_count     = 0;

    repeat (5) @(posedge clk);
    reset_n = 1'b1;
    repeat (2) @(posedge clk);

    // TEST 1: Outputs should be quiet right after reset is released.
    if (ast_source_valid !== 1'b0) begin
      $error("ERROR: ast_source_valid is not low immediately after reset release.");
      error_count += 1;
    end

    // TEST 2: An impulse should be accepted and eventually create output activity.
    baseline_outputs = output_count;
    drive_sample(18'sd1);
    repeat (8) drive_sample(18'sd0);
    expect_output_count_greater_than(baseline_outputs, MAX_RESPONSE_CYCLES, "Impulse response");

    // TEST 3: Drive a short constant stream as an example stimulus burst.
    repeat (16) drive_sample(18'sd1024);
    wait_cycles(64);

    // TEST 4: Example backpressure window. This shows how to stall the output.
    repeat (12) drive_sample(18'sd256);
    ast_source_ready = 1'b0;
    wait_cycles(24);
    ast_source_ready = 1'b1;
    wait_cycles(64);

    // TEST 5: Mid-stream reset should force the interface back to a safe state.
    repeat (4) drive_sample(-18'sd64);
    wait_cycles(4);
    reset_n = 1'b0;
    @(posedge clk);

    if (ast_source_valid !== 1'b0) begin
      $error("ERROR: ast_source_valid is not low during reset.");
      error_count += 1;
    end

    reset_n = 1'b1;
    wait_cycles(4);
    baseline_outputs = output_count;
    drive_sample(18'sd1);
    expect_output_count_greater_than(baseline_outputs, MAX_RESPONSE_CYCLES, "Post-reset impulse");

    if (error_count == 0) begin
      $display("YAHOO!! All FIR tests passed.");
    end else begin
      $error("ERROR: %0d FIR test(s) failed.", error_count);
    end

    $stop();
  end

endmodule
