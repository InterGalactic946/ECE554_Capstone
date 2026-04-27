module tdoa_tb();

logic clk, rst_n;
logic [3:0] mic_valid;
logic signed [15:0] mic_pcm_0, mic_pcm_1, mic_pcm_2, mic_pcm_3;

logic quadrant_valid;
logic [2:0] quadrant_code;
logic collect_sample;

tdoa iDUT(
    .clk(clk),
    .rst_n(rst_n),
    .mic_valid(mic_valid),
    .mic_pcm_0(mic_pcm_0),
    .mic_pcm_1(mic_pcm_1),
    .mic_pcm_2(mic_pcm_2),
    .mic_pcm_3(mic_pcm_3),

    .quadrant_valid(quadrant_valid),
    .quadrant_code(quadrant_code),
    .collect_sample(collect_sample),
    .hit_time1(),
    .hit_time2(),
    .hit_time3(),
    .hit_time4(),
    .threshold_valid(),
    .event_done(),
    .sta_mean_1(),
    .sta_mean_2(),
    .sta_mean_3(),
    .sta_mean_4(),
    .lta_mean_1(),
    .lta_mean_2(),
    .lta_mean_3(),
    .lta_mean_4(),
    .sta_valid_1(),
    .sta_valid_2(),
    .sta_valid_3(),
    .sta_valid_4(),
    .lta_valid_1(),
    .lta_valid_2(),
    .lta_valid_3(),
    .lta_valid_4()
);

logic [15:0] pulse_gen_count;
logic pulse_high;

always_ff @(posedge clk, negedge rst_n) begin
    if (!rst_n)
        pulse_gen_count <= '0;
    else
        pulse_gen_count <= pulse_gen_count + 1'b1;
end


always_comb begin
    mic_pcm_0 = 16'sd0;
    mic_pcm_1 = 16'sd0;
    mic_pcm_2 = 16'sd0;
    mic_pcm_3 = 16'sd0;
    pulse_high = 1'b0;

    if (pulse_high == 0) begin
            if (pulse_gen_count % 2 == 0) begin
                mic_pcm_0 = 16'sd10;
                mic_pcm_1 = 16'sd10;
                mic_pcm_2 = 16'sd10;
                mic_pcm_3 = 16'sd10;
            end
            else if (pulse_gen_count % 2 == 1) begin
                mic_pcm_0 = -16'sd10;
                mic_pcm_1 = -16'sd10;
                mic_pcm_2 = -16'sd10;
                mic_pcm_3 = -16'sd10;
            end
    end

    if (pulse_gen_count == 16'd3550 || pulse_gen_count == 16'd3551 || // Event 1
        pulse_gen_count == 16'd4550 || pulse_gen_count == 16'd4551 || // Event 2
        pulse_gen_count == 16'd5550 || pulse_gen_count == 16'd5551) begin // Event 3
        mic_pcm_0 = 16'sd6000;
        pulse_high = 1'b1;
    end

    if (pulse_gen_count == 16'd3650 || pulse_gen_count == 16'd3651 ||
        pulse_gen_count == 16'd4650 || pulse_gen_count == 16'd4651 ||
        pulse_gen_count == 16'd5650 || pulse_gen_count == 16'd5651) begin
        mic_pcm_1 = 16'sd6000;
        pulse_high = 1'b1;
    end

    if (pulse_gen_count == 16'd3850 || pulse_gen_count == 16'd3851 ||
        pulse_gen_count == 16'd4850 || pulse_gen_count == 16'd4851 ||
        pulse_gen_count == 16'd5850 || pulse_gen_count == 16'd5851) begin
        mic_pcm_2 = 16'sd6000;
        pulse_high = 1'b1;
    end

    if (pulse_gen_count == 16'd3640 || pulse_gen_count == 16'd3641 ||
        pulse_gen_count == 16'd4640 || pulse_gen_count == 16'd4641 ||
        pulse_gen_count == 16'd5640 || pulse_gen_count == 16'd5641) begin
        mic_pcm_3 = 16'sd6000;
        pulse_high = 1'b1;
    end
end

initial begin
    clk = 1'b0;
    rst_n = 1'b0;
    mic_valid = 4'b0000;
    @(negedge clk) begin
        rst_n = 1'b1;
        mic_valid = 4'b1111;
    end

    @(posedge quadrant_valid);
    if (quadrant_code == 3'd4)
        $display("Quadrant SE detected correctly.");
    else
        $display("Quadrant SE detection failed. Detected code: %b", quadrant_code);

    $stop();
end

always #5 clk = ~clk;


endmodule