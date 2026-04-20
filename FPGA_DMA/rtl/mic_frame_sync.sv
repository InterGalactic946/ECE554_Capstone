module mic_frame_sync #(
    parameter int M  = 4,
    parameter int DW = 16
) (
    input  logic                     clk,
    input  logic                     rst_n,

    input  logic [M-1:0]             mic_valid,
    input  logic signed [DW-1:0]     mic_pcm [M],

    output logic                     frame_sample_valid,
    output logic signed [DW-1:0]     frame_sample [M],
    output logic                     collect_sample
);

    typedef enum logic {
        COLLECT = 1'b0,
        EMIT    = 1'b1
    } state_t;

    state_t state, nxt_state;
    logic emit_frame;
    logic frame_complete;

    logic [M-1:0]                 got_sample;
    logic signed [DW-1:0]         sample_buf [M];

    // Frame is complete when every mic has either a collected sample or a valid sample this cycle.
    // got_sample is from a previous clock, while mic_valid is from the current clock.
    assign frame_complete = &(got_sample | mic_valid);

    genvar g;
    generate
        for (g = 0; g < M; g++) begin : GEN_SAMPLE_BUF_CAPTURE
            always_ff @(posedge clk, negedge rst_n) begin
                if (!rst_n)
                    sample_buf[g] <= '0;
                else if (collect_sample && mic_valid[g] && !got_sample[g])
                    sample_buf[g] <= mic_pcm[g];
            end
        end
    endgenerate

    generate
        for (g = 0; g < M; g++) begin : GEN_GOT_SAMPLE
            always_ff @(posedge clk, negedge rst_n) begin
                if (!rst_n)
                    got_sample[g] <= 1'b0;
                else if (emit_frame) // Clear got sample for next frame
                    got_sample[g] <= 1'b0;
                else if (collect_sample && mic_valid[g] && !got_sample[g])
                    got_sample[g] <= 1'b1;
            end
        end
    endgenerate

    always_ff @(posedge clk, negedge rst_n) begin
        if (!rst_n) begin
            frame_sample_valid <= 1'b0;
        end
        else if (emit_frame) begin
            frame_sample_valid <= 1'b1;
        end 
        else begin
            frame_sample_valid <= 1'b0;
        end
    end

    generate
        for (g = 0; g < M; g++) begin : GEN_FRAME_OUTPUT
            always_ff @(posedge clk, negedge rst_n) begin
                if (!rst_n)
                    frame_sample[g] <= '0;
                else if (emit_frame)
                    // Drive sample to final emit line
                    frame_sample[g] <= sample_buf[g];
            end
        end
    endgenerate

    always_ff @(posedge clk, negedge rst_n) begin
        if (!rst_n)
            state <= COLLECT;
        else
            state <= nxt_state;
    end

    always_comb begin
        // Default outputs
        nxt_state = state;
        collect_sample = 1'b0;
        emit_frame = 1'b0;

        case (state)
            COLLECT: begin
                collect_sample = 1'b1;
                if (frame_complete) begin
                    nxt_state = EMIT;
                end
            end

            EMIT: begin
                emit_frame = 1'b1;
                nxt_state = COLLECT;
            end

            default: begin
                nxt_state = COLLECT;
            end
        endcase
    end

    
endmodule