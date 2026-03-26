`timescale 1 ps / 1 ps
// ------------------------------------------------------------
// Module: Mic_Clk_Ctrl
// Description: The Mic_Clk_Ctrl block selects between the four
//					    clock sources ensuring glitch free transition.
// Author: Srivibhav Jonnalagadda
// Date: 03-26-2026
// ------------------------------------------------------------
module Mic_Clk_Ctrl (
    // 50MHz system clock
    input logic clk_i,
    input logic rst_i,

    // Sleep, Low_Pwr, Standard, Ultra clocks
    input logic clk0_i,
    input logic clk1_i,
    input logic clk2_i,
    input logic clk3_i,

    // Select signal to choose one of the four mic clocks
    input logic [1:0] clk_sel_i,

    // Enable signal to enable one of the clocks
    input logic en_i,

    // Output clock and ready signal to ensure timing
    output logic clk_o,
    output logic clk_rdy_o
);

  /////////////////////////////////////////////////
  // Declare any internal signals as type logic //
  ///////////////////////////////////////////////
  logic en0, en1, en2, en3;
  logic clk_rdy, clk_rdy_int, clk_rdy_stable;
  //////////////////////////////////////////////

  // Synchronize the asynchronous clock-path-ready indication back into the system clock domain.
  always_ff @(posedge clk_i) begin
    if (rst_i) begin
      clk_rdy_int <= 1'b0;
      clk_rdy_stable <= 1'b0;
    end else begin
      clk_rdy_int <= clk_rdy;
      clk_rdy_stable <= clk_rdy_int;
    end
  end

  // The stable ready signal is output.
  assign clk_rdy_o = clk_rdy_stable;

  // Latch the sleep clock's enable when it is low.
  always_latch begin
    if (rst_i) en0 <= 1'b0;
    else if (!clk0_i) en0 <= en_i & (clk_sel_i == 2'h0) & ~en1 & ~en2 & ~en3;
  end

  // Latch the low power clock's enable when it is low.
  always_latch begin
    if (rst_i) en1 <= 1'b0;
    else if (!clk1_i) en1 <= en_i & (clk_sel_i == 2'h1) & ~en0 & ~en2 & ~en3;
  end

  // Latch the standard clock's enable when it is low.
  always_latch begin
    if (rst_i) en2 <= 1'b0;
    else if (!clk2_i) en2 <= en_i & (clk_sel_i == 2'h2) & ~en0 & ~en1 & ~en3;
  end

  // Latch the ultrasonic clock's enable when it is low.
  always_latch begin
    if (rst_i) en3 <= 1'b0;
    else if (!clk3_i) en3 <= en_i & (clk_sel_i == 2'h3) & ~en0 & ~en1 & ~en2;
  end

  // Only one enable and one clock will be active at any given time.
  assign clk_o = (clk0_i & en0) | (clk1_i & en1) | (clk2_i & en2) | (clk3_i & en3);

  // Assert ready only when the newly selected clock path has actually latched on.
  assign clk_rdy = ((clk_sel_i == 2'h0) & en0) |
                   ((clk_sel_i == 2'h1) & en1) |
                   ((clk_sel_i == 2'h2) & en2) |
                   ((clk_sel_i == 2'h3) & en3);

endmodule
