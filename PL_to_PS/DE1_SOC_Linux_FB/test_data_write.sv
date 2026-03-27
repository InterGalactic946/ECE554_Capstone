module test_data_write (
    input logic clk,
    input logic rst_n,
    output logic [31:0] ram_data_in,
    output logic [31:0] ram_addr,
    output logic ram_write_en
);

    logic [2:0] cnt;
    logic done;

    always_ff @( posedge clk, negedge rst_n ) begin
        if ( !rst_n ) begin
            cnt <= 3'b0;
        end else if ( ~done ) begin
            cnt <= cnt + 1;
        end
    end

    assign done = &cnt;
    assign ram_write_en = ~done;

    always_comb begin
        ram_addr = {27'b0, cnt, 2'b0}; 
        ram_data_in = cnt + 1;
    end
    
endmodule