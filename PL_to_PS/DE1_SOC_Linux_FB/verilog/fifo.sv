/////////////////////////////////////////////////////////////
// FIFO.sv: First-In-First-Out Memory Module               //
//                                                         //
// This module implements a simple FIFO memory with        //
// parameterized depth and data width.                     //
/////////////////////////////////////////////////////////////
module FIFO
#(
  parameter DEPTH=8,
  parameter DATA_WIDTH=8
)
(
  input  clk,
  input  rst_n,
  input  rden,
  input  wren,
  input  [DATA_WIDTH-1:0] i_data,
  output [DATA_WIDTH-1:0] o_data,
  output full,
  output empty
);

  // FIFO_ip fifo(	.aclr(~rst_n),.data(i_data),.rdclk(clk),.rdreq(rden), .wrclk(clk), .wrreq(wren), .q(o_data), .rdempty(empty), .wrfull(full));

// Internal signals
logic [DATA_WIDTH-1:0] mem [0:DEPTH-1];
logic [$clog2(DEPTH):0] rd_ptr, wr_ptr, size;
logic [DATA_WIDTH-1:0] o_data_reg;

// Read pointer logic
always_ff @(posedge clk or negedge rst_n) begin
  if (!rst_n)
    rd_ptr <= '0;
  else if (rden && !empty)
    rd_ptr <= rd_ptr + 1;
end

// Write pointer logic
always_ff @(posedge clk or negedge rst_n) begin
  if (!rst_n)
    wr_ptr <= '0;
  else if (wren && !full)
    wr_ptr <= wr_ptr + 1;
end

// Write operation whenever wren is high.
always_ff @(posedge clk or negedge rst_n) begin
  if (!rst_n)
    mem <= '{default: '0};
  else if (wren)
    mem[wr_ptr] <= i_data;
end

// Read operation whenever rden is high.
always_ff @(posedge clk or negedge rst_n) begin
  if (!rst_n)
    o_data_reg <= '0;
  else if (rden && empty && wren) // Handle simultaneous read/write when FIFO is empty
    o_data_reg <= i_data; 
  else
    o_data_reg <= mem[rd_ptr];
end

// Size logic
assign size = wr_ptr - rd_ptr;

// Pass the outputs.
assign full  = (size == DEPTH);
assign empty = (size == 0);
assign o_data = o_data_reg;

endmodule