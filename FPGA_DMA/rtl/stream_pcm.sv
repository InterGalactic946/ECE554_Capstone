module stream_pcm(
    input logic clk,
    input logic rst_n,
    input logic ready_for_data,
    input logic [15:0] pcm_in,
    input logic pcm_valid,
    output logic [7:0] data_out,
    output logic data_valid
);

    logic [7:0] pcm_lower_buffer;
    logic read_lower, prev_valid;

    always_ff @( posedge clk, negedge rst_n ) begin
        if (!rst_n) begin
            prev_valid <= 1'b0;
        end else begin
            prev_valid <= pcm_valid;
        end
    end

    always_ff @( posedge clk, negedge rst_n ) begin
        if (!rst_n) begin
            pcm_lower_buffer <= '0;
        end else if (!read_lower) begin
            pcm_lower_buffer <= pcm_in[7:0];
        end
    end
    
    always_ff @( posedge clk, negedge rst_n ) begin : blockName
        if (!rst_n) begin
            data_out <= '0;
            data_valid <= 1'b0;
        end else if (ready_for_data) begin
            data_out <= read_lower ? pcm_lower_buffer : pcm_in[15:8]; // Output selected byte of PCM data as mock data
            data_valid <= read_lower ? prev_valid : pcm_valid; // Indicate that data is valid
        end else begin
            data_valid <= 1'b0; // Indicate that data is not valid when not ready
        end
    end

    always_ff @( posedge clk, negedge rst_n ) begin
        if (!rst_n) begin
            read_lower <= 1'b0;
        end else if (pcm_valid || prev_valid) begin
            read_lower <= ~read_lower; // Toggle between reading upper and lower byte on each valid PCM input
        end
    end

endmodule