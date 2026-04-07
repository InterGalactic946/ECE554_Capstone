
module PCM_Top_tb();

    logic clk, rst_n, pdm_in_1, pdm_in_2;

    logic [1:0] mic_mode;

    logic [35:0] gpio;

    logic [7:0] sample_cnt0;
    logic [6:0] sample_cnt1;
    logic [5:0] sample_cnt2;
    logic [4:0] sample_cnt3;

    logic [255:0] sine_wave_data0; // 12 kHz
    logic [127:0] sine_wave_data1; // 24 kHz
    logic [63:0] sine_wave_data2;  // 48 kHz
    logic [31:0] sine_wave_data3;  // 96 kHz

    PCM_Top iDUT(

        //////////// ADC //////////
        .ADC_CONVST(),
        .ADC_DIN(),
        .ADC_DOUT(),
        .ADC_SCLK(),

        //////////// CLOCK //////////
        .CLOCK2_50(),
        .CLOCK3_50(),
        .CLOCK4_50(),
        .CLOCK_50(clk),

        //////////// SEG7 //////////
        .HEX0(),
        .HEX1(),
        .HEX2(),
        .HEX3(),
        .HEX4(),
        .HEX5(),

        //////////// KEY //////////
        .KEY({3'b111, rst_n}),

        //////////// LED //////////
        .LEDR(),

        //////////// SW //////////
        .SW({8'h00, mic_mode}),

        //////////// GPIO_0, GPIO_0 connect to GPIO Default //////////
        .GPIO(gpio)
    );

    assign gpio[2] = pdm_in_1;
    assign gpio[3] = pdm_in_2;

    initial begin
        sine_wave_data0 = 256'hAAD6EEEEF7F7FBFFFFFFFFFFFFFFFDFDEEEDB6B554A488840200001001024495; 
        sine_wave_data1 = 128'hAB77DFFFFFFF7DBAA92100000100892A; 
        sine_wave_data2 = 64'hADFFFF76A200020A; 
        sine_wave_data3 = 32'hB7FD9002; 
        clk = 1'b0;
        rst_n = 1'b0;

        @(posedge clk);
        @(posedge clk);
        @(negedge clk);
        rst_n = 1'b1;

        #100000;

        $stop();

    end

    always
        #5 clk = ~clk;

    always_ff @(posedge gpio[0], negedge rst_n) begin
        if (!rst_n) begin
            sample_cnt0 <= 0;
        end
        else begin
            sample_cnt0 <= sample_cnt0 + 1;
        end
    end

    always_ff @(posedge gpio[0], negedge rst_n) begin
        if (!rst_n) begin
            sample_cnt1 <= 0;
        end
        else begin
            sample_cnt1 <= sample_cnt1 + 1;
        end
    end

    always_ff @(posedge gpio[0], negedge rst_n) begin
        if (!rst_n) begin
            sample_cnt2 <= 0;
        end
        else begin
            sample_cnt2 <= sample_cnt2 + 1;
        end
    end

    always_ff @(posedge gpio[0], negedge rst_n) begin
        if (!rst_n) begin
            sample_cnt3 <= 0;
        end
        else begin
            sample_cnt3 <= sample_cnt3 + 1;
        end
    end

    always_ff @(posedge clk, negedge rst_n) begin
        if (!rst_n) begin
            pdm_in_1 <= 1'b0;
        end
        else begin
            pdm_in_1 <= sine_wave_data2[sample_cnt2];
        end
    end

    always_ff @(posedge clk, negedge rst_n) begin
        if (!rst_n) begin
            pdm_in_2 <= 1'b0;
        end
        else begin
            pdm_in_2 <= sine_wave_data1[sample_cnt1];
        end
    end


endmodule