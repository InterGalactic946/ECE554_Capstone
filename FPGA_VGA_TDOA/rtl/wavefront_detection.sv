module wavefront_detection #(
    parameter int unsigned STA_LEN = 32,    // Short term average length (power of 2 between 8 and 2048)
    parameter int unsigned LTA_LEN = 512,   // Long term average length (power of 2 between 8 and 2048)
    parameter int unsigned THRESHOLD = 4,    // How many times the STA must exceed the LTA to trigger a detection
    parameter int MIC_THRESHOLD = 16'd1000  // Minimum absolute sample value to consider for detection
) (
    input logic clk,
    input logic rst_n,
    input logic [15:0] data_in,
    input logic data_valid,
    output logic detection_out,
    output logic [15:0] sta_mean,
    output logic [15:0] lta_mean,
    output logic sta_valid,
    output logic lta_valid
);

//   logic [15:0] sta_mean, lta_mean;
//   logic sta_valid, lta_valid;

  logic detection_out_internal;
  logic above_mic_threshold;

  window_mean #(
      .WINDOW_SIZE(STA_LEN)
  ) sta_window (
      .clk(clk),
      .rst_n(rst_n),
      .data_in(data_in),
      .data_valid(data_valid),
      .mean_out(sta_mean),
      .mean_valid(sta_valid)
  );

  window_mean #(
      .WINDOW_SIZE(LTA_LEN)
  ) lta_window (
      .clk(clk),
      .rst_n(rst_n),
      .data_in(data_in),
      .data_valid(data_valid),
      .mean_out(lta_mean),
      .mean_valid(lta_valid)
  );

  always_ff @(posedge clk, negedge rst_n) begin
    if (!rst_n) begin
      detection_out_internal <= 0;
    end else if (sta_valid && lta_valid) begin
      detection_out_internal <= (sta_mean > (lta_mean << $clog2(THRESHOLD))) ? 1 : 0;
    end else begin
      detection_out_internal <= 0;  // Clear detection when not valid
    end
  end

  assign above_mic_threshold = data_in >= MIC_THRESHOLD;
  assign detection_out = above_mic_threshold & detection_out_internal;

endmodule
