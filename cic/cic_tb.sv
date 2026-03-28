`timescale 1ps/1ps

module cic_tb();

    logic [1:0] in_error, out_error;
    logic clk, reset_n, in_valid, in_ready, in_data, out_valid, out_ready;
    logic [15:0] out_data;

    logic [3:0] sample_cnt;
    logic in_data_ff;

    assign in_data = sample_cnt[3]; 
    assign in_valid = (in_data_ff != in_data);

 
    cic iDUT (
        .in_error(in_error),  //  av_st_in.error
        .in_valid(in_valid),  //          .valid
        .in_ready(in_ready),  //          .ready
        .in_data(in_data),   //          .in_data
        .out_data(out_data),  // av_st_out.out_data
        .out_error(out_error), //          .error
        .out_valid(out_valid), //          .valid
        .out_ready(out_ready), //          .ready
        .clk(clk),       //     clock.clk
        .reset_n(reset_n)    //     reset.reset_n
        );

    initial begin
        clk = 1'b0;
        reset_n = 1'b0;
        out_ready = 1'b1;
        in_error = 2'b00; 

        @(posedge clk);
        @(posedge clk);
        @(negedge clk);
        reset_n = 1'b0;

    end

    always
        #5 clk = ~clk;

    always_ff @(posedge clk, negedge reset_n) begin
        if (!reset_n) begin
            sample_cnt <= 0;
        end
        else begin
            sample_cnt <= sample_cnt + 1;
        end
    end

    always_ff @(posedge clk, negedge reset_n) begin
        if (!reset_n) begin
            in_data_ff <= 0;
        end
        else begin
            in_data_ff <= in_data;
        end
    end


endmodule