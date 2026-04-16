module pcm_cross_covariance #(
    parameter int N_MICS      = 4,
    parameter int SAMPLE_W    = 16,
    parameter int WINDOW_SIZE = 256,

    parameter int SUM_W       = SAMPLE_W + $clog2(WINDOW_SIZE) + 2,
    parameter int PROD_W      = 2*SAMPLE_W,
    parameter int ACC_W       = PROD_W + $clog2(WINDOW_SIZE) + 2,
    parameter int OUT_W       = ACC_W
)(
    input  logic clk,
    input  logic rst_n,

    input  logic valid_in,
    input  logic signed [SAMPLE_W-1:0] mic_samples [0:N_MICS-1],

    output logic valid_out,
    output logic signed [OUT_W-1:0] cov_mat [0:N_MICS-1][0:N_MICS-1]
);

    localparam int COUNT_W = $clog2(WINDOW_SIZE);

    logic [COUNT_W-1:0] sample_count;

    logic signed [SUM_W-1:0] sum_x [0:N_MICS-1];
    logic signed [ACC_W-1:0] sum_xx [0:N_MICS-1][0:N_MICS-1];

    integer i, j;

    logic signed [SUM_W-1:0] sx_i, sx_j;
    logic signed [PROD_W-1:0] prod_ij;
    logic signed [ACC_W-1:0] sxx_ij;

    logic signed [2*SUM_W-1:0] mean_corr_full;
    logic signed [ACC_W:0] numerator_full;
    logic signed [OUT_W-1:0] cov_tmp;

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            sample_count <= '0;
            valid_out    <= 1'b0;

            for (i = 0; i < N_MICS; i++) begin
                sum_x[i] <= '0;
                for (j = 0; j < N_MICS; j++) begin
                    sum_xx[i][j] <= '0;
                    cov_mat[i][j] <= '0;
                end
            end
        end else begin
            valid_out <= 1'b0;

            if (valid_in) begin
                if (sample_count == WINDOW_SIZE-1) begin
                    for (i = 0; i < N_MICS; i++) begin
                        for (j = 0; j < N_MICS; j++) begin
                            sx_i   = sum_x[i] + mic_samples[i];
                            sx_j   = sum_x[j] + mic_samples[j];
                            prod_ij = mic_samples[i] * mic_samples[j];
                            sxx_ij = sum_xx[i][j] + prod_ij;

                            mean_corr_full = (sx_i * sx_j) / WINDOW_SIZE;

                            numerator_full = sxx_ij - mean_corr_full;

                            cov_tmp = numerator_full / (WINDOW_SIZE - 1);

                            cov_mat[i][j] <= cov_tmp;
                        end
                    end

                    valid_out    <= 1'b1;
                    sample_count <= '0';

                    for (i = 0; i < N_MICS; i++) begin
                        sum_x[i] <= '0;
                        for (j = 0; j < N_MICS; j++) begin
                            sum_xx[i][j] <= '0;
                        end
                    end
                end else begin
                    for (i = 0; i < N_MICS; i++) begin
                        sum_x[i] <= sum_x[i] + mic_samples[i];
                    end

                    for (i = 0; i < N_MICS; i++) begin
                        for (j = 0; j < N_MICS; j++) begin
                            sum_xx[i][j] <= sum_xx[i][j] + (mic_samples[i] * mic_samples[j]);
                        end
                    end

                    sample_count <= sample_count + 1'b1;
                end
            end
        end
    end

endmodule