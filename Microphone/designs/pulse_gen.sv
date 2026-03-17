module pulse_gen #(
    parameter DIVISOR = 100
)(
    input  wire clk,
    input  wire rst_n,
    output reg  pulse
);
    reg [$clog2(DIVISOR)-1:0] count;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            count <= 0;
            pulse <= 0;
        end else if (count == DIVISOR - 1) begin
            count <= 0;
            pulse <= !pulse;
        end else begin
            count <= count + 1;
        end
    end

endmodule