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
    logic fifo_rden;
    logic fifo_wren;
    logic fifo_full;
    logic [DATA_WIDTH-1:0] fifo_out;

    logic [$clog2(WINDOW_SIZE) + DATA_WIDTH -1:0] current_sum;

    assign fifo_rden = fifo_full && data_valid;
    assign fifo_wren = data_valid;

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

    always_ff @( posedge clk, negedge rst_n ) begin
        if (!rst_n) begin
            current_sum <= '0;
        end else if (fifo_wren && !fifo_rden) begin
            current_sum <= current_sum + data_in;
        end else if (fifo_wren && fifo_rden) begin
            current_sum <= current_sum + data_in - fifo_out;
        end
    end

    assign mean_out = current_sum >> $clog2(WINDOW_SIZE);
    assign mean_valid = fifo_rden;
endmodule