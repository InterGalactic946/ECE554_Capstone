module pl_to_ps (
    input logic clk,
    input logic rst_n,
    input logic [9:0] data_from_ps,
    input logic [15:0] input_data,
    input logic input_data_valid,
    output logic [9:0] data_to_ps,
    output logic ready_for_data,
    output logic ps_ready_for_data
);


    logic req_clk, flop_req_clk, flop_ps_ready, prev_req_clk, fifo_empty, fifo_full, active_req, prev_active_req, rd_upper_byte;

    logic [15:0] data_out;
    logic [7:0] lower_buf;

    assign data_to_ps[0] = ~fifo_empty || ~rd_upper_byte; // Indicate to PS that data is valid
    assign data_to_ps[1] = prev_req_clk; // Ack to PS that data read signal has been registered
    assign data_to_ps[9:2] = (rd_upper_byte) ? data_out[15:8] : lower_buf;

    assign ready_for_data = ~fifo_full;
    FIFO #(
        .DEPTH(512),
        .DATA_WIDTH(16)
    ) fifo_inst (
        .clk(clk),
        .rst_n(rst_n),
        .rden(active_req && rd_upper_byte),
        .wren(input_data_valid && ps_ready_for_data),
        .i_data(input_data),
        .o_data(data_out),
        .full(fifo_full),
        .empty(fifo_empty)
    );

    always_ff @( posedge clk, negedge rst_n ) begin
        if (!rst_n) begin
            req_clk <= 0;
            ps_ready_for_data <= 0;
            flop_req_clk <= 0;
            flop_ps_ready <= 0;
        end else begin
            flop_req_clk <= data_from_ps[0];
            req_clk <= flop_req_clk;
            flop_ps_ready <= data_from_ps[1];
            ps_ready_for_data <= flop_ps_ready;
        end
    end

    // always_ff @( posedge clk, negedge rst_n ) begin
    //     if (!rst_n) begin
    //         ram <= '{default: '0};
    //     end else if (active_req && ~fifo_empty) begin
    //     end else begin
    //         data_out <= '0; // Clear data when not valid or after being read
    //     end
    // end

    always_ff @( posedge clk ) begin
        prev_req_clk <= req_clk;
    end

    always_ff @( posedge clk, negedge rst_n ) begin
        if ( !rst_n ) begin
            active_req <= 1'b0;
        end else if (req_clk != prev_req_clk) begin
            active_req <= 1'b1;
        end else if (active_req && (~fifo_empty || ~rd_upper_byte)) begin
            active_req <= 1'b0;
        end
    end

    always_ff @( posedge clk, negedge rst_n ) begin
        if ( !rst_n ) begin
            prev_active_req <= 1'b0;
        end else begin
            prev_active_req <= active_req;
        end
    end

    always_ff @( posedge clk, negedge rst_n ) begin
        if ( !rst_n ) begin
            rd_upper_byte <= 1'b1;
        end else if (prev_active_req && ~active_req) begin
            rd_upper_byte <= ~rd_upper_byte; // Toggle between upper and lower byte on each read
        end
    end

    always_ff @( posedge clk ) begin
        if (rd_upper_byte) begin
            lower_buf <= data_out[7:0]; // Capture lower byte for next read
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