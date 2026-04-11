`timescale 1ns / 1ps
// ------------------------------------------------------------
// Testbench: Cic_Decimator_tb
// Description: Verifies Cic_Decimator behavior ensuring basic
//              reset, handshake, stall, and streaming edge
//              cases pass.
// Author: Srivibhav Jonnalagadda
// Date: 04-09-2026
// ------------------------------------------------------------
module Cic_Decimator_tb ();

  /////////////////////////////
  // Stimulus of type logic //
  ///////////////////////////
  logic [ 1:0] in_error;
  logic        in_valid;
  logic        in_ready;
  logic [ 1:0] in_data;
  logic [17:0] out_data;
  logic [ 1:0] out_error;
  logic        out_valid;
  logic        out_ready;
  logic        clk;
  logic        reset_n;
  int          error_count;
  int          output_count;

  //////////////////////
  // Instantiate DUT //
  ////////////////////
  Cic_Decimator_192 iDUT (
      .in_error (in_error),
      .in_valid (in_valid),
      .in_ready (in_ready),
      .in_data  (in_data),
      .out_data (out_data),
      .out_error(out_error),
      .out_valid(out_valid),
      .out_ready(out_ready),
      .clk      (clk),
      .reset_n  (reset_n)
  );

  // Count accepted output samples.
  always @(posedge clk) begin
    if (out_valid && out_ready) begin
      output_count += 1;
    end
  end

  initial begin
    clk = 1'b0;
    reset_n = 1'b0;
    in_valid = 1'b0;
    in_data = 2'b00;
    in_error = 2'b00;
    out_ready = 1'b1;
    error_count = 0;
    output_count = 0;

    // Hold reset for a few cycles.
    repeat (5) @(posedge clk);
    reset_n = 1'b1;
    repeat (2) @(posedge clk);

    // TEST 1: Outputs should stay quiet immediately after reset.
    if (out_valid !== 1'b0) begin
      $error("ERROR: out_valid is not low immediately after reset!");
      error_count += 1;
    end

    if (^out_error === 1'bx) begin
      $error("ERROR: out_error contains X immediately after reset!");
      error_count += 1;
    end

    // TEST 2: A stream of valid inputs should eventually produce output.
    repeat (32) begin
      @(negedge clk) begin
        in_valid = 1'b1;
        in_data  = 2'b01;
        in_error = 2'b00;
      end
    end

    @(negedge clk) in_valid = 1'b0;
    @(negedge clk) in_data = 2'b00;

    repeat (64) @(posedge clk);

    if (output_count == 0) begin
      $error("ERROR: No output samples were observed after a valid input stream!");
      error_count += 1;
    end

    // TEST 3: Clean input stream should not raise out_error.
    if (out_error !== 2'b00) begin
      $error("ERROR: out_error is not 2'b00 for a clean input stream!");
      error_count += 1;
    end

    // TEST 4: Output data should not contain X when valid.
    if (out_valid && (^out_data === 1'bx)) begin
      $error("ERROR: out_data contains X when out_valid is asserted!");
      error_count += 1;
    end

    // TEST 5: With out_ready low, out_valid may assert but the accepted output count should not change.
    repeat (32) begin
      @(negedge clk) begin
        in_valid = 1'b1;
        in_data  = 2'b01;
      end
    end

    @(negedge clk) begin
      in_valid = 1'b0;
      in_data  = 2'b00;
    end

    repeat (16) @(posedge clk);
    output_count = 0;
    out_ready = 1'b0;
    repeat (32) @(posedge clk);

    if (output_count != 0) begin
      $error("ERROR: Output samples were accepted while out_ready was low!");
      error_count += 1;
    end

    out_ready = 1'b1;
    repeat (16) @(posedge clk);

    // TEST 6: Alternating edge-case inputs should still produce output.
    output_count = 0;

    repeat (16) begin
      @(negedge clk) begin
        in_valid = 1'b1;
        in_data  = 2'b01;
      end
      @(negedge clk) begin
        in_valid = 1'b1;
        in_data  = 2'b11;
      end
    end

    @(negedge clk) begin
      in_valid = 1'b0;
      in_data  = 2'b00;
    end

    repeat (64) @(posedge clk);

    if (output_count == 0) begin
      $error("ERROR: No output samples were observed for alternating input data!");
      error_count += 1;
    end

    // TEST 7: Mid-stream reset should force the interface back to a safe state.
    @(negedge clk) begin
      in_valid = 1'b1;
      in_data  = 2'b01;
    end

    repeat (4) @(posedge clk);
    reset_n = 1'b0;
    @(posedge clk);

    if (out_valid !== 1'b0) begin
      $error("ERROR: out_valid is not low during reset!");
      error_count += 1;
    end

    reset_n = 1'b1;
    @(posedge clk);
    @(negedge clk) begin
      in_valid = 1'b0;
      in_data  = 2'b00;
    end

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
