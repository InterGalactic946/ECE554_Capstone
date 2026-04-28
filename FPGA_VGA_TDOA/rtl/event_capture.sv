module event_capture #(
    parameter int DW             = 16,
    parameter int TSW            = 16,
    parameter int THRESHOLD      = 4,
    // parameter int CAPTURE_WINDOW = 200,
    parameter int NUM_MICS       = 4,
    parameter int unsigned STA_LEN = 16,
    parameter int unsigned LTA_LEN = 1024,
    parameter int unsigned PULSE_GAP_MS = 200
) (
    input  logic                         clk,
    input  logic                         rst_n,

    input  logic                         sample_valid,
    input  logic signed [DW-1:0]         frame_sample [4],
    input  logic [TSW-1:0]               sample_time, // Generated from custom clock
    input  logic                         audible,

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
    logic [DW-1:0] abs_sample [4];
    logic capturing;
    logic start_cooldown;
    logic [15:0] cooldown_samples;

    localparam int MIC_THRESHOLD [4] = '{16'd3000, 16'd3000, 16'd3000, 16'd3000};
    localparam int MIC_ZERO_THRESHOLD [4] = '{16'd200, 16'd200, 16'd200, 16'd200};

    localparam int QUIET_SAMPLES_FOR_COOLDOWN_192 = (PULSE_GAP_MS / 10) * 192;
    localparam int QUIET_SAMPLES_FOR_COOLDOWN_48 = (PULSE_GAP_MS / 10) * 48;

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

    assign cooldown_samples = audible ? QUIET_SAMPLES_FOR_COOLDOWN_48 : QUIET_SAMPLES_FOR_COOLDOWN_192;

    assign abs_sample[0] = abs_s(frame_sample[0]);
    assign abs_sample[1] = abs_s(frame_sample[1]);
    assign abs_sample[2] = abs_s(frame_sample[2]);
    assign abs_sample[3] = abs_s(frame_sample[3]);

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
                .data_in(abs_sample[i]),
                .data_valid(sample_valid),
                .detection_out(det_out[i]),
                .sta_mean(sta_mean[i]),
                .lta_mean(lta_mean[i]),
                .sta_valid(sta_valid[i]),
                .lta_valid(lta_valid[i])
            );
        end
    endgenerate

    // --- State Machine ---
    typedef enum logic {IDLE, CAPTURE} state_t;
    state_t state, nxt_state;

    logic [3:0] hit_mask, nxt_hit_mask;
    logic [15:0] timeout_ctr;

    assign threshold_valid = hit_mask;

    always_ff @(posedge clk, negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            hit_mask <= '0;
        end else begin
            state <= nxt_state;
            hit_mask <= nxt_hit_mask;
        end
    end

    always_ff @(posedge clk, negedge rst_n) begin
        if (!rst_n) begin
            timeout_ctr <= '0;
        end else if (begin_capture) begin
            timeout_ctr <= '0;
        end else if (capturing && sample_valid) begin
            timeout_ctr <= timeout_ctr + 1'b1;
        end
    end

    logic all_quiet;
    assign all_quiet = (abs_sample[0] < MIC_ZERO_THRESHOLD[0]) &&
                       (abs_sample[1] < MIC_ZERO_THRESHOLD[1]) &&
                       (abs_sample[2] < MIC_ZERO_THRESHOLD[2]) &&
                       (abs_sample[3] < MIC_ZERO_THRESHOLD[3]);

    // Cooldown counter in between valid events to prevent multiple captures of the same event
    logic [15:0] cooldown_ctr;
    always_ff @(posedge clk, negedge rst_n) begin
        if (!rst_n) begin
            cooldown_ctr <= '0;
        end else if (start_cooldown) begin
            cooldown_ctr <= cooldown_samples;
        end else if (cooldown_ctr != 0) begin 
            // Only when the cooldown counter has began (all 4 crossed threshold) do we care about checking if det_out is all 0
            if (!all_quiet)
                cooldown_ctr <= cooldown_samples;
            else if (sample_valid)
                cooldown_ctr <= cooldown_ctr - 1'b1;
        end
    end

    // --- Hit Time Latching Logic ---
    logic [3:0] latch_new_hit;

    // Only latch if there is a new hit this cycle
    assign latch_new_hit = det_out & ~hit_mask;

    genvar g_time;
    generate
        for (g_time = 0; g_time < 4; g_time++) begin : GEN_HIT_TIME_CAPTURE
            always_ff @(posedge clk, negedge rst_n) begin
                if (!rst_n)
                    hit_time[g_time] <= '0;
                else if (begin_capture) begin
                    hit_time[g_time] <= '0;
                end else if (capturing) begin
                    if (latch_new_hit[g_time]) begin
                        hit_time[g_time] <= sample_time;
                    end
                end
            end
        end
    endgenerate

    // --- Next State Logic ---
    always_comb begin
        nxt_state = state;
        nxt_hit_mask = hit_mask;

        begin_capture = 1'b0;
        event_done = 1'b0;
        capturing = 1'b0;
        start_cooldown = 1'b0;

        case (state)
            IDLE: begin
                if (|det_out && (cooldown_ctr == 0)) begin
                    begin_capture = 1'b1;     // Pulse high to clear external sample timer
                    nxt_hit_mask = det_out;   // Record which mic(s) triggered
                    nxt_state = CAPTURE;
                end
            end

            CAPTURE: begin
                // Continuously track which mics have crossed the threshold
                nxt_hit_mask = hit_mask | det_out;
                capturing = 1'b1;

                // Condition 1: All 4 mics have successfully triggered
                if (&hit_mask) begin         // Trigger on hit_mask so the last hit_time is latched on the same cycle as event_done
                    event_done = 1'b1;       // Tell top level we have valid TDOA data!
                    start_cooldown = 1'b1;    // Start cooldown for next event
                    nxt_hit_mask = '0;       // Clear mask
                    nxt_state = IDLE;        // Go back to waiting
                end
                // Condition 2: Not all mics triggered, and we ran out of time
                else if (&timeout_ctr) begin
                    nxt_hit_mask = '0;       // Clear mask
                    start_cooldown = 1'b1;    // Start cooldown for next event (even though this one is invalid, we still want to prevent immediate re-triggering)
                    nxt_state = IDLE;        // Abort silently (event_done stays 0)
                end
            end
        endcase
    end

endmodule
