
module cic_plus_comp_tb();

    logic clk, rst_n, in_valid, in_ready, pdm_in, out_valid, out_ready;
    logic [1:0] in_data;
    logic [17:0] out_data;
    logic [3:0] rate;
    logic [17:0] out_data_comp;

    logic [7:0] sample_cnt0;
    logic [6:0] sample_cnt1;
    logic [5:0] sample_cnt2;
    logic [4:0] sample_cnt3;

    logic [255:0] sine_wave_data0; // 12 kHz
    logic [127:0] sine_wave_data1; // 24 kHz
    logic [63:0] sine_wave_data2;  // 48 kHz
    logic [31:0] sine_wave_data3;  // 96 kHz

    assign in_data = pdm_in ? 2'b01 : 2'b11;

    cic_decimator #(.WIDTH(2), .RMAX(8), .M(2), .N(4)) iDUT (
        .clk(clk),
        .rst(~rst_n),
        .input_tdata(in_data),
        .input_tvalid(in_valid),
        .input_tready(in_ready),
        .output_tdata(out_data),
        .output_tvalid(out_valid),
        .output_tready(out_ready),
        .rate(rate)
    );

    fir_comp iDUT2 (
        .clk(clk),
        .rst_n(rst_n),
        .in_valid(out_valid),
        .in_data(out_data),
        .out_data(out_data_comp)
    );

    initial begin
        sine_wave_data0 = 256'hAAD6EEEEF7F7FBFFFFFFFFFFFFFFFDFDEEEDB6B554A488840200001001024495; 
        sine_wave_data1 = 128'hAB77DFFFFFFF7DBAA92100000100892A; 
        sine_wave_data2 = 64'hADFFFF76A200020A; 
        sine_wave_data3 = 32'hB7FD9002; 
        rate = 4'b1000;
        clk = 1'b0;
        rst_n = 1'b0;
        out_ready = 1'b1;
        in_valid = 1'b1;

        @(posedge clk);
        @(posedge clk);
        @(negedge clk);
        rst_n = 1'b1;

        #10000;

        $stop();

    end

    always
        #5 clk = ~clk;

    always_ff @(posedge clk, negedge rst_n) begin
        if (!rst_n) begin
            sample_cnt0 <= 0;
        end
        else begin
            sample_cnt0 <= sample_cnt0 + 1;
        end
    end

    always_ff @(posedge clk, negedge rst_n) begin
        if (!rst_n) begin
            sample_cnt1 <= 0;
        end
        else begin
            sample_cnt1 <= sample_cnt1 + 1;
        end
    end

    always_ff @(posedge clk, negedge rst_n) begin
        if (!rst_n) begin
            sample_cnt2 <= 0;
        end
        else begin
            sample_cnt2 <= sample_cnt2 + 1;
        end
    end

    always_ff @(posedge clk, negedge rst_n) begin
        if (!rst_n) begin
            sample_cnt3 <= 0;
        end
        else begin
            sample_cnt3 <= sample_cnt3 + 1;
        end
    end

    always_ff @(posedge clk, negedge rst_n) begin
        if (!rst_n) begin
            pdm_in <= 1'b0;
        end
        else begin
            pdm_in <= sine_wave_data2[sample_cnt2];
        end
    end


endmodule