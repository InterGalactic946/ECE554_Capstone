module pdm_to_pcm_no_bp (
    input clk,
    input mic_clk,
    input [1:0] mic_mode,
    input rst_n,
    input mic_raw,
    output [15:0] pcm_pos,
    output pcm_valid_pos,
    output [15:0] pcm_neg,
    output pcm_valid_neg
);

    logic pdm_pos, pdm_neg;
    logic output_valid_pos, output_valid_neg;
    logic [1:0] data_in_pos, data_in_neg;
    logic [17:0] cic_out_pos, cic_out_neg;
    logic [17:0] comp_out_pos, comp_out_neg;

    logic mic_clk_delayed;
    logic output_valid_pos_delayed; 
    logic output_valid_neg_delayed;

    logic [7:0] clk_cnt;

    assign pcm_valid_pos = output_valid_pos & ~output_valid_pos_delayed;
    assign pcm_valid_neg = output_valid_neg & ~output_valid_neg_delayed;

    assign data_in_pos = pdm_pos ? 2'b01 : 2'b11;
    assign data_in_neg = pdm_neg ? 2'b01 : 2'b11;

    assign pcm_pos = comp_out_pos[17] ? (~&comp_out_pos[16:15] ? 16'h800 : comp_out_pos[15:0]) 
                                      : (|comp_out_pos[16:15] ? 16'h7FF : comp_out_pos[15:0]);

    assign pcm_neg = comp_out_neg[17] ? (~&comp_out_neg[16:15] ? 16'h800 : comp_out_neg[15:0]) 
                                      : (|comp_out_neg[16:15] ? 16'h7FF : comp_out_neg[15:0]);

    always @(posedge clk, negedge rst_n) begin
        if (!rst_n) begin
            pdm_pos <= 1'b0;
            pdm_neg <= 1'b0;
        end
        else begin
            if (mic_mode == 2'b10) begin
                if (clk_cnt == 6) begin
                    pdm_pos <= mic_raw; 
                end
                else if (clk_cnt == 16) begin
                    pdm_neg <= mic_raw; 
                end
            end
            else if (mic_mode == 2'b11) begin
                if (clk_cnt == 4) begin
                    pdm_pos <= mic_raw; 
                end
                else if (clk_cnt == 13) begin
                    pdm_neg <= mic_raw; 
                end
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

    cic_decimator #(.WIDTH(2), .RMAX(8), .M(2), .N(4)) iPOSMIC (
        .clk(mic_clk),
        .rst(~rst_n),
        .input_tdata(data_in_pos),
        .input_tvalid(1'b1),
        .input_tready(),
        .output_tdata(cic_out_pos),
        .output_tvalid(output_valid_pos),
        .output_tready(1'b1),
        .rate(4'b1000)
    );

    cic_decimator #(.WIDTH(2), .RMAX(8), .M(2), .N(4)) iNEGMIC (
        .clk(mic_clk),
        .rst(~rst_n),
        .input_tdata(data_in_neg),
        .input_tvalid(1'b1),
        .input_tready(),
        .output_tdata(cic_out_neg),
        .output_tvalid(output_valid_neg),
        .output_tready(1'b1),
        .rate(4'b1000)
    );

    fir_comp iPOSCOMP (
        .clk(mic_clk),
        .rst_n(rst_n),
        .in_valid(output_valid_pos),
        .in_data(cic_out_pos),
        .out_data(comp_out_pos)
    );

    fir_comp iNEGCOMP (
        .clk(mic_clk),
        .rst_n(rst_n),
        .in_valid(output_valid_neg),
        .in_data(cic_out_neg),
        .out_data(comp_out_neg)
    );

endmodule