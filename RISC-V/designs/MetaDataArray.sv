//-------------------------------------------------------------
// Module: MetaDataArray
// Description: Metadata array for one 4KB cache instance.
//              This module stores one packed metadata entry per
//              set per way, not the cache data itself.
//              In the current configuration, each metadata entry
//              is TAG_WIDTH=23 bits:
//                - 21-bit line tag
//                - 1 valid bit
//                - 1 LRU bit
//              Total metadata storage = 64 sets x 2 ways x 23 bits
//              = 2944 bits = 368 bytes.
// Author: Srivibhav Jonnalagadda
// Date: 03-07-2026
// -------------------------------------------------------------
import Core_Cfg_pkg::*;
module MetaDataArray (
    input logic clk_i,
    input logic rst_i,
    input logic [TAG_WIDTH-1:0] first_way_data_i,
    input logic [TAG_WIDTH-1:0] second_way_data_i,
    input logic write_i,
    input logic [CACHE_SET_IDX_W-1:0] set_idx_i,
    input logic set_first_lru_i,
    output logic [TAG_WIDTH-1:0] first_way_data_o,
    output logic [TAG_WIDTH-1:0] second_way_data_o
);

  // Packed metadata entry = {tag, valid, lru}.
  // LSB is the LRU bit, bit[1] is the valid bit, and the remaining bits are the line tag.
  logic [TAG_WIDTH-1:0] tag_array_first_way [CACHE_SET_COUNT];
  logic [TAG_WIDTH-1:0] tag_array_second_way[CACHE_SET_COUNT];

  // Write logic
  always_ff @(posedge clk_i) begin
    if (rst_i) begin
      tag_array_first_way  <= '{default: '0};
      tag_array_second_way <= '{default: '0};
    end else if (write_i) begin
      tag_array_first_way[set_idx_i]  <= {first_way_data_i[TAG_WIDTH-1:1], set_first_lru_i};
      tag_array_second_way[set_idx_i] <= {second_way_data_i[TAG_WIDTH-1:1], ~set_first_lru_i};
    end
  end

  // Read logic (combinational).
  assign first_way_data_o  = tag_array_first_way[set_idx_i];
  assign second_way_data_o = tag_array_second_way[set_idx_i];

endmodule
