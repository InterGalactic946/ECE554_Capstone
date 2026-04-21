module onchip_mem_pcm_tb();
    logic clk;
    logic rst_n;
    logic [9:0] data_from_ps, data_to_ps;
    logic [15:0] mock_data_1, mock_data_2, data_byte;
    logic data_valid_1, data_valid_2, ready_for_data, data_to_ps_valid, req_clk, enable_1, enable_2;
    shortint count = 5;

    wire [5:0] mem_addr;
    wire [127:0] mem_data;
    wire mem_write_en;
    wire mem_chip_select;
    wire [15:0] mem_byte_en;

    always #5 clk = ~clk;

    mock_data mock_data_inst_1 (
        .clk(clk),
        .rst_n(rst_n),
        .ready_for_data(enable_1),
        .data_out(mock_data_1),
        .data_valid(data_valid_1)
    );

    mock_data mock_data_inst_2 (
        .clk(clk),
        .rst_n(rst_n),
        .ready_for_data(enable_2),
        .data_out(mock_data_2),
        .data_valid(data_valid_2)
    );

    pcm_to_mem pcm_to_mem_inst (
        .clk(clk),
        .rst_n(rst_n),
        .pcm_pos_1(mock_data_1),
        .pcm_pos_2(mock_data_1),
        .pcm_neg_1(mock_data_2),
        .pcm_neg_2(mock_data_2),
        .pcm_pos_valid_1(data_valid_1),
        .pcm_pos_valid_2(data_valid_1),
        .pcm_neg_valid_1(data_valid_2),
        .pcm_neg_valid_2(data_valid_2),
        .mem_addr(mem_addr),
        .mem_data(mem_data),
        .mem_write_en(mem_write_en),
        .mem_chip_select(mem_chip_select),
        .mem_byte_en(mem_byte_en)
    );

    always begin
        enable_1 = 0;
        enable_2 = 0;
        repeat(5) @(posedge clk);
        enable_1 = 1;
        @(posedge clk);
        enable_1 = 0;
        enable_2 = 1;
        @(posedge clk);
    end

    task automatic reset_dut();
        begin
            rst_n = 0;
            req_clk = 0;
            @(posedge clk);
            rst_n = 1;
        end
    endtask
    
    initial begin
        clk = 0;
        reset_dut();
        repeat(10000) @(posedge clk);
        $stop();
    end
    
endmodule