`timescale 1ns / 1ps
// ------------------------------------------------------------
// Module: Pdm_To_Pcm
// Description: Converts PDM data from two microphones (Hi-Mic
//              and Lo-Mic) into PCM format. The module samples
//              the PDM data, processes it through a CIC decimator,
//              and applies FIR compensation to produce the final
//              PCM output. The design supports both single and dual
//              microphone modes based on the mic_mode input.
// Author: Nate Parmley
// Date: 04-01-2026
// ------------------------------------------------------------
module Pdm_To_Pcm (
    input logic clk_i,
    input logic rst_i,
    input logic mic_clk_i,
    input logic mic_clk_val_i,
    input logic mic_data_i,
    input logic [1:0] mic_mode_i,

    output logic [15:0] pcm_pos_o,
    output logic pcm_valid_pos_o,
    output logic [15:0] pcm_neg_o,
    output logic pcm_valid_neg_o
);

  /////////////////////////////////////////////////
  // Declare any internal signals as type logic //
  ///////////////////////////////////////////////
  logic mic_clk_step, mic_clk_stable;
  logic mic_clk_stable_prev;
  logic mic_clk_en;
  logic mic_clk_rising, mic_clk_falling;
  logic pdm_pos_valid, pdm_neg_valid;
  logic pdm_pos, pdm_neg;
  logic [1:0] data_in_pos, data_in_neg;
  logic cic_valid_pos, cic_valid_neg;
  logic [17:0] cic_out_pos, cic_out_neg;
  logic [17:0] comp_out_pos, comp_out_neg;

  logic [7:0] clk_cnt;
  logic volt_on;
  logic [11:0] volt_lvl;
  ///////////////////////////////////////////////

  // Synchronize the microphone clock and generate an enable signal for sampling.
  always_ff @(posedge clk_i) begin
    if (rst_i) begin
      mic_clk_step   <= 1'b0;
      mic_clk_stable <= 1'b0;
    end else begin
      mic_clk_step   <= mic_clk_i;
      mic_clk_stable <= mic_clk_step;
    end
  end

  // Get the previous value of mic_clk_stable to detect edges.
  always_ff @(posedge clk_i) begin
    if (rst_i) begin
      mic_clk_stable_prev <= 1'b0;
    end else begin
      mic_clk_stable_prev <= mic_clk_stable;
    end
  end

  // Detect an edge on mic_clk.
  assign mic_clk_rising = (~mic_clk_stable_prev & mic_clk_stable);
  assign mic_clk_falling = (mic_clk_stable_prev & ~mic_clk_stable);
  assign mic_clk_en = mic_clk_val_i & (mic_clk_rising | mic_clk_falling);

  // 1-cycle delay to align valid signals with DDIO output latency
  always_ff @(posedge clk_i) begin
    if (rst_i) begin
      pdm_pos_valid <= 1'b0;
      pdm_neg_valid <= 1'b0;
    end else begin
      // Mic (High) is valid after falling edge
      pdm_pos_valid <= mic_clk_falling;
      // Mic (Low) is valid on rising edge
      pdm_neg_valid <= mic_clk_rising;
    end
  end

  // Instantiate the PDM data sampler.
  // NOTE: We latch the Hi-Mic's data on clk low and the Lo-Mic's data
  // on clk high to ensure we capture the correct bits for each mic mode.
  Mic_Data_In iPDM_Sampler (
      .inclock(clk_i),
      .sclr(rst_i),
      .inclocken(mic_clk_en),
      .datain(mic_data_i),

      .dataout_h(pdm_neg),
      .dataout_l(pdm_pos)
  );

  // Convert the latched PDM bits into 2-bit values for the CIC decimator.
  // If pdm data is 1, we input 2'b01 to represent a positive pulse;
  // if it's 0, we input 2'b11 to represent a negative pulse.
  always_ff @(posedge clk_i) begin
    if (rst_i) begin
      data_in_pos <= 2'b00;
      data_in_neg <= 2'b00;
    end else begin
      // Makes data_in stable for the CIC exactly when the valid pulses are high
      data_in_pos <= (pdm_pos) ? 2'b01 : 2'b11;
      data_in_neg <= (pdm_neg) ? 2'b01 : 2'b11;
    end
  end

  // CIC for Mic High (sampled on falling Edge)
  Cic_Decimator iPOS_MIC (
      .clk    (clk_i),
      .clken  (1'b1),
      .reset_n(~rst_i),

      .in_error (2'b00),
      .in_data  (data_in_pos),
      .in_valid (pdm_pos_valid),
      .out_ready(1'b1),

      .in_ready (),
      .out_data (cic_out_pos),
      .out_valid(cic_valid_pos),
      .out_error()
  );

  // CIC for Mic Low (sampled on rising Edge)
  Cic_Decimator iNEG_MIC (
      .clk    (clk_i),
      .clken  (1'b1),
      .reset_n(~rst_i),

      .in_error (2'b00),
      .in_data  (data_in_neg),
      .in_valid (pdm_neg_valid),
      .out_ready(1'b1),

      .in_ready (),
      .out_data (cic_out_neg),
      .out_valid(cic_valid_neg),
      .out_error()
  );

  fir_comp iPOSCOMP (
      .clk(mic_clk),
      .rst_n(rst_n),
      .in_valid(output_valid_pos),
      .in_data(cic_out_pos),
      .out_data(comp_out_pos)
  );

  fir_comp iNEGCOMP (
      .clk(mic_clk),
      .rst_n(rst_n),
      .in_valid(output_valid_neg),
      .in_data(cic_out_neg),
      .out_data(comp_out_neg)
  );

  assign pcm_valid_pos = output_valid_pos & ~output_valid_pos_delayed;
  assign pcm_valid_neg = output_valid_neg & ~output_valid_neg_delayed;

  assign pcm_pos = comp_out_pos[17] ? (~&comp_out_pos[16:15] ? 16'h800 : comp_out_pos[15:0]) 
                                      : (|comp_out_pos[16:15] ? 16'h7FF : comp_out_pos[15:0]);

  assign pcm_neg = comp_out_neg[17] ? (~&comp_out_neg[16:15] ? 16'h800 : comp_out_neg[15:0]) 
                                      : (|comp_out_neg[16:15] ? 16'h7FF : comp_out_neg[15:0]);

  always @(posedge clk, negedge rst_n) begin
    if (!rst_n) begin
      pdm_pos <= 1'b0;
      pdm_neg <= 1'b0;
    end else begin
      if (mic_mode == 2'b10) begin
        if (clk_cnt == 6) begin
          pdm_pos <= mic_raw;
        end else if (clk_cnt == 16) begin
          pdm_neg <= mic_raw;
        end
      end else if (mic_mode == 2'b11) begin
        if (clk_cnt == 4) begin
          pdm_pos <= mic_raw;
        end else if (clk_cnt == 13) begin
          pdm_neg <= mic_raw;
        end
      end
    end
  end

  always @(posedge clk, negedge rst_n) begin
    if (!rst_n) begin
      clk_cnt <= 1'b0;
    end else begin
      if (mic_clk && !mic_clk_delayed) begin
        clk_cnt <= 1'b0;
      end else begin
        clk_cnt <= clk_cnt + 1;
      end
    end
  end

  always @(posedge clk, negedge rst_n) begin
    if (!rst_n) begin
      mic_clk_delayed <= 1'b0;
    end else begin
      mic_clk_delayed <= mic_clk;
    end
  end

  always @(posedge clk, negedge rst_n) begin
    if (!rst_n) begin
      output_valid_pos_delayed <= 1'b0;
    end else begin
      output_valid_pos_delayed <= output_valid_pos;
    end
  end

  always @(posedge clk, negedge rst_n) begin
    if (!rst_n) begin
      output_valid_neg_delayed <= 1'b0;
    end else begin
      output_valid_neg_delayed <= output_valid_neg;
    end
  end

endmodule
