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


    //////////////////////////////////////////////////
    // Helper
    //////////////////////////////////////////////////
    function automatic logic [DW-1:0] abs_s(input logic signed [DW-1:0] v);
        begin
            if (v < 0)
                abs_s = -v;
            else
                abs_s = v;
        end
    endfunction

    typedef enum logic {
        IDLE    = 1'b0, // Waiting for mic threshold crossing
        CAPTURE = 1'b1  // Capture the time 
    } state_t;

    state_t state, nxt_state;

    // localparam int CAPW = (CAPTURE_WINDOW > 1) ? $clog2(CAPTURE_WINDOW) : 1;

    logic capturing;
    logic pulse_event_done;
    logic latch_new_hits;

    //////////////////////////////////////////////////
    // Per-channel threshold checks
    //////////////////////////////////////////////////
    logic [DW-1:0] abs_sample [4];
    logic [3:0]    above_threshold;
    logic [3:0]    already_hit;
    logic [3:0]    new_hits;
    logic          any_above;

    assign abs_sample[0] = abs_s(frame_sample[0]);
    assign abs_sample[1] = abs_s(frame_sample[1]);
    assign abs_sample[2] = abs_s(frame_sample[2]);
    assign abs_sample[3] = abs_s(frame_sample[3]);

    wavefront_detection det0 (
        .clk(clk),
        .rst_n(rst_n),
        .data_in(abs_sample[0]),
        .data_valid(sample_valid),
        .detection_out(above_threshold[0]),
        .sta_mean(sta_mean[0]),
        .lta_mean(lta_mean[0]),
        .sta_valid(sta_valid[0]),
        .lta_valid(lta_valid[0])
    );

    wavefront_detection det1 (
        .clk(clk),
        .rst_n(rst_n),
        .data_in(abs_sample[1]),
        .data_valid(sample_valid),
        .detection_out(above_threshold[1]),
        .sta_mean(sta_mean[1]),
        .lta_mean(lta_mean[1]),
        .sta_valid(sta_valid[1]),
        .lta_valid(lta_valid[1])
    );

    wavefront_detection det2 (
        .clk(clk),
        .rst_n(rst_n),
        .data_in(abs_sample[2]),
        .data_valid(sample_valid),
        .detection_out(above_threshold[2]),
        .sta_mean(sta_mean[2]),
        .lta_mean(lta_mean[2]),
        .sta_valid(sta_valid[2]),
        .lta_valid(lta_valid[2])
    );

    wavefront_detection det3 (
        .clk(clk),
        .rst_n(rst_n),
        .data_in(abs_sample[3]),
        .data_valid(sample_valid),
        .detection_out(above_threshold[3]),
        .sta_mean(sta_mean[3]),
        .lta_mean(lta_mean[3]),
        .sta_valid(sta_valid[3]),
        .lta_valid(lta_valid[3])
    );

    logic det_pipe_valid;
    logic detect_valid;

    // If logic breaks, check this logic first
    // This assumes that all microphone lines and their means are synchoronized
    assign det_pipe_valid = sta_valid[0] & lta_valid[0];

    always_ff @(posedge clk, negedge rst_n) begin
        if (!rst_n)
            detect_valid <= 1'b0;
        else
            detect_valid <= det_pipe_valid;
    end

    // assign above_threshold[0] = (abs_sample[0] >= THRESHOLD);
    // assign above_threshold[1] = (abs_sample[1] >= THRESHOLD);
    // assign above_threshold[2] = (abs_sample[2] >= THRESHOLD);
    // assign above_threshold[3] = (abs_sample[3] >= THRESHOLD);

    assign any_above = |above_threshold;

    assign threshold_valid = already_hit;

    // New hits are when we are above the threshold, but haven't already hit it
    // already_hit goes high for a microphone after its first capture.
    assign new_hits[3:0] = above_threshold[3:0] & ~already_hit[3:0];

    // Logic for the "capture window" after the first threshold crossing
    logic capture_done;
    // logic [CAPW-1:0] capture_cnt;

    // always_ff @(posedge clk, negedge rst_n) begin
    //     if (!rst_n)
    //         capture_cnt <= '0;
    //     else if (begin_capture)
    //         capture_cnt <= '0;
    //     else if (capturing)
    //         capture_cnt <= capture_cnt + 1;
    // end

    // assign capture_done = (capture_cnt == CAPTURE_WINDOW - 1);
    assign capture_done = &sample_time; 

    // One cycle delay to event valid to synchronize with capturing of data
    always_ff @(posedge clk, negedge rst_n) begin
        if (!rst_n)
            event_done <= 1'b0;
        else if (pulse_event_done)
            event_done <= 1'b1;
        else
            event_done <= 1'b0;
    end

    // Indicator that we have already captured for a mic threshold
    always_ff @(posedge clk, negedge rst_n) begin
        if (!rst_n)
            already_hit[3:0] <= 4'b0000;
        else if (begin_capture)
            already_hit[3:0] <= above_threshold[3:0];
        else if (latch_new_hits)
            // When getting a new hit that we want to capture, we 
            // want to mark that the one that is above the threshold is the one we are hitting
            already_hit[3:0] <= already_hit[3:0] | above_threshold[3:0];
    end

    // Capture hit time flops
    genvar g_time;
    generate
        for (g_time = 0; g_time < 4; g_time++) begin : GEN_HIT_TIME_CAPTURE
            always_ff @(posedge clk, negedge rst_n) begin
                if (!rst_n)
                    hit_time[g_time] <= '0;
                else if (begin_capture) begin
                    hit_time[g_time] <= '0;
                end else if (latch_new_hits && new_hits[g_time]) begin
                    hit_time[g_time] <= sample_time;
                end
            end
        end
    endgenerate

    always_ff @(posedge clk, negedge rst_n) begin
        if (!rst_n)
            state <= IDLE;
        else
            state <= nxt_state;
    end

    always_comb begin
        nxt_state = state;
        begin_capture = 1'b0;
        capturing = 1'b0;
        pulse_event_done = 1'b0;
        latch_new_hits = 1'b0;

        case (state)
            IDLE : begin
                if (any_above && detect_valid) begin
                    begin_capture = 1'b1;
                    nxt_state = CAPTURE;
                end
            end

            CAPTURE : begin
                if (detect_valid) begin
                    capturing = 1'b1;

                    if (|new_hits)
                        latch_new_hits = 1'b1;

                    if (&(already_hit | above_threshold) || capture_done) begin
                        pulse_event_done = 1'b1;
                        nxt_state = IDLE;
                    end
                end
            end

            default : begin
                nxt_state = IDLE;
            end
        endcase
    end


endmodule

