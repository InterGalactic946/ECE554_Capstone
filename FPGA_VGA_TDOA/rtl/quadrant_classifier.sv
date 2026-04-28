module quadrant_classifier #(
    parameter int TSW                 = 32
) (
    input  logic                         clk,
    input  logic                         rst_n,

    input  logic                         event_done,
    input  logic [3:0]                   threshold_valid,
    input  logic [TSW-1:0]               hit_time [4],

    output logic                         quadrant_valid,
    output logic [2:0]                   quadrant_code
);


    localparam logic [2:0] Q_UNKNOWN = 3'd0;
    localparam logic [2:0] Q_NE      = 3'd1;
    localparam logic [2:0] Q_NW      = 3'd2;
    localparam logic [2:0] Q_SW      = 3'd3;
    localparam logic [2:0] Q_SE      = 3'd4;

    logic [1:0]     earliest_mic;

    logic [2:0]     classify_code;

    //logic [2:0]     quadrant_count;
    logic [2:0]     prev_classify_code;

    logic [TSW-1:0] earliest_time;


    // Checks what is the "earliest microphone" for the fallback option if not all hits are valid
    always_comb begin
        earliest_mic  = 2'd0;
        earliest_time = {TSW{1'b1}};

        if (threshold_valid[0]) begin
            earliest_mic  = 2'd0;
            earliest_time = hit_time[0];
        end

        if (threshold_valid[1] && (hit_time[1] < earliest_time)) begin
            earliest_mic  = 2'd1;
            earliest_time = hit_time[1];
        end

        if (threshold_valid[2] && (hit_time[2] < earliest_time)) begin
            earliest_mic  = 2'd2;
            earliest_time = hit_time[2];
        end

        if (threshold_valid[3] && (hit_time[3] < earliest_time)) begin
            earliest_mic  = 2'd3;
            earliest_time = hit_time[3];
        end

        if (|threshold_valid) begin
            case (earliest_mic)
                2'd0: classify_code = Q_SE;
                2'd1: classify_code = Q_SW;
                2'd2: classify_code = Q_NW;
                2'd3: classify_code = Q_NE;
                default: classify_code = Q_UNKNOWN;
            endcase
        end else begin
            classify_code = Q_UNKNOWN;
        end
    end

    // Captures quadrant code a clock after the event done signal
    // to allow for quadrant classification
    always_ff @(posedge clk, negedge rst_n) begin
        if (!rst_n) begin
            quadrant_valid <= 1'b0;
            quadrant_code  <= Q_UNKNOWN;
        // Checks if the quadrant stays the same for the 3 consecutive events after the classification
        end else if (event_done) begin
                quadrant_valid <= 1'b1;
                quadrant_code  <= prev_classify_code;
        end
        else begin
            quadrant_valid <= 1'b0;
        end
    end

    always_ff @(posedge clk, negedge rst_n) begin
        if (!rst_n) begin
            prev_classify_code <= Q_UNKNOWN;
        end else if (event_done) begin
            prev_classify_code <= classify_code;
        end
    end

    /*

    always_ff @(posedge clk, negedge rst_n) begin
        if (!rst_n) begin
            quadrant_count <= 3'b0;
        end else if (event_done && (classify_code == prev_classify_code)) begin
            quadrant_count <= quadrant_count + 1;
        end else if (event_done && (classify_code != prev_classify_code)) begin
            quadrant_count <= 3'b0;
        end
    end

    */

endmodule