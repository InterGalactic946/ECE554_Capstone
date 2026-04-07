module fir_comp (
    input clk,
    input rst_n,
    input in_valid,
    input [17:0] in_data,
    output [17:0] out_data
);

    logic signed [17:0] buffer [0:10];
    logic [29:0] out_data_int;

    integer i;

    always @(posedge clk, negedge rst_n) begin
        if (!rst_n) begin
            for (i = 0; i < 11; i = i + 1) begin
                buffer[i] <= 18'h00000;
            end
        end
        else if (in_valid) begin
            buffer[0] <= in_data; 
            for (i = 0; i < 10; i = i + 1) begin
                buffer[i + 1] <= buffer[i];
            end
        end
    end

    assign out_data_int = ( (buffer[0] * 8'sd2) + (buffer[1] * 8'sd3) + (buffer[2] * -8'sd19) + 
                        (buffer[3] * -8'sd32) + (buffer[4] * 8'sd53) + (buffer[5] * 8'sd127) + 
                        (buffer[6] * 8'sd53) + (buffer[7] * -8'sd32) + (buffer[8] * -8'sd19) + 
                        (buffer[9] * 8'sd3) + (buffer[10] * 8'sd2) ) / 30'sd141;

    assign out_data = out_data_int[17:0];

endmodule