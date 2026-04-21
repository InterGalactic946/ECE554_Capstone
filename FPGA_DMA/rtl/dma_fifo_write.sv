module dma_fifo_write (
    input logic clk,
    input logic rst_n,
    input logic [15:0] input0,
    input logic [15:0] input1,
    input logic [15:0] input2,
    input logic [15:0] input3,
    input logic [15:0] input4,
    input logic [15:0] input5,
    input logic [15:0] input6,
    input logic [15:0] input7,
    input logic input0_valid,
    input logic input1_valid,
    input logic input2_valid,
    input logic input3_valid,
    input logic input4_valid,
    input logic input5_valid,
    input logic input6_valid,
    input logic input7_valid,
    input logic write_pending,
    input logic ps_ready_for_data,
    output logic [127:0] write_data,
    output logic write_en
);

    
    logic [15:0] buffer [7:0];
    logic [7:0] done;
    logic aq_done;

    assign aq_done = &done; // All inputs have been captured when all bits of 'done' are 1

  // PCM Buffer Layout {pcm_pos_1_first, pcm_pos_1_second, pcm_pos_2_first, pcm_pos_2_second, pcm_neg_1_first, pcm_neg_1_second, pcm_neg_2_first, pcm_neg_2_second}
  always_ff @(posedge clk, negedge rst_n) begin
    if (!rst_n) begin
      buffer <= '{default: '0};
    end else begin
      buffer[0] <= input0_valid ? input0 : buffer[0];
      buffer[1] <= input1_valid ? input1 : buffer[1];
      buffer[2] <= input2_valid ? input2 : buffer[2];
      buffer[3] <= input3_valid ? input3 : buffer[3];
      buffer[4] <= input4_valid ? input4 : buffer[4];
      buffer[5] <= input5_valid ? input5 : buffer[5];
      buffer[6] <= input6_valid ? input6 : buffer[6];
      buffer[7] <= input7_valid ? input7 : buffer[7];
    end
  end

  always_ff @(posedge clk, negedge rst_n) begin
    if (!rst_n) begin
        done <= '0;
    end else if (aq_done) begin
        done <= '0; // Reset done flags after all inputs have been captured
    end else begin
        done[0] <= input0_valid ? 1'b1 : done[0];
        done[1] <= input1_valid ? 1'b1 : done[1];
        done[2] <= input2_valid ? 1'b1 : done[2];
        done[3] <= input3_valid ? 1'b1 : done[3];
        done[4] <= input4_valid ? 1'b1 : done[4];
        done[5] <= input5_valid ? 1'b1 : done[5];
        done[6] <= input6_valid ? 1'b1 : done[6];
        done[7] <= input7_valid ? 1'b1 : done[7];
    end
  end

  always_ff @(posedge clk, negedge rst_n) begin
    if (!rst_n) begin
      write_en <= 1'b0;
    end else if (aq_done) begin
      write_en <= 1'b1;
    end else if (!write_pending) begin
      write_en <= 1'b0;
    end
  end

  always_ff @(posedge clk, negedge rst_n) begin
    if (!rst_n) begin
      write_data <= '0;
    end else if (aq_done) begin
      write_data <= buffer;
    end
  end
endmodule
