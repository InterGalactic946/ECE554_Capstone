module PCM_no_comp_tb ();

logic clk, mic_clk, rst_n, mic_raw, pcm_valid_pos, pcm_valid_neg;
logic [1:0] dec_mode;
logic [15:0] pcm_pos, pcm_neg;

logic [2:0] clk_cnt;

PCM_no_comp iDUT (
    .clk(clk),
    .mic_clk(mic_clk),
    .rst_n(rst_n),
    .mic_raw(mic_raw),
    .dec_mode(dec_mode),           // 0: 12kHz PCM fs,  1: 48kHz PCM fs,  2: 192 kHz PCM fs
    .pcm_pos(pcm_pos),
    .pcm_valid_pos(pcm_valid_pos),
    .pcm_neg(pcm_neg),
    .pcm_valid_neg(pcm_valid_neg)
);

initial begin
    clk = 1'b0;
	mic_clk = 1'b0;
    rst_n = 1'b0;
    mic_raw = 1'b0;
	clk_cnt = 3'b000;
	@(negedge mic_clk);
	@(negedge mic_clk);
    
    rst_n = 1'b1;

    dec_mode = 2'b00;
    repeat(12000) begin
        @(posedge clk);
    end

    dec_mode = 2'b01;
    repeat(4000) begin
        @(posedge clk);
    end

    dec_mode = 2'b10;
    repeat(1000) begin
        @(posedge clk);
    end
	
	$stop();
end

always 
    #5 clk = ~clk;

always @(posedge clk) begin
    if (clk_cnt == 3'b111) 
        mic_clk <= ~mic_clk;
end

always @(posedge clk) begin
        begin
            clk_cnt <= clk_cnt + 1;
        end
    end 

endmodule