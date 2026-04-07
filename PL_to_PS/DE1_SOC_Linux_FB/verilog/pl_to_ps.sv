module pl_to_ps (
    input logic clk,
    input logic rst_n,
    input logic [9:0] data_from_ps,
    input logic [7:0] input_data,
    input logic input_data_valid,
    output logic [9:0] data_to_ps,
    output logic ready_for_data
);


    logic req_clk, prev_req_clk, fifo_empty, fifo_full, active_req;

    logic [7:0] data_out;

    assign req_clk = data_from_ps[0];

    assign data_to_ps[0] = ~fifo_empty; // Indicate to PS that data is valid
    assign data_to_ps[1] = prev_req_clk; // Ack to PS that data read signal has been registered
    assign data_to_ps[9:2] = data_out;

    assign ready_for_data = ~fifo_full;

    FIFO #(
        .DEPTH(32),
        .DATA_WIDTH(8)
    ) fifo_inst (
        .clk(clk),
        .rst_n(rst_n),
        .rden(active_req),
        .wren(input_data_valid),
        .i_data(input_data),
        .o_data(data_out),
        .full(fifo_full),
        .empty(fifo_empty)
    );

    always_ff @( posedge clk ) begin
        prev_req_clk <= req_clk;
    end

    always_ff @( posedge clk, negedge rst_n ) begin
        if ( !rst_n ) begin
            active_req <= 1'b0;
        end else if (req_clk != prev_req_clk) begin
            active_req <= 1'b1;
        end else if (active_req && ~fifo_empty) begin
            active_req <= 1'b0;
        end
        
    end

    // always_ff @( posedge clk, negedge rst_n ) begin
    //     if ( !rst_n ) begin
    //         data_out <= '1;
    //     end else if (data_read && input_data_valid) begin
    //         data_out <= input_data;
    //     end
    // end

    // always_ff @( posedge clk, negedge rst_n ) begin
    //     if ( !rst_n ) begin
    //         data_valid <= 1'b0;
    //     end else begin
    //         data_valid <= input_data_valid;
    //     end
        
    // end
endmodule