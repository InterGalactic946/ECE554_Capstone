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
    .collect_sample(collect_sample)
);

logic [9:0] pulse_gen_count;

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

    if (pulse_gen_count == 10'd50 || pulse_gen_count == 10'd51) begin
        mic_pcm_0 = 16'sd6000;
    end

    if (pulse_gen_count == 10'd150 || pulse_gen_count == 10'd151) begin
        mic_pcm_1 = 16'sd6000;
    end

    if (pulse_gen_count == 10'd350 || pulse_gen_count == 10'd351) begin
        mic_pcm_2 = 16'sd6000;
    end

    if (pulse_gen_count == 10'd145 || pulse_gen_count == 10'd146) begin
        mic_pcm_3  = 16'sd6000;
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