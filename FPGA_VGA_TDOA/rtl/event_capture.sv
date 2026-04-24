module event_capture #(
    parameter int DW             = 16,
    parameter int TSW            = 16,
    parameter int THRESHOLD      = 4,
    // parameter int CAPTURE_WINDOW = 200,
    parameter int NUM_MICS       = 4,
    parameter int unsigned STA_LEN = 16,
    parameter int unsigned LTA_LEN = 1024
) (
    input  logic                         clk,
    input  logic                         rst_n,

    input  logic                         sample_valid,
    input  logic signed [DW-1:0]         frame_sample [4],
    input  logic [TSW-1:0]               sample_time, // Generated from custom clock

    output logic [3:0]                   threshold_valid,
    output logic [TSW-1:0]               hit_time [4],
    output logic                         event_done,
    output logic                         begin_capture,
    output logic [15:0]                  sta_mean [4],
    output logic [15:0]                  lta_mean [4],
    output logic                         sta_valid [4],
    output logic                         lta_valid [4]
);

    logic [3:0] det_out;
    localparam int MIC_THRESHOLD [4] = '{16'd3000, 16'd3000, 16'd3000, 16'd3000};

    // Instantiate the 4 detectors
    genvar i;
    generate
        for (i = 0; i < 4; i++) begin : GEN_WAVEFRONT
            wavefront_detection #(
                .STA_LEN(STA_LEN),
                .LTA_LEN(LTA_LEN),
                .THRESHOLD(THRESHOLD),
                .MIC_THRESHOLD(MIC_THRESHOLD[i])
            ) det_inst (
                .clk(clk),
                .rst_n(rst_n),
                .data_in(frame_sample[i]),
                .data_valid(sample_valid),
                .detection_out(det_out[i]),
                .sta_mean(sta_mean[i]),
                .lta_mean(lta_mean[i]),
                .sta_valid(sta_valid[i]),
                .lta_valid(lta_valid[i])
            );
        end
    endgenerate

    assign threshold_valid = det_out;

    // --- State Machine ---
    typedef enum logic {IDLE, CAPTURE} state_t;
    state_t state, nxt_state;

    logic [3:0] hit_mask, nxt_hit_mask;
    logic [15:0] timeout_ctr, nxt_timeout_ctr;

    always_ff @(posedge clk, negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            hit_mask <= '0;
            timeout_ctr <= '0;
        end else begin
            state <= nxt_state;
            hit_mask <= nxt_hit_mask;
            timeout_ctr <= nxt_timeout_ctr;
        end
    end

    // --- Hit Time Latching Logic ---
    always_ff @(posedge clk, negedge rst_n) begin
        if (!rst_n) begin
            hit_time[0] <= '0; hit_time[1] <= '0; hit_time[2] <= '0; hit_time[3] <= '0;
        end else begin
            if (state == IDLE && (|det_out)) begin
                // The exact cycle the FIRST mic(s) hit. 
                // We hardcode 0 because the external timer is 1 cycle behind on clearing.
                for (int j = 0; j < 4; j++) begin
                    if (det_out[j]) hit_time[j] <= '0;
                end
            end else if (state == CAPTURE) begin
                // For subsequent mics, grab the external timer only on the FIRST cycle they go high
                for (int j = 0; j < 4; j++) begin
                    if (det_out[j] && !hit_mask[j]) hit_time[j] <= sample_time;
                end
            end
        end
    end

    // --- Next State Logic ---
    always_comb begin
        nxt_state = state;
        nxt_hit_mask = hit_mask;
        nxt_timeout_ctr = timeout_ctr;

        begin_capture = 1'b0;
        event_done = 1'b0;

        case (state)
            IDLE: begin
                if (|det_out) begin
                    begin_capture = 1'b1;     // Pulse high to clear external sample timer
                    nxt_hit_mask = det_out;   // Record which mic(s) triggered
                    nxt_timeout_ctr = '0;
                    nxt_state = CAPTURE;
                end
            end

            CAPTURE: begin
                // Continuously track which mics have crossed the threshold
                nxt_hit_mask = hit_mask | det_out;

                // Increment timeout counter every new audio sample
                if (sample_valid) begin
                    nxt_timeout_ctr = timeout_ctr + 1'b1;
                end

                // Condition 1: All 4 mics have successfully triggered
                if (&nxt_hit_mask) begin
                    event_done = 1'b1;       // Tell top level we have valid TDOA data!
                    nxt_hit_mask = '0;       // Clear mask
                    nxt_state = IDLE;        // Go back to waiting
                end
                // Condition 2: Not all mics triggered, and we ran out of time
                else if (&sample_time) begin
                    nxt_hit_mask = '0;       // Clear mask
                    nxt_state = IDLE;        // Abort silently (event_done stays 0)
                end
            end
        endcase
    end

endmodule

