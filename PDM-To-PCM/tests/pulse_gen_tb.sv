`timescale 1ns/1ps

module pulse_gen_tb();

    logic clk, rst_n, pulse;
    logic [1:0] freq_sel;

    pulse_gen #(.PULSE_LENGTH_MS(1), .PULSE_GAP_MS(5)) iDUT (
        .clk(clk),
        .rst_n(rst_n),
        .freq_sel(freq_sel),
        .pulse(pulse)
    );

    initial begin
        rst_n = 1'b0;
        clk = 1'b0;
        freq_sel = 2'b10; // 40kHz

        @(negedge clk)
        @(negedge clk)
        rst_n = 1'b1; 

        repeat (2) begin
            @(negedge iDUT.pulsing);
        end

        freq_sel = 2'b01; // 30 kHz

        repeat (2) begin
            @(negedge iDUT.pulsing);
        end

        freq_sel = 2'b00; // 24 kHz

        repeat (2) begin
            @(negedge iDUT.pulsing);
        end

        freq_sel = 2'b11; // Test defualt case: 40 kHz

        repeat (2) begin
            @(negedge iDUT.pulsing);
        end

        $stop();
    end

    always
        #10 clk = ~clk;

endmodule