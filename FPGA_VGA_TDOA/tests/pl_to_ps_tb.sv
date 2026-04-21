module pl_to_ps_tb();
    logic clk;
    logic rst_n;
    logic [9:0] data_from_ps, data_to_ps;
    logic [15:0] data_from_pl, data_byte;
    logic data_valid, ready_for_data, data_to_ps_valid, req_clk, ps_ready_for_data;
    shortint count = 5;

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

    assign data_from_ps = {8'b0, ps_ready_for_data, req_clk};
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

    task automatic expect_upper_byte(int num);
        if (data_byte == count[15:8]) begin
            $display("Test passed: Received upper byte 0x%02X from PL in exchange %0d.", count[15:8], num);
        end else begin
            $display("Test failed: Expected upper byte 0x%02X, but received 0x%02X in exchange %0d.", count[15:8], data_byte, num);
            $stop;
        end
    endtask

        task automatic expect_lower_byte(int num);
        if (data_byte == count[7:0]) begin
            $display("Test passed: Received lower byte 0x%02X from PL in exchange %0d.", count[7:0], num);
        end else begin
            $display("Test failed: Expected lower byte 0x%02X, but received 0x%02X in exchange %0d.", count[7:0], data_byte, num);
            $stop;
        end
    endtask

    task automatic do_exchange(int num, int wait_time);
        wait (num == count);
        #(wait_time);
        $display("Starting exchange %0d after waiting for %0d time units.", num, wait_time);
        flip_req_clk(num);
        ps_wait_for_ack(num);
        ps_wait_for_valid(num);
        expect_upper_byte(num);
        #(10);
        flip_req_clk(num);
        ps_wait_for_ack(num);
        ps_wait_for_valid(num);
        expect_lower_byte(num);
        count++;
    endtask
    
    initial begin
        clk = 0;
        ps_ready_for_data = 0;
        reset_dut();
        @(posedge clk);
        repeat(35) @(posedge clk); // skip first 10 values 

        ps_ready_for_data = 1; // Indicate that PS is ready to receive data
        for (int i = count; i <= 1000; i++) begin
            do_exchange(i, $urandom_range(1, 100)); // Random wait time between 1 and 10 time units before each exchange
        end
        ps_ready_for_data = 0; // Indicate that PS is no longer ready to receive data

        repeat(35) @(posedge clk); // skip first 10 values 

        ps_ready_for_data = 1; // Indicate that PS is ready to receive data

        for (int i = count; i <= 2000; i++) begin
            do_exchange(i, $urandom_range(1, 100)); // Random wait time between 1 and 10 time units before each exchange
        end

        ps_ready_for_data = 0; // Indicate that PS is no longer ready to receive data

        $display("All tests passed!");
        $stop;
    end
    
endmodule