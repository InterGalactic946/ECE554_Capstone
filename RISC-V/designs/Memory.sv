// ------------------------------------------------------------
// Module: Memory
// Description: Infers a XLEN-bit PLEN-bit addressable memory
//              with a 4 cycle read delay and single cycle 
//              write.
// Author: Srivibhav Jonnalagadda
// Date: 03-14-2026
// ------------------------------------------------------------
import Core_Cfg_pkg::*;

module Memory (
  input logic clk_i,        // System clock
  input logic rst_i,        // Synchronous, active-high reset
  input logic wr_i,         // Write enable (1 for write, 0 for read)
  input logic enable_i,     // Enable signal for memory access
  input addr_t addr_i,      // Address for memory read/write operation
  input xlen_t data_i,      // XLEN-bit data input to be written into memory
  output xlen_t data_o,     // XLEN-bit data output read from memory
  output logic data_valid_o // Output signal indicating when the data_out is valid
);

  // Internal signals to simulate a 4-cycle latency for memory reads.
  localparam int unsigned MAX_DEPTH = 2_147_483_647;
  xlen_t data_out_4;
  xlen_t data_out_3, data_out_2, data_out_1;
  logic data_valid_4;
  logic data_valid_3, data_valid_2, data_valid_1;

  // Instantiate the memory structure.
  xlen_t data_mem[MAX_DEPTH];

  /////////////////////////////////////////////////////////////////////////////
  // Combinational logic for reading from memory                             //
  // - Only when memory is enabled and not in write mode.                    //
  // - Data is read from memory and marked valid.                            //
  /////////////////////////////////////////////////////////////////////////////
  assign data_out_4   = (enable_i && !wr_i) ? data_mem[addr_i[MEM_ADDR_MSB:MEM_ADDR_LSB]] : '0;
  assign data_valid_4 = (enable_i && !wr_i);

  /////////////////////////////////////////////////////////////////////////////
  // Memory write and initialization logic                                   //
  // - On reset, memory is loaded from a file once.                          //
  // - On write enable, input data is written to memory.                     //
  /////////////////////////////////////////////////////////////////////////////
  always_ff @(posedge clk_i) begin
    if (rst_i) begin
      $readmemh("./tests/loadfile_all.img", data_mem);  // Load memory contents
    end else if (enable_i && wr_i) begin
      // Store word operation (write to data memory)
      data_mem[addr_i[MEM_ADDR_MSB:MEM_ADDR_LSB]] <= data_i;
    end
  end

  /////////////////////////////////////////////////////////////////////////////
  // Pipeline registers for simulating 4-cycle read latency                  //
  // - Each cycle, values are shifted down the pipeline.                     //
  // - After 4 cycles, the original read value appears on data_out.          //
  /////////////////////////////////////////////////////////////////////////////
  always_ff @(posedge clk_i) begin
    if (rst_i) begin
      // Reset all output and pipeline stages
      data_out_3 <= '0;
      data_out_2 <= '0;
      data_out_1 <= '0;
      data_o <= '0;

      data_valid_3 <= 1'b0;
      data_valid_2 <= 1'b0;
      data_valid_1 <= 1'b0;
      data_valid_o <= 1'b0;
    end else begin
      // Shift data and valid signals through pipeline
      data_out_3 <= data_out_4;
      data_out_2 <= data_out_3;
      data_out_1 <= data_out_2;
      data_o <= data_out_1;

      data_valid_3 <= data_valid_4;
      data_valid_2 <= data_valid_3;
      data_valid_1 <= data_valid_2;
      data_valid_o <= data_valid_1;
    end
  end

endmodule
