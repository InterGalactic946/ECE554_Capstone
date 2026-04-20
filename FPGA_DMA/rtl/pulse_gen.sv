module pulse_gen #(
    parameter int unsigned SYS_CLK_HZ = 50_000_000,
    parameter int unsigned PULSE_LENGTH_MS = 50,
    parameter int unsigned PULSE_GAP_MS = 200
) (
    input clk,
    input rst_n,
    input [1:0] freq_sel,
    output pulse
);

    localparam int unsigned FREQUENCY_0_HZ = 24_000;
    localparam int unsigned FREQUENCY_1_HZ = 30_000;
    localparam int unsigned FREQUENCY_2_HZ = 40_000;

    localparam int unsigned FREQUENCY_0_NUM_CLKS_FLIP = (SYS_CLK_HZ / FREQUENCY_0_HZ) / 2;
    localparam int unsigned FREQUENCY_1_NUM_CLKS_FLIP = (SYS_CLK_HZ / FREQUENCY_1_HZ) / 2;
    localparam int unsigned FREQUENCY_2_NUM_CLKS_FLIP = (SYS_CLK_HZ / FREQUENCY_2_HZ) / 2;

    localparam int unsigned SYS_CLK_PERIOD_NS = 1_000_000_000 / SYS_CLK_HZ;
    localparam int unsigned PULSE_LENGTH_NS = PULSE_LENGTH_MS * 1_000_000;
    localparam int unsigned PULSE_GAP_NS = PULSE_GAP_MS * 1_000_000;

    localparam int unsigned PULSE_LENGTH_NUM_CLKS = PULSE_LENGTH_NS / SYS_CLK_PERIOD_NS;
    localparam int unsigned PULSE_GAP_NUM_CLKS = PULSE_GAP_NS / SYS_CLK_PERIOD_NS;
    localparam int unsigned PULSE_CNT_W = $clog2(PULSE_GAP_NUM_CLKS + 1);

    logic freq_gen, freq_gen_flip;

    logic [11:0] clk_cnt;
    logic [PULSE_CNT_W-1:0] pulse_cnt;

    logic reset_pulse_cnt, pulsing; 

    typedef enum logic {GAP, PULSE} state_t;

    state_t state, nxt_state;

    assign pulse = pulsing ? freq_gen : 1'b0;

    always @(posedge clk, negedge rst_n) begin 
        if (!rst_n) 
            state <= GAP;
        else 
            state <= nxt_state;
    end

    always @(posedge clk, negedge rst_n) begin 
        if (!rst_n) 
            clk_cnt <= 0;
        else if (freq_gen_flip) 
            clk_cnt <= 0;
        else 
            clk_cnt <= clk_cnt + 1;
    end

    always @(posedge clk, negedge rst_n) begin 
        if (!rst_n) 
            pulse_cnt <= 0;
        else if (reset_pulse_cnt) 
            pulse_cnt <= 0;
        else 
            pulse_cnt <= pulse_cnt + 1;
    end

    always @(posedge clk, negedge rst_n) begin 
        if (!rst_n) 
            freq_gen <= 0;
        else if (freq_gen_flip) 
            freq_gen <= ~freq_gen;
    end

    always_comb begin 
        nxt_state = state;
        reset_pulse_cnt = 1'b0;
        pulsing = 1'b0;

        case(state)
            GAP: begin
                if (pulse_cnt == PULSE_GAP_NUM_CLKS) begin
                    nxt_state = PULSE;
                    reset_pulse_cnt = 1'b1;
                end
            end
            PULSE: begin
                pulsing = 1'b1;

                if (pulse_cnt == PULSE_LENGTH_NUM_CLKS) begin
                    nxt_state = GAP;
                    reset_pulse_cnt = 1'b1;
                end
            end
            default: begin
                nxt_state = GAP;
            end
        endcase
    end

    always_comb begin
        case(freq_sel) 
            2'b00: freq_gen_flip = (clk_cnt == FREQUENCY_0_NUM_CLKS_FLIP);
            2'b01: freq_gen_flip = (clk_cnt == FREQUENCY_1_NUM_CLKS_FLIP);
            2'b10: freq_gen_flip = (clk_cnt == FREQUENCY_2_NUM_CLKS_FLIP);
            default: freq_gen_flip = (clk_cnt == FREQUENCY_2_NUM_CLKS_FLIP);
        endcase
    end

endmodule