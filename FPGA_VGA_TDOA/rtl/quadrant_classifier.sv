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

    // logic [TSW:0] east_sum, west_sum, north_sum, south_sum;
    // logic         east_earlier, west_earlier, north_earlier, south_earlier;

    logic [1:0]     earliest_mic;

    logic           classify_valid;
    logic [2:0]     classify_code;

    logic [2:0]     quadrant_count;
    logic [2:0]     prev_classify_code;
    logic           prev_classify_valid;

    // Adders for the border sums
    // assign east_sum  = {1'b0, hit_time[0]} + {1'b0, hit_time[3]}; // SE + NE
    // assign west_sum  = {1'b0, hit_time[1]} + {1'b0, hit_time[2]}; // SW + NW
    // assign north_sum = {1'b0, hit_time[2]} + {1'b0, hit_time[3]}; // NW + NE
    // assign south_sum = {1'b0, hit_time[0]} + {1'b0, hit_time[1]}; // SE + SW

    // assign east_earlier = (east_sum < west_sum);
    // assign west_earlier = (west_sum < east_sum);
    // assign north_earlier = (north_sum < south_sum);
    // assign south_earlier = (south_sum < north_sum);

    // Checks what is the "earliest microphone" for the fallback option if not all hits are valid
    always_comb begin
        earliest_mic  = 2'd0;

        if ((hit_time[0] < hit_time[1]) && (hit_time[0] < hit_time[2]) && (hit_time[0] < hit_time[3])) begin
            earliest_mic  = 2'd0;
        end

        else if ((hit_time[1] < hit_time[0]) && (hit_time[1] < hit_time[2]) && (hit_time[1] < hit_time[3])) begin
            earliest_mic  = 2'd1;
        end

        else if ((hit_time[2] < hit_time[0]) && (hit_time[2] < hit_time[1]) && (hit_time[2] < hit_time[3])) begin
            earliest_mic  = 2'd2;
        end

        else begin
            earliest_mic  = 2'd3;
        end

        case (earliest_mic)
                2'd0: classify_code = Q_SE;
                2'd1: classify_code = Q_SW;
                2'd2: classify_code = Q_NW;
                2'd3: classify_code = Q_NE;
                default: classify_code = Q_UNKNOWN;
        endcase
    end

    // Captures quadrant code a clock after the event done signal
    // to allow for quadrant classification
    always_ff @(posedge clk, negedge rst_n) begin
        if (!rst_n) begin
            quadrant_valid <= 1'b0;
            quadrant_code  <= Q_UNKNOWN;
        end else if (prev_classify_valid && (quadrant_count == 3'b011)) begin
                quadrant_valid <= 1'b1;
                quadrant_code  <= classify_code;
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

    always_ff @(posedge clk, negedge rst_n) begin
        if (!rst_n) begin
            prev_classify_valid <= 1'b0;
        end else begin
            prev_classify_valid <= event_done;
        end
    end

    always_ff @(posedge clk, negedge rst_n) begin
        if (!rst_n) begin
            quadrant_count <= 3'b0;
        end else if (prev_classify_valid && (classify_code == prev_classify_code)) begin
            quadrant_count <= quadrant_count + 1;
        end else begin
            quadrant_count <= 3'b0;
        end
    end

    /*

    // Logic that checks what quadrant it is depending on the sums
    always_comb begin
        classify_valid = 1'b0;
        classify_code  = Q_UNKNOWN;

        // event_done guarantees the event is finished,
        // so solver always attempts classification then.
       /* if (threshold_valid == 4'b1111) begin
            if (east_earlier && north_earlier)
                classify_code = Q_NE;
            else if (west_earlier && north_earlier)
                classify_code = Q_NW;
            else if (west_earlier && south_earlier)
                classify_code = Q_SW;
            else if (east_earlier && south_earlier)
                classify_code = Q_SE;
            else begin // 
                case (earliest_mic)
                    2'd0: classify_code = Q_SE;
                    2'd1: classify_code = Q_SW;
                    2'd2: classify_code = Q_NW;
                    2'd3: classify_code = Q_NE;
                    default: classify_code = Q_UNKNOWN;
                endcase
            end
            classify_valid = 1'b1;
        end else 
        if (&threshold_valid) begin
            case (earliest_mic)
                2'd0: classify_code = Q_SE;
                2'd1: classify_code = Q_SW;
                2'd2: classify_code = Q_NW;
                2'd3: classify_code = Q_NE;
                default: classify_code = Q_UNKNOWN;
            endcase
            classify_valid = 1'b1;
        end
    end

    */

    

endmodule