module lcmv_score #(
	parameter int N_MICS    = 4,
    parameter int WEIGHT_W  = 16,
    parameter int COV_W     = 32,

    // Real-valued beamformer weights for one candidate location
    parameter logic signed [WEIGHT_W-1:0] WEIGHTS [0:N_MICS-1] = '{
        16'sd1, 16'sd2, 16'sd3, 16'sd4
    },

    parameter int TERM_W  = COV_W + 2*WEIGHT_W,
    parameter int SCORE_W = TERM_W + $clog2(N_MICS*N_MICS)
)(
	input logic clk,
	input logic rst_n,

	input logic valid_in,
	input  logic signed [COV_W-1:0] cov_mat [0:N_MICS-1][0:N_MICS-1],

    output logic valid_out,
    output logic signed [SCORE_W-1:0] spatial_score
);

	logic [SCORE_W-1:0] next_score;

	integer i, j;
	logic signed [TERM_W-1:0] mult_term;


	always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            valid_out      <= 1'b0;
            spatial_score  <= '0;
        end else begin
            valid_out <= valid_in;

            if (valid_in) begin
                spatial_score <= next_score;
            end
        end
    end

	always_comb begin
        score_next = '0;

        for (i = 0; i < N_MICS; i++) begin
            for (j = 0; j < N_MICS; j++) begin
                mult_term = WEIGHTS[i] * cov_mat[i][j] * WEIGHTS[j];
                score_next = next_score + $signed(mult_term);
            end
        end
    end

endmodule
