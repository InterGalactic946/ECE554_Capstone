module rom_intf(
    input logic clk,
    input logic rst_n,
    input logic readdatavalid,
    output logic [2:0] addr,
    output logic read,
    output logic done
);

  logic [2:0] addr_out;
  logic inc_addr;

  always_ff @(posedge clk, negedge rst_n)
    if (!rst_n)
      addr_out <= 3'h0;
    else if (inc_addr)
      addr_out <= addr_out + 1'b1;

  assign addr = addr_out;

  typedef enum logic [1:0] {IDLE, SEND, DONE} state_t;
  state_t nxt_state;
  state_t state;

  always_ff @(posedge clk, negedge rst_n)
    if (!rst_n)
      state <= IDLE;
    else
      state <= nxt_state;

  always_comb begin
    nxt_state = state;  
    inc_addr = 1'b0; 
    read = 1'b0;
    done = 1'b0;
            
    case (state)
      IDLE : begin 
        nxt_state = SEND; 
        read = 1'b1;   
      end

      SEND : begin 
        if (readdatavalid && (addr_out != 3'h7)) begin
          inc_addr = 1'b1;
          read = 1'b1;
        end
        else if (readdatavalid && (addr_out == 3'h7)) begin
          nxt_state = DONE;
        end          
      end

      DONE : begin
        // we done
        done = 1'b1;
      end
    endcase
  end

endmodule