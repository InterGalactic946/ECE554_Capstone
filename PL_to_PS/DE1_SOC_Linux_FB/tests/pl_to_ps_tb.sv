module pl_to_ps_tb();
    logic clk;
    logic rst_n;
    logic [9:0] data_from_ps, data_to_ps;
    logic [7:0] data_from_pl, data_byte;
    logic data_valid, ready_for_data, data_to_ps_valid, req_clk;
    integer count = 0;

    always #5 clk = ~clk;

    mock_data mock_data_inst (
        .clk(clk),
        .rst_n(rst_n),
        .ready_for_data(ready_for_data),
        .data_out(data_from_pl),
        .data_valid(data_valid)
    );

    pl_to_ps iDUT (
        .clk(clk),
        .rst_n(rst_n),
        .data_from_ps(data_from_ps),
        .input_data(data_from_pl),
        .input_data_valid(data_valid),
        .data_to_ps(data_to_ps),
        .ready_for_data(ready_for_data)
    );

    assign data_from_ps = {9'b0, req_clk};
    assign data_to_ps_valid = data_to_ps[0];
    assign ack_to_ps = data_to_ps[1];
    assign data_byte = data_to_ps[9:2];

    task automatic reset_dut();
        begin
            rst_n = 0;
            req_clk = 0;
            @(posedge clk);
            rst_n = 1;
        end
    endtask

    task automatic flip_req_clk(int num);
        begin
            req_clk = ~req_clk;
        end
    endtask

    task automatic ps_wait_for_ack(int num);
        fork
            begin: wait_for_ack
                wait (req_clk == ack_to_ps) ;
                $display("PS requested data, PL acknowledged, in exchange %0d.", num); 
                disable ack_timeout;
            end
            begin: ack_timeout
                repeat(20) @(posedge clk);
                $display("Timed out waiting for PL to acknowledge PS request in exchange %0d.", num);
                disable wait_for_ack;
                $stop;
            end
        join_any
        disable fork;
    endtask

    task automatic ps_wait_for_valid(int num);
        fork
            begin: wait_for_valid
                wait (data_to_ps_valid == 1);
                $display("Data is valid, PS can read now in exchange %0d.", num);
                disable valid_timeout;
            end
            begin: valid_timeout
                repeat(20) @(posedge clk);
                $display("Timed out waiting for valid data in exchange %0d.", num);
                disable wait_for_valid;
                $stop;
            end
        join_any
        disable fork;
    endtask

    task automatic assert_byte_expected(int num);
        if (data_byte == count) begin
            $display("Test passed: Received expected data byte 0x%02X from PL in exchange %0d.", count, num);
        end else begin
            $display("Test failed: Expected data byte 0x%02X, but received 0x%02X in exchange %0d.", count, data_byte, num);
            $stop;
        end
    endtask

    task automatic do_exchange(int num, int wait_time);
        wait (num == count);
        #(wait_time);
        flip_req_clk(num);
        ps_wait_for_ack(num);
        ps_wait_for_valid(num);
        assert_byte_expected(num);
        count++;
    endtask
    
    initial begin
        clk = 0;
        reset_dut();

        do_exchange(0, 1);
        do_exchange(1, 1);
        do_exchange(2, 100);

        $display("All tests passed!");
        $stop;


    end
    
endmodule