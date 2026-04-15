module mock_data(
    input logic clk,
    input logic rst_n,
    input logic ready_for_data,
    output logic [15:0] data_out,
    output logic data_valid
);

    logic [15:0] data_counter;

    assign data_out = data_counter[15:0]; // Use upper bits of counter as mock data

    always_ff @( posedge clk, negedge rst_n ) begin
        if ( !rst_n ) begin
            data_counter <= '0;
        end else if (ready_for_data) begin
            data_counter <= data_counter + 1; // Increment counter to generate new data
        end
    end

    always_ff @( posedge clk, negedge rst_n ) begin
        if ( !rst_n ) begin
            data_valid <= 0;
        end else begin
            data_valid <= ready_for_data; // Valid when counter is at specific values
        end
    end
    
    // assign data_valid = ~|data_counter[2:1] && data_counter[0];
endmodule