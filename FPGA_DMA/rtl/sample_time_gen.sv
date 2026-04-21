module sample_time_gen #(
    parameter int TSW = 32
) (
    input  logic             clk,
    input  logic             rst_n,
    input  logic             sample_tick,   // connect to frame_sample_valid
    input  logic             clr_time,      // optional clear
    output logic [TSW-1:0]   sample_time
);

    always_ff @(posedge clk, negedge rst_n) begin
        if (!rst_n)
            sample_time <= '0;
        else if (clr_time)
            sample_time <= '0;
        else
            sample_time <= sample_time + 1'b1;
    end

endmodule