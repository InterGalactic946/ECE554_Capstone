module window_mean 
# (
    parameter int unsigned WINDOW_SIZE = 64
)
(
    input logic clk,
    input logic rst_n,
    input logic [15:0] data_in,
    input logic data_valid,
    output logic [15:0] mean_out,
    output logic mean_valid
);

    localparam DATA_WIDTH = 16;
    logic fifo_rden, prev_fifo_rden;
    logic fifo_wren, prev_fifo_wren;
    logic fifo_full;
    logic [15:0] prev_data_in;
    logic [DATA_WIDTH-1:0] fifo_out;

    logic [$clog2(WINDOW_SIZE) + DATA_WIDTH -1:0] current_sum;

    assign fifo_rden = fifo_full && data_valid;
    assign fifo_wren = data_valid;

    always_ff @(posedge clk, negedge rst_n) begin
        if (!rst_n) begin
            prev_fifo_rden <= 0;
            prev_fifo_wren <= 0;
            prev_data_in <= 0;
        end else begin
            prev_fifo_rden <= fifo_rden;
            prev_fifo_wren <= fifo_wren;
            prev_data_in <= data_in;
        end
    end

    My_FIFO #(
        .DEPTH(WINDOW_SIZE),
        .DATA_WIDTH(DATA_WIDTH)
    ) fifo (
        .clk(clk),
        .rst_n(rst_n),
        .rden(fifo_rden),
        .wren(fifo_wren),
        .i_data(data_in),
        .o_data(fifo_out),
        .full(fifo_full),
        .empty()
    );

    /*
    generate
        if (WINDOW_SIZE == 8) begin
            FIFO_8 fifo_8 (
                .clock(clk),
                .data(data_in),
                .rdreq(fifo_rden),
                .wrreq(fifo_wren),
                .q(fifo_out),
                .full(fifo_full)
            );
        end else if (WINDOW_SIZE == 16) begin
            FIFO_16 fifo_16 (
                .clock(clk),
                .data(data_in),
                .rdreq(fifo_rden),
                .wrreq(fifo_wren),
                .q(fifo_out),
                .full(fifo_full)
            );
        end else if (WINDOW_SIZE == 32) begin
            FIFO_32 fifo_32 (
                .clock(clk),
                .data(data_in),
                .rdreq(fifo_rden),
                .wrreq(fifo_wren),
                .q(fifo_out),
                .full(fifo_full)
            );
        end else if (WINDOW_SIZE == 64) begin
            FIFO_64 fifo_64 (
                .clock(clk),
                .data(data_in),
                .rdreq(fifo_rden),
                .wrreq(fifo_wren),
                .q(fifo_out),
                .full(fifo_full)
            );
        end else if (WINDOW_SIZE == 128) begin
            FIFO_128 fifo_128 (
                .clock(clk),
                .data(data_in),
                .rdreq(fifo_rden),
                .wrreq(fifo_wren),
                .q(fifo_out),
                .full(fifo_full)
            );
        end else if (WINDOW_SIZE == 256) begin
            FIFO_256 fifo_256 (
                .clock(clk),
                .data(data_in),
                .rdreq(fifo_rden),
                .wrreq(fifo_wren),
                .q(fifo_out),
                .full(fifo_full)
            );
        end else if (WINDOW_SIZE == 512) begin
            FIFO_512 fifo_512 (
                .clock(clk),
                .data(data_in),
                .rdreq(fifo_rden),
                .wrreq(fifo_wren),
                .q(fifo_out),
                .full(fifo_full)
            );
        end else if (WINDOW_SIZE == 1024) begin
                FIFO_1024 fifo_1024 (
                    .clock(clk),
                    .data(data_in),
                    .rdreq(fifo_rden),
                    .wrreq(fifo_wren),
                    .q(fifo_out),
                    .full(fifo_full)
                );
        end else if (WINDOW_SIZE == 2048) begin
            FIFO_2048 fifo_2048 (
                .clock(clk),
                .data(data_in),
                .rdreq(fifo_rden),
                .wrreq(fifo_wren),
                .q(fifo_out),
                .full(fifo_full)
            );
        end else begin
            initial begin
                $error("Unsupported WINDOW_SIZE: %0d. Supported sizes powers of 2 from 8 to 2048.", WINDOW_SIZE);
            end
        end
    endgenerate
    */

    always_ff @( posedge clk, negedge rst_n ) begin
        if (!rst_n) begin
            current_sum <= '0;
        end else if (fifo_wren && !fifo_rden) begin
            current_sum <= current_sum + data_in;
        end else if (prev_fifo_wren && prev_fifo_rden) begin
            current_sum <= current_sum + prev_data_in - fifo_out;
        end
    end

    assign mean_out = current_sum >> $clog2(WINDOW_SIZE);
    assign mean_valid = prev_fifo_rden;
endmodule