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
    output logic collect_sample,
    output logic [15:0] hit_time1,
    output logic [15:0] hit_time2,
    output logic [15:0] hit_time3,
    output logic [15:0] hit_time4,
    output logic [3:0]    threshold_valid,
    output logic event_done,
    output logic [15:0] sta_mean_1,
    output logic [15:0] sta_mean_2,
    output logic [15:0] sta_mean_3,
    output logic [15:0] sta_mean_4,
    output logic [15:0] lta_mean_1,
    output logic [15:0] lta_mean_2,
    output logic [15:0] lta_mean_3,
    output logic [15:0] lta_mean_4,
    output logic sta_valid_1,
    output logic sta_valid_2,
    output logic sta_valid_3,
    output logic sta_valid_4,
    output logic lta_valid_1,
    output logic lta_valid_2,
    output logic lta_valid_3,
    output logic lta_valid_4
);

    localparam TSW = 16;
    localparam DW = 16;
    
    logic [TSW-1:0] hit_time [4];
    logic frame_sample_valid;
    logic signed [TSW-1:0] frame_sample [4];
    logic [TSW-1:0] sample_time;
    logic first_threshold_crossed;
    logic [15:0] sta_mean [4];
    logic [15:0] lta_mean [4];
    logic        sta_valid [4];
    logic        lta_valid [4];

    logic signed [15:0] mic_pcm [4];
    assign mic_pcm[0] = mic_pcm_0;
    assign mic_pcm[1] = mic_pcm_1;
    assign mic_pcm[2] = mic_pcm_2;
    assign mic_pcm[3] = mic_pcm_3;

    assign hit_time1 = hit_time[0];
    assign hit_time2 = hit_time[1];
    assign hit_time3 = hit_time[2];
    assign hit_time4 = hit_time[3];

    assign sta_mean_1 = sta_mean[0];
    assign sta_mean_2 = sta_mean[1];
    assign sta_mean_3 = sta_mean[2];
    assign sta_mean_4 = sta_mean[3];

    assign lta_mean_1 = lta_mean[0];
    assign lta_mean_2 = lta_mean[1];
    assign lta_mean_3 = lta_mean[2];
    assign lta_mean_4 = lta_mean[3];

    assign sta_valid_1 = sta_valid[0];
    assign sta_valid_2 = sta_valid[1];
    assign sta_valid_3 = sta_valid[2];
    assign sta_valid_4 = sta_valid[3];

    assign lta_valid_1 = lta_valid[0];
    assign lta_valid_2 = lta_valid[1];
    assign lta_valid_3 = lta_valid[2];
    assign lta_valid_4 = lta_valid[3];

    mic_frame_sync #(
        .M(4),
        .DW(DW)
    ) u_sync (
        .clk(clk),
        .rst_n(rst_n),
        .mic_valid(mic_valid),
        .mic_pcm(mic_pcm),
        .frame_sample_valid(frame_sample_valid),
        .frame_sample(frame_sample),
        .collect_sample(collect_sample)
    );

    sample_time_gen #(
        .TSW(TSW)
    ) u_time (
        .clk(clk),
        .rst_n(rst_n),
        .sample_tick(frame_sample_valid), // Increment time on each valid sample from frame sync
        .clr_time(first_threshold_crossed),
        .sample_time(sample_time)
    );

    event_capture # (
        .DW(DW),
        .TSW(TSW),
        .STA_LEN(32),
        .LTA_LEN(1024),
        .THRESHOLD(4)
    ) u_event (
        .clk(clk),
        .rst_n(rst_n),
        .sample_valid(frame_sample_valid),
        .frame_sample(frame_sample),
        .sample_time(sample_time),
        .threshold_valid(threshold_valid),
        .hit_time(hit_time),
        .event_done(event_done),
        .begin_capture(first_threshold_crossed),
        .sta_mean(sta_mean),
        .lta_mean(lta_mean),
        .sta_valid(sta_valid),
        .lta_valid(lta_valid)
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