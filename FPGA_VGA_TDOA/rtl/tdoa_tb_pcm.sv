module tdoa_tb_pcm();

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

// CSV column mapping:
//   P1 -> mic0 -> SE -> quadrant code 4
//   N1 -> mic1 -> SW -> quadrant code 3
//   P2 -> mic2 -> NW -> quadrant code 2
//   N2 -> mic3 -> NE -> quadrant code 1
localparam string CSV_FILE = "mic_data.csv";
localparam int NUM_EXPECTED = 3;
localparam int DRAIN_CYCLES = 20000;

int csv_fd;
int scan_count;
int sample_count;
int observed_count;
int p1_sample, p2_sample, n1_sample, n2_sample;
string header_line;
logic csv_done;

int expected_quadrant [0:NUM_EXPECTED-1] = '{3'd4, 3'd1, 3'd2};

always #5 clk = ~clk;

task automatic read_next_csv_sample();
    begin
        scan_count = $fscanf(csv_fd, "%d,%d,%d,%d\n", p1_sample, p2_sample, n1_sample, n2_sample);

        if (scan_count == 4) begin
            // File order is P1, P2, N1, N2. DUT order is SE, SW, NW, NE.
            mic_pcm_0 = p1_sample[15:0]; // P1 = SE
            mic_pcm_1 = n1_sample[15:0]; // N1 = SW
            mic_pcm_2 = p2_sample[15:0]; // P2 = NW
            mic_pcm_3 = n2_sample[15:0]; // N2 = NE
            sample_count = sample_count + 1;
        end else begin
            csv_done  = 1'b1;
            mic_valid = 4'b0000;
            mic_pcm_0 = 16'sd0;
            mic_pcm_1 = 16'sd0;
            mic_pcm_2 = 16'sd0;
            mic_pcm_3 = 16'sd0;
        end
    end
endtask

initial begin
    clk = 1'b0;
    rst_n = 1'b0;
    mic_valid = 4'b0000;
    csv_done = 1'b0;
    sample_count = 0;
    observed_count = 0;
    mic_pcm_0 = 16'sd0;
    mic_pcm_1 = 16'sd0;
    mic_pcm_2 = 16'sd0;
    mic_pcm_3 = 16'sd0;

    csv_fd = $fopen(CSV_FILE, "r");
    if (csv_fd == 0) begin
        $display("ERROR: Could not open %s. Make sure mic_data.csv is in the simulation run directory.", CSV_FILE);
        $stop();
    end

    // Skip header: P1,P2,N1,N2
    void'($fgets(header_line, csv_fd));

    repeat (5) @(negedge clk);
    rst_n = 1'b1;

    // Drive the first row before allowing mic_frame_sync to collect samples.
    @(negedge clk);
    read_next_csv_sample();
    mic_valid = 4'b1111;

    // Only advance to the next CSV row when mic_frame_sync is actually collecting.
    // This prevents the COLLECT/EMIT bubble from dropping every other row.
    while (!csv_done) begin
        @(negedge clk);
        if (collect_sample) begin
            read_next_csv_sample();
        end
    end

    // Let the DUT drain any detector/filter/classifier pipeline state.
    repeat (DRAIN_CYCLES) @(posedge clk);

    if (observed_count != NUM_EXPECTED) begin
        $display("FAILED: Expected %0d debounced quadrant outputs, observed %0d.", NUM_EXPECTED, observed_count);
    end else begin
        $display("YAHOO! All PCM-data quadrant tests passed.");
    end

    $fclose(csv_fd);
    $stop();
end

always_ff @(posedge clk, negedge rst_n) begin
    if (!rst_n) begin
        observed_count <= 0;
    end else if (quadrant_valid) begin
        if (observed_count < NUM_EXPECTED) begin
            if (quadrant_code == expected_quadrant[observed_count]) begin
                $display("Quadrant %0d detected correctly at PCM sample %0d.", quadrant_code, sample_count);
            end else begin
                $display("FAILED: Expected quadrant %0d, detected quadrant %0d at PCM sample %0d.",
                         expected_quadrant[observed_count], quadrant_code, sample_count);
                $stop();
            end
        end else begin
            $display("FAILED: Extra quadrant output %0d at PCM sample %0d.", quadrant_code, sample_count);
            $stop();
        end

        observed_count <= observed_count + 1;
    end
end

// Safety timeout in case the DUT never produces the expected quadrant_valid pulses.
initial begin
    #30000000;
    $display("FAILED: Simulation timeout. Read %0d PCM rows and observed %0d quadrant outputs.", sample_count, observed_count);
    $stop();
end

endmodule
