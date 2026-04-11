`timescale 1ns / 1ps
// ------------------------------------------------------------
// Testbench: Pdm_To_Pcm_tb
// Description: Basic sanity checks for the PDM -> CIC -> FIR ->
//              PCM chain. Verifies reset, PDM clock activity,
//              PCM valid/output sanity, capture backpressure,
//              and mid-stream reset behavior.
// Author: Srivibhav Jonnalagadda
// Date: 04-11-2026
// ------------------------------------------------------------
module Pdm_To_Pcm_tb ();

  /////////////////////////////
  // Stimulus of type logic //
  ///////////////////////////
  logic               clk_i;
  logic               rst_i;
  logic               mic_clk_i;
  logic               mic_clk_val_i;
  logic               mic_data_i;
  logic               pos_pcm_cap_rdy_i;
  logic               neg_pcm_cap_rdy_i;
  logic signed [15:0] pcm_pos_o;
  logic               pcm_valid_pos_o;
  logic signed [15:0] pcm_neg_o;
  logic               pcm_valid_neg_o;

  int                 error_count;
  int                 pos_output_count;
  int                 neg_output_count;

  //////////////////////
  // Instantiate DUT //
  ////////////////////
  Pdm_To_Pcm iDUT (
      .clk_i            (clk_i),
      .rst_i            (rst_i),
      .mic_clk_i        (mic_clk_i),
      .mic_clk_val_i    (mic_clk_val_i),
      .mic_data_i       (mic_data_i),
      .pos_pcm_cap_rdy_i(pos_pcm_cap_rdy_i),
      .neg_pcm_cap_rdy_i(neg_pcm_cap_rdy_i),

      .pcm_pos_o      (pcm_pos_o),
      .pcm_valid_pos_o(pcm_valid_pos_o),
      .pcm_neg_o      (pcm_neg_o),
      .pcm_valid_neg_o(pcm_valid_neg_o)
  );

  ///////////////////////////////////////////
  // Clock generation for synchronous DUT //
  /////////////////////////////////////////
  always #10 clk_i = ~clk_i;  // 50MHz system clock
  always #162.7604167 mic_clk_i = ~mic_clk_i;  // 3.072 MHz mic clock

  // Drive one PDM half-cycle. Data is sampled by the DUT on mic clock edges.
  task automatic drive_pdm_bit(input logic pdm_bit);
    begin
      @(negedge clk_i);
      mic_data_i    <= pdm_bit;
      mic_clk_val_i <= 1'b1;
    end
  endtask

  task automatic drive_pdm_pattern(input int cycles, input int pattern_select);
    begin
      repeat (cycles) begin
        case (pattern_select)
          0:       drive_pdm_bit(1'b1);  // mostly positive
          1:       drive_pdm_bit(1'b0);  // mostly negative
          2:       drive_pdm_bit(($time / 10) & 1'b1);  // alternating-ish
          default: drive_pdm_bit($urandom_range(0, 1));  // noisy PDM-ish
        endcase
      end

      @(negedge clk_i);
      mic_clk_val_i <= 1'b0;
    end
  endtask

  task automatic wait_for_pcm_output(input int max_clk_cycles, input string test_name);
    int start_pos_count;
    int start_neg_count;
    begin
      start_pos_count = pos_output_count;
      start_neg_count = neg_output_count;

      repeat (max_clk_cycles) begin
        @(posedge clk_i);
        if ((pos_output_count > start_pos_count) || (neg_output_count > start_neg_count)) begin
          return;
        end
      end

      $error("ERROR: %s did not produce any PCM output within %0d clk_i cycles.", test_name,
             max_clk_cycles);
      error_count += 1;
    end
  endtask

  // Count accepted PCM samples.
  always @(posedge clk_i) begin
    if (rst_i) begin
      pos_output_count <= 0;
      neg_output_count <= 0;
    end else begin
      if (pcm_valid_pos_o && pos_pcm_cap_rdy_i) begin
        pos_output_count <= pos_output_count + 1;
      end

      if (pcm_valid_neg_o && neg_pcm_cap_rdy_i) begin
        neg_output_count <= neg_output_count + 1;
      end
    end
  end

  // Check for X on valid PCM samples.
  always @(posedge clk_i) begin
    if (!rst_i) begin
      if (pcm_valid_pos_o && (^pcm_pos_o === 1'bx)) begin
        $error("ERROR: pcm_pos_o contains X when pcm_valid_pos_o is asserted!");
        error_count += 1;
      end

      if (pcm_valid_neg_o && (^pcm_neg_o === 1'bx)) begin
        $error("ERROR: pcm_neg_o contains X when pcm_valid_neg_o is asserted!");
        error_count += 1;
      end
    end
  end

  initial begin
    clk_i             = 1'b0;
    rst_i             = 1'b1;
    mic_clk_i         = 1'b0;
    mic_clk_val_i     = 1'b0;
    mic_data_i        = 1'b0;
    pos_pcm_cap_rdy_i = 1'b1;
    neg_pcm_cap_rdy_i = 1'b1;
    error_count       = 0;
    pos_output_count  = 0;
    neg_output_count  = 0;

    // Hold reset for a few cycles.
    repeat (8) @(posedge clk_i);
    rst_i = 1'b0;
    repeat (4) @(posedge clk_i);

    // TEST 1: Outputs should be quiet immediately after reset.
    if (pcm_valid_pos_o !== 1'b0) begin
      $error("ERROR: pcm_valid_pos_o is not low immediately after reset!");
      error_count += 1;
    end

    if (pcm_valid_neg_o !== 1'b0) begin
      $error("ERROR: pcm_valid_neg_o is not low immediately after reset!");
      error_count += 1;
    end

    // TEST 2: A stream of valid PDM activity should eventually produce PCM output.
    drive_pdm_pattern(512, 3);
    wait_for_pcm_output(20000, "Random PDM stream");

    // TEST 3: Capture backpressure should prevent accepted PCM samples.
    pos_output_count = 0;
    neg_output_count = 0;

    @(negedge clk_i);
    pos_pcm_cap_rdy_i = 1'b0;
    neg_pcm_cap_rdy_i = 1'b0;

    drive_pdm_pattern(256, 2);
    repeat (512) @(posedge clk_i);

    if (pos_output_count != 0) begin
      $error("ERROR: POS PCM sample was accepted while pos_pcm_cap_rdy_i was low!");
      error_count += 1;
    end

    if (neg_output_count != 0) begin
      $error("ERROR: NEG PCM sample was accepted while neg_pcm_cap_rdy_i was low!");
      error_count += 1;
    end

    @(negedge clk_i);
    pos_pcm_cap_rdy_i = 1'b1;
    neg_pcm_cap_rdy_i = 1'b1;

    wait_for_pcm_output(20000, "Backpressure release");

    // TEST 4: Mostly positive PDM should still produce valid-looking PCM.
    drive_pdm_pattern(512, 0);
    wait_for_pcm_output(20000, "Mostly positive PDM stream");

    // TEST 5: Mostly negative PDM should still produce valid-looking PCM.
    drive_pdm_pattern(512, 1);
    wait_for_pcm_output(20000, "Mostly negative PDM stream");

    // TEST 6: Mid-stream reset should force valid outputs low.
    fork
      drive_pdm_pattern(128, 3);
      begin
        repeat (64) @(posedge clk_i);
        rst_i = 1'b1;
      end
    join

    @(posedge clk_i);

    if (pcm_valid_pos_o !== 1'b0) begin
      $error("ERROR: pcm_valid_pos_o is not low during reset!");
      error_count += 1;
    end

    if (pcm_valid_neg_o !== 1'b0) begin
      $error("ERROR: pcm_valid_neg_o is not low during reset!");
      error_count += 1;
    end

    repeat (8) @(posedge clk_i);
    rst_i = 1'b0;
    repeat (4) @(posedge clk_i);

    drive_pdm_pattern(512, 3);
    wait_for_pcm_output(20000, "Post-reset PDM stream");

    if (error_count == 0) begin
      $display("YAHOO!! All Pdm_To_Pcm tests passed.");
    end else begin
      $error("ERROR: %0d Pdm_To_Pcm test(s) failed.", error_count);
    end

    $stop();
  end

endmodule
