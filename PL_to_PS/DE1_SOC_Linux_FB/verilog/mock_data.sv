module mock_data(
    input logic clk,
    input logic rst_n,
    input logic ready_for_data,
    output logic [7:0] data_out,
    output logic data_valid
);

    logic [9:0] data_counter;

    assign data_out = data_counter[9:2]; // Use upper bits of counter as mock data

    always_ff @( posedge clk, negedge rst_n ) begin
        if ( !rst_n ) begin
            data_counter <= '0;
        end else if (ready_for_data) begin
            data_counter <= data_counter + 1; // Increment counter to generate new data
        end
    end

    assign data_valid = ~|data_counter[1:0];
endmodule