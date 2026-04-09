module PCM_no_comp (
    input clk,
    input mic_clk,
    input rst_n,
    input mic_raw,
    input [1:0] dec_mode,           // 0: 12kHz PCM fs,  1: 48kHz PCM fs,  2: 192 kHz PCM fs
    output logic [15:0] pcm_pos,
    output pcm_valid_pos,
    output logic [15:0] pcm_neg,
    output pcm_valid_neg
);

    logic pdm_pos, pdm_neg;
    logic output_valid_pos, output_valid_neg;
    logic output_valid_pos12, output_valid_neg12;
    logic output_valid_pos48, output_valid_neg48;
    logic output_valid_pos192, output_valid_neg192;
    logic [1:0] data_in_pos, data_in_neg;
    logic [25:0] cic_out_pos12, cic_out_neg12;
    logic [19:0] cic_out_pos48, cic_out_neg48;
    logic [17:0] cic_out_pos192, cic_out_neg192;

    logic mic_clk_delayed;
    logic output_valid_pos_delayed; 
    logic output_valid_neg_delayed;

    logic [7:0] clk_cnt;

    assign pcm_valid_pos = output_valid_pos & ~output_valid_pos_delayed;
    assign pcm_valid_neg = output_valid_neg & ~output_valid_neg_delayed;

    assign data_in_pos = pdm_pos ? 2'b01 : 2'b11;
    assign data_in_neg = pdm_neg ? 2'b01 : 2'b11;

    always_comb begin
        case(dec_mode)
            2'b00: begin
                output_valid_pos = output_valid_pos12;
                output_valid_neg = output_valid_neg12;
                pcm_pos = cic_out_pos12[25:10];
                pcm_neg = cic_out_neg12[25:10];
            end
            2'b01: begin
                output_valid_pos = output_valid_pos48;
                output_valid_neg = output_valid_neg48;
                pcm_pos = cic_out_pos48[19:4];
                pcm_neg = cic_out_neg48[19:4];
            end
            2'b10: begin
                output_valid_pos = output_valid_pos192;
                output_valid_neg = output_valid_neg192;
                pcm_pos = cic_out_pos192[17:2];
                pcm_neg = cic_out_neg192[17:2];
            end
            default: begin
                output_valid_pos = output_valid_pos48;
                output_valid_neg = output_valid_neg48;
                pcm_pos = cic_out_pos48[19:4];
                pcm_neg = cic_out_neg48[19:4];
            end
        endcase
    end

    always @(posedge clk, negedge rst_n) begin
        if (!rst_n) begin
            pdm_pos <= 1'b0;
            pdm_neg <= 1'b0;
        end
        else begin
            if (clk_cnt == 4) begin
                pdm_pos <= mic_raw; 
            end
            else if (clk_cnt == 12) begin
                pdm_neg <= mic_raw; 
            end
        end
    end

    always @(posedge clk, negedge rst_n) begin
        if (!rst_n) begin
            clk_cnt <= 1'b0;
        end
        else begin
            if (mic_clk && !mic_clk_delayed) begin
                clk_cnt <= 1'b0;
            end 
            else begin 
                clk_cnt <= clk_cnt + 1;
            end 
        end
    end 

    always @(posedge clk, negedge rst_n) begin
        if (!rst_n) begin
            mic_clk_delayed <= 1'b0;
        end
        else begin
            mic_clk_delayed <= mic_clk;
        end
    end 

    always @(posedge clk, negedge rst_n) begin
        if (!rst_n) begin
            output_valid_pos_delayed <= 1'b0;
        end
        else begin
            output_valid_pos_delayed <= output_valid_pos;
        end
    end 

    always @(posedge clk, negedge rst_n) begin
        if (!rst_n) begin
            output_valid_neg_delayed <= 1'b0;
        end
        else begin
            output_valid_neg_delayed <= output_valid_neg;
        end
    end 

    // 12 kHz PCM
    cic_decimator #(.WIDTH(2), .RMAX(256), .M(1), .N(3)) iPOSMIC12 (
        .clk(mic_clk),
        .rst(~rst_n),
        .input_tdata(data_in_pos),
        .input_tvalid(1'b1),
        .input_tready(),
        .output_tdata(cic_out_pos12),
        .output_tvalid(output_valid_pos12),
        .output_tready(1'b1),
        .rate(9'b100000000)
    );

    cic_decimator #(.WIDTH(2), .RMAX(256), .M(1), .N(3)) iNEGMIC12 (
        .clk(mic_clk),
        .rst(~rst_n),
        .input_tdata(data_in_neg),
        .input_tvalid(1'b1),
        .input_tready(),
        .output_tdata(cic_out_neg12),
        .output_tvalid(output_valid_neg12),
        .output_tready(1'b1),
        .rate(9'b100000000)
    );

    // 48 kHz PCM
    cic_decimator #(.WIDTH(2), .RMAX(64), .M(1), .N(3)) iPOSMIC48 (
        .clk(mic_clk),
        .rst(~rst_n),
        .input_tdata(data_in_pos),
        .input_tvalid(1'b1),
        .input_tready(),
        .output_tdata(cic_out_pos48),
        .output_tvalid(output_valid_pos48),
        .output_tready(1'b1),
        .rate(7'b1000000)
    );

    cic_decimator #(.WIDTH(2), .RMAX(64), .M(1), .N(3)) iNEGMIC48 (
        .clk(mic_clk),
        .rst(~rst_n),
        .input_tdata(data_in_neg),
        .input_tvalid(1'b1),
        .input_tready(),
        .output_tdata(cic_out_neg48),
        .output_tvalid(output_valid_neg48),
        .output_tready(1'b1),
        .rate(7'b1000000)
    );

    // 192 kHz PCM
    cic_decimator #(.WIDTH(2), .RMAX(16), .M(1), .N(4)) iPOSMIC192 (
        .clk(mic_clk),
        .rst(~rst_n),
        .input_tdata(data_in_pos),
        .input_tvalid(1'b1),
        .input_tready(),
        .output_tdata(cic_out_pos192),
        .output_tvalid(output_valid_pos192),
        .output_tready(1'b1),
        .rate(5'b10000)
    );

    cic_decimator #(.WIDTH(2), .RMAX(16), .M(1), .N(4)) iNEGMIC192 (
        .clk(mic_clk),
        .rst(~rst_n),
        .input_tdata(data_in_neg),
        .input_tvalid(1'b1),
        .input_tready(),
        .output_tdata(cic_out_neg192),
        .output_tvalid(output_valid_neg192),
        .output_tready(1'b1),
        .rate(5'b10000)
    );

endmodule