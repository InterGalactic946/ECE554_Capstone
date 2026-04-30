module data_to_ps
# (
    parameter int unsigned BUF_WIDTH = 64
) (
    input logic clk,
    input logic rst_n,
    input logic [9:0] data_from_ps,
    input logic [BUF_WIDTH-1:0] input_data,
    input logic input_data_valid,
    output logic [9:0] data_to_ps,
    output logic ready_for_data,
    output logic ps_ready_for_data
);


    logic req_clk, flop_req_clk, flop_ps_ready, prev_req_clk, active_req, out_valid, reg_valid;

    logic [BUF_WIDTH-1:0] shift_reg;
    logic [7:0] data_out;
    logic [$clog2(BUF_WIDTH/8):0] bytes_sent;

    assign data_to_ps[0] = out_valid; // Indicate to PS that data is valid
    assign data_to_ps[1] = prev_req_clk; // Ack to PS that data read signal has been registered
    assign data_to_ps[9:2] = data_out;

    assign ready_for_data = ~reg_valid;

    always_ff @( posedge clk, negedge rst_n ) begin
        if (!rst_n) begin
            shift_reg <= '0;
            data_out <= '0;
        end else if (input_data_valid && !reg_valid) begin
            shift_reg <= input_data;
        end else if (active_req && reg_valid) begin
            data_out <= shift_reg[7:0]; // Output the least significant byte
            shift_reg <= shift_reg >> 8; // Shift out the next byte
        end
    end

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

    always_ff @( posedge clk ) begin
        prev_req_clk <= req_clk;
    end

    always_ff @( posedge clk, negedge rst_n ) begin
        if ( !rst_n ) begin
            active_req <= 1'b0;
        end else if (req_clk != prev_req_clk) begin
            active_req <= 1'b1;
        end else if (active_req && reg_valid) begin
            active_req <= 1'b0;
        end
    end 

    always_ff @( posedge clk, negedge rst_n ) begin
        if ( !rst_n ) begin
            reg_valid <= 1'b0;
        end else if (input_data_valid) begin
            reg_valid <= 1'b1;
        end else if (bytes_sent == (BUF_WIDTH/8)) begin
            reg_valid <= 1'b0; // Clear valid after data has been read
        end
    end

    always_ff @( posedge clk, negedge rst_n ) begin
        if ( !rst_n ) begin
            out_valid <= 1'b0;
        end else if (active_req && reg_valid) begin
            out_valid <= 1'b1;
        end else if (active_req && !reg_valid) begin
            out_valid <= 1'b0;
        end
    end

    always_ff @( posedge clk, negedge rst_n ) begin
        if ( !rst_n ) begin
            bytes_sent <= 0;
        end else if (bytes_sent == (BUF_WIDTH/8)) begin
            bytes_sent <= 0; // Reset byte counter after all bytes have been sent
        end else if (active_req && reg_valid) begin
           bytes_sent <= bytes_sent + 1;
        end 
    end
endmodule