module loc_classifier #(
    parameter int TSW      = 32,
    parameter int OUT_Q    = 15,
    parameter int CONST_Q  = 30,

    // K_Q30 = round((343 / (2 * 50_000_000 * 0.2345)) * 2^30)
    parameter logic signed [31:0] K_Q30 = 32'sd15705
) (
    input  logic                         clk,
    input  logic                         rst_n,

    input  logic                         event_done,
    input  logic [TSW-1:0]               hit_time [4],

    output logic                         loc_valid,
    output logic signed [15:0]           x_proj_q15,
    output logic signed [15:0]           y_proj_q15
);

    // Mic order:
    // hit_time[0] = SE / Bottom-Right
    // hit_time[1] = SW / Bottom-Left
    // hit_time[2] = NW / Top-Left
    // hit_time[3] = NE / Top-Right

    localparam int SUMW = TSW + 1;
    localparam int DTW  = TSW + 2;
    localparam int MULW = DTW + 32;

    logic [SUMW-1:0] left_sum;
    logic [SUMW-1:0] right_sum;
    logic [SUMW-1:0] top_sum;
    logic [SUMW-1:0] bottom_sum;

    logic signed [DTW-1:0]  dx_cycles;
    logic signed [DTW-1:0]  dy_cycles;

    logic signed [DTW-1:0]  x_cycles_flipped;

    logic signed [MULW-1:0] x_prod_q30;
    logic signed [MULW-1:0] y_prod_q30;

    logic signed [MULW-1:0] x_scaled_q15_full;
    logic signed [MULW-1:0] y_scaled_q15_full;

    //////////////////////////////////////////////////
    // Saturate wide signed value to signed Q1.15
    //////////////////////////////////////////////////
    function automatic logic signed [15:0] sat_q15(
        input logic signed [MULW-1:0] value
    );
        begin
            if (value > $signed({{(MULW-16){1'b0}}, 16'sh7FFF}))
                sat_q15 = 16'sh7FFF;
            else if (value < $signed({{(MULW-16){1'b1}}, 16'sh8000}))
                sat_q15 = 16'sh8000;
            else
                sat_q15 = value[15:0];
        end
    endfunction

    //////////////////////////////////////////////////
    // Side sums
    //////////////////////////////////////////////////
    always_comb begin
        // left  = NW + SW
        // right = NE + SE
        left_sum   = {1'b0, hit_time[2]} + {1'b0, hit_time[1]};
        right_sum  = {1'b0, hit_time[3]} + {1'b0, hit_time[0]};

        // top    = NW + NE
        // bottom = SW + SE
        top_sum    = {1'b0, hit_time[2]} + {1'b0, hit_time[3]};
        bottom_sum = {1'b0, hit_time[1]} + {1'b0, hit_time[0]};

        dx_cycles = $signed({1'b0, left_sum})   - $signed({1'b0, right_sum});
        dy_cycles = $signed({1'b0, bottom_sum}) - $signed({1'b0, top_sum});

        // Match the C++ x-axis flip:
        // loc.x_proj = -loc.x_proj;
        x_cycles_flipped = -dx_cycles;

        x_prod_q30 = $signed(x_cycles_flipped) * $signed(K_Q30);
        y_prod_q30 = $signed(dy_cycles)        * $signed(K_Q30);

        x_scaled_q15_full = $signed(x_prod_q30) >>> (CONST_Q - OUT_Q);
        y_scaled_q15_full = $signed(y_prod_q30) >>> (CONST_Q - OUT_Q);
    end

    //////////////////////////////////////////////////
    // Register outputs on event_done
    //////////////////////////////////////////////////
    always_ff @(posedge clk, negedge rst_n) begin
        if (!rst_n) begin
            loc_valid <= 1'b0;
            x_proj_q15  <= 16'sd0;
            y_proj_q15  <= 16'sd0;
        end else if (event_done) begin
            x_proj_q15  <= sat_q15(x_scaled_q15_full);
            y_proj_q15  <= sat_q15(y_scaled_q15_full);
            loc_valid <= 1'b1;
        end else begin
            loc_valid <= 1'b0;
        end
    end

endmodule