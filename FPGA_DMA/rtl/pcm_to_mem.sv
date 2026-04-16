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
    input logic ps_ready_for_data,
    output logic [127:0] write_data,
    output logic write_en
);

    logic pcm_pos_second, pcm_neg_second;

    logic [127:0] pcm_buffer;
    logic [15:0] pcm_pos_1_first, pcm_pos_1_second, pcm_pos_2_first, pcm_pos_2_second;
    logic [15:0] pcm_neg_1_first, pcm_neg_1_second, pcm_neg_2_first, pcm_neg_2_second;
    logic [2:0] pcm_count;


    always_comb begin
        pcm_pos_1_first = (pcm_pos_valid_1 && !pcm_pos_second) ? pcm_pos_1 : pcm_buffer[127:112];
        pcm_pos_1_second = (pcm_pos_valid_1 && pcm_pos_second) ? pcm_pos_1 : pcm_buffer[111:96];
        pcm_pos_2_first = (pcm_pos_valid_2 && !pcm_pos_second) ? pcm_pos_2 : pcm_buffer[95:80];
        pcm_pos_2_second = (pcm_pos_valid_2 && pcm_pos_second) ? pcm_pos_2 : pcm_buffer[79:64];
        pcm_neg_1_first = (pcm_neg_valid_1 && !pcm_neg_second) ? pcm_neg_1 : pcm_buffer[63:48];
        pcm_neg_1_second = (pcm_neg_valid_1 && pcm_neg_second) ? pcm_neg_1 : pcm_buffer[47:32];
        pcm_neg_2_first = (pcm_neg_valid_2 && !pcm_neg_second) ? pcm_neg_2 : pcm_buffer[31:16];
        pcm_neg_2_second = (pcm_neg_valid_2 && pcm_neg_second) ? pcm_neg_2 : pcm_buffer[15:0];
    end
    // PCM Buffer Layout {pcm_pos_1_first, pcm_pos_1_second, pcm_pos_2_first, pcm_pos_2_second, pcm_neg_1_first, pcm_neg_1_second, pcm_neg_2_first, pcm_neg_2_second}
    always_ff @( posedge clk, negedge rst_n ) begin
        if ( !rst_n ) begin
            pcm_buffer <= '0;
        end else begin
            pcm_buffer <= {pcm_pos_1_first, pcm_pos_1_second, pcm_pos_2_first, pcm_pos_2_second, pcm_neg_1_first, pcm_neg_1_second, pcm_neg_2_first, pcm_neg_2_second};
        end
    end

    always_ff @( posedge clk, negedge rst_n ) begin
        if ( !rst_n ) begin
            pcm_count <= '0;
        end else if ((pcm_count == 3'd4)) begin
            pcm_count <= '0;
        end else if (ps_ready_for_data && (pcm_pos_valid_1 || pcm_pos_valid_2 || pcm_neg_valid_1 || pcm_neg_valid_2)) begin
            pcm_count <= pcm_count + 1;
        end
    end

    always_ff @( posedge clk, negedge rst_n) begin
        if ( !rst_n ) begin
            pcm_pos_second <= 0;
            pcm_neg_second <= 0;
        end else if (ps_ready_for_data && (pcm_pos_valid_1 || pcm_pos_valid_2)) begin
            pcm_pos_second <= ~pcm_pos_second; // Toggle between first and second PCM samples
        end else if (ps_ready_for_data && (pcm_neg_valid_1 || pcm_neg_valid_2)) begin
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
endmodule