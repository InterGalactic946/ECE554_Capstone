//-------------------------------------------------------------
// Module: DataArray
// Description: 4KB Data array for the cache.
//              It is a 2-way set associative array of blocks,
//              where each block has 8 words and has 64 sets with
//              32 bytes per block.
// Author: Srivibhav Jonnalagadda
// Date: 03-07-2026
// -------------------------------------------------------------
import Core_Cfg_pkg::*;
module DataArray (
    input logic clk_i,
    input logic rst_i,
    input logic [CACHE_LINE_WORD_W-1:0] data_i,
    input logic write_i,
    input logic way_select_i,
    input logic [CACHE_SET_IDX_W-1:0] set_idx_i,
    input logic [WORD_IDX_W-1:0] word_idx_i,
    output logic [CACHE_LINE_WORD_W-1:0] first_way_data_o,
    output logic [CACHE_LINE_WORD_W-1:0] second_way_data_o
);

  // 2-way set associative array of blocks. Each set has 2 blocks (ways), and each block has 8 words.
  // Each word is 32 bits (4 bytes).
  logic [CACHE_LINE_WORD_W-1:0] block_first_way[CACHE_SET_COUNT][CACHE_LINE_WORDS];
  logic [CACHE_LINE_WORD_W-1:0] block_second_way[CACHE_SET_COUNT][CACHE_LINE_WORDS];
  integer set_idx;
  integer word_idx;

  // Write logic
  always_ff @(posedge clk_i) begin
    if (rst_i) begin
      block_first_way  <= '{default: '{default: '0}};
      block_second_way <= '{default: '{default: '0}};
    end else if (write_i) begin
      if (way_select_i) block_second_way[set_idx_i][word_idx_i] <= data_i;
      else block_first_way[set_idx_i][word_idx_i] <= data_i;
    end
  end

  // Read logic (combinational).
  assign first_way_data_o  = block_first_way[set_idx_i][word_idx_i];
  assign second_way_data_o = block_second_way[set_idx_i][word_idx_i];

endmodule
