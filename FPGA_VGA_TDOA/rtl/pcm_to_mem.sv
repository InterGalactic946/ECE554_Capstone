module pcm_to_mem (
    input logic clk,
    input logic rst_n,
    input logic [15:0] pcm_pos_1,
    input logic [15:0] pcm_pos_2,
    input logic [15:0] pcm_neg_1,
    input logic [15:0] pcm_neg_2,
    input logic pcm_pos_valid_1,
    input logic pcm_pos_valid_2,
    input logic pcm_neg_valid_1,
    input logic pcm_neg_valid_2,
    input logic write_pending,
    output logic [127:0] write_data,
    output logic write_en
);

    logic pcm_pos_second, pcm_neg_second;

    logic [127:0] pcm_buffer;
    logic [2:0] pcm_count;

    // PCM Buffer Layout {pcm_pos_1_first, pcm_pos_1_second, pcm_pos_2_first, pcm_pos_2_second, pcm_neg_1_first, pcm_neg_1_second, pcm_neg_2_first, pcm_neg_2_second}
    always_ff @( posedge clk, negedge rst_n ) begin
        if ( !rst_n ) begin
            pcm_buffer <= '0;
        end else if ((pcm_pos_valid_1 || pcm_pos_valid_2) && ~pcm_pos_second) begin
            pcm_buffer <= {pcm_pos_1, pcm_buffer[111:96], pcm_pos_2, pcm_buffer[79:0]};
        end else if ((pcm_pos_valid_1 || pcm_pos_valid_2) && pcm_pos_second) begin
            pcm_buffer <= {pcm_buffer[127:112], pcm_pos_1, pcm_buffer[95:80], pcm_pos_2, pcm_buffer[63:0]};
        end else if ((pcm_neg_valid_1 || pcm_neg_valid_2) && ~pcm_neg_second) begin
            pcm_buffer <= {pcm_buffer[127:64], pcm_neg_1, pcm_buffer[47:32], pcm_neg_2, pcm_buffer[15:0]};
        end else if ((pcm_neg_valid_1 || pcm_neg_valid_2) && pcm_neg_second) begin
            pcm_buffer <= {pcm_buffer[127:48], pcm_neg_1, pcm_buffer[31:16], pcm_neg_2};
        end
    end

    always_ff @( posedge clk, negedge rst_n ) begin
        if ( !rst_n ) begin
            pcm_count <= '0;
        end else if (mem_write_en) begin
            pcm_count <= '0;
        end else if (pcm_pos_valid_1 || pcm_pos_valid_2 || pcm_neg_valid_1 || pcm_neg_valid_2) begin
            pcm_count <= pcm_count + 1;
        end
    end

    always_ff @( posedge clk, negedge rst_n) begin
        if ( !rst_n ) begin
            pcm_pos_second <= 0;
            pcm_neg_second <= 0;
        end else if (pcm_pos_valid_1 || pcm_pos_valid_2) begin
            pcm_pos_second <= ~pcm_pos_second; // Toggle between first and second PCM samples
        end else if (pcm_neg_valid_1 || pcm_neg_valid_2) begin
            pcm_neg_second <= ~pcm_neg_second; // Toggle between first and second PCM samples
        end
    end

    always_ff @( posedge clk, negedge rst_n ) begin
        if (!rst_n) begin 
            write_en <= 1'b0;
        end else if (pcm_count == 3'd4) begin
            write_en <= 1'b1;
        end else if (!write_pending) begin
            write_en <= 1'b0;
        end
    end

    always_ff @( posedge clk, negedge rst_n ) begin
        if ( !rst_n ) begin
            write_data <= '0;
        end else if ((pcm_count == 3'd4)) begin
            write_data <= pcm_buffer;
        end
    end

    always_ff @( posedge clk, negedge rst_n ) begin
        if ( !rst_n ) begin
            mem_addr <= '0;
        end else if (mem_write_en) begin
            mem_addr <= mem_addr + 1;
        end
    end

    assign mem_byte_en = 16'hFFFF; // Enable all bytes

    assign mem_chip_select = 1'b1; // Always select the memory

endmodule