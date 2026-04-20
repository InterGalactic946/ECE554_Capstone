module wavefront_detection #(
    parameter int unsigned STA_LEN = 16,    // Short term average length (power of 2 between 8 and 2048)
    parameter int unsigned LTA_LEN = 512,   // Long term average length (power of 2 between 8 and 2048)
    parameter int unsigned THRESHOLD = 4    // How many times the STA must exceed the LTA to trigger a detection
) (
    input logic clk,
    input logic rst_n,
    input logic [15:0] data_in,
    input logic data_valid,
    output logic detection_out
);

  logic [15:0] sta_mean, lta_mean;
  logic sta_valid, lta_valid;

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
      detection_out <= 0;
    end else if (sta_valid && lta_valid) begin
      detection_out <= (sta_mean > (lta_mean << $clog2(THRESHOLD))) ? 1 : 0;
    end else begin
      detection_out <= 0;  // Clear detection when not valid
    end
  end

endmodule
