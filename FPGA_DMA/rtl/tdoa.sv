module tdoa(
    input logic clk,
    input logic rst_n,
    input logic [3:0] mic_valid,
    input logic signed [15:0] mic_pcm_0,
    input logic signed [15:0] mic_pcm_1,
    input logic signed [15:0] mic_pcm_2,
    input logic signed [15:0] mic_pcm_3,

    output logic quadrant_valid,
    output logic [2:0] quadrant_code,
    output logic collect_sample
);

    localparam TSW = 16;
    logic frame_sample_valid;
    logic event_done;
    logic signed [15:0] frame_sample [4];
    logic [31:0] sample_time;
    logic [3:0] threshold_valid;
    logic [31:0] hit_time [4];
    logic first_threshold_crossed;

    logic signed [15:0] mic_pcm [4];
    assign mic_pcm[0] = mic_pcm_0;
    assign mic_pcm[1] = mic_pcm_1;
    assign mic_pcm[2] = mic_pcm_2;
    assign mic_pcm[3] = mic_pcm_3;

    mic_frame_sync
    #(
        .M(4),
        .DW(16)
    ) u_sync (
        .clk(clk),
        .rst_n(rst_n),
        .mic_valid(mic_valid),
        .mic_pcm(mic_pcm),
        .frame_sample_valid(frame_sample_valid),
        .frame_sample(frame_sample),
        .collect_sample(collect_sample)
    );

    sample_time_gen
    #(
        .TSW(TSW)
    )
     u_time (
        .clk(clk),
        .rst_n(rst_n),
        .sample_tick(frame_sample_valid), // Increment time on each valid sample from frame sync
        .clr_time(first_threshold_crossed),
        .sample_time(sample_time)
    );

    event_capture 
    # (
        .DW(16),
        .TSW(TSW),
        .STA_LEN(16),
        .LTA_LEN(1024),
        .THRESHOLD(4)
    )
    u_event (
        .clk(clk),
        .rst_n(rst_n),
        .sample_valid(frame_sample_valid),
        .frame_sample(frame_sample),
        .sample_time(sample_time),
        .threshold_valid(threshold_valid),
        .hit_time(hit_time),
        .event_done(event_done),
        .begin_capture(first_threshold_crossed)
    );

    quadrant_classifier #(
        .TSW(TSW)
    ) u_quadrant (
        .clk(clk),
        .rst_n(rst_n),
        .event_done(event_done),
        .threshold_valid(threshold_valid),
        .hit_time(hit_time),
        .quadrant_valid(quadrant_valid),
        .quadrant_code(quadrant_code)
    );

endmodule