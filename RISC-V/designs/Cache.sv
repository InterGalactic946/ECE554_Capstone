// -------------------------------------------------------------
// Module: Cache
// Description: 2-way set associative cache with 64 sets and 32 bytes per block
//              Total cache size = 64 sets x 2 ways x 32 bytes/line
//              = 4096 bytes total cache capacity.
// Author: Srivibhav Jonnalagadda
// Date: 03-07-2026
// -------------------------------------------------------------
import Core_Cfg_pkg::*;
module Cache (
    input logic  clk_i,  // System clock
    input logic  rst_i,  // Active high synchronous reset
    input addr_t addr_i, // Address of the memory to access

    // Data array control signals
    input xlen_t data_i,             // Data (instruction or word) to write into the cache
    input logic  write_data_array_i, // Write enable for data array

    // Meta data array control signals
    input logic [TAG_WIDTH-1:0] tag_i,  // The new tag to be written to the cache on a miss
    input logic write_tag_array_i,  // Write enable for tag array

    // Outputs
    output xlen_t data_o,  // Output data from cache (e.g., fetched instruction or memory word)
    output logic  hit_o    // Indicates cache hit or miss in this cycle.
);

  /////////////////////////////////////////////////
  // Declare any internal signals as type wire  //
  ///////////////////////////////////////////////
  logic set_first_lru;  // Sets the first LRU bit and clears the second.
  logic first_tag_lru;  // LRU bit of the first tag
  logic evict_first_way;  // Indicates which line we are evicting on a cache miss.
  logic way_select;  // The line to write data to either on a hit or a miss.
  logic [CACHE_SET_WIDTH-1:0] set_idx;  // The set index bits of the address to index into the cache arrays.
  logic [WORD_IDX_W-1:0] word_idx;  // The word index
  xlen_t first_data_out;  // The data currently stored in the first line of the cache.
  xlen_t second_data_out;  // The data currently stored in the second line of the cache.
  logic first_way_match;  // 1-bit signal indicating the first "way" in the set caused a cache hit.
  logic second_way_match;       // 1-bit signal indicating the second "way" in the set caused a cache hit.
  logic [TAG_WIDTH-1:0] first_tag_in;  // Input to the first line in MDA.
  logic [TAG_WIDTH-1:0] second_tag_in;  // Input to the second line in MDA.
  logic [TAG_WIDTH-1:0] first_tag_out;    // The tag currently stored in the first line of the cache to compare to.
  logic [TAG_WIDTH-1:0] second_tag_out;   // The tag currently stored in the second line in the cache to compare to.
  ///////////////////////////////////////////////

  // 3 bits for word index within the cache line (32 bytes per line = 8 words, so 3 bits).
  assign word_idx = addr_i[CACHE_WORD_IDX_MSB:CACHE_WORD_IDX_LSB];

  // 6 bits for set index (64 sets, so 6 bits).
  assign set_idx  = addr_i[CACHE_SET_IDX_MSB:CACHE_SET_IDX_LSB];

  ////////////////////////////////////////////////////////////
  // Implement the L1-cache as structural/dataflow verilog //
  //////////////////////////////////////////////////////////
  // Instantiate the data array for the cache.
  DataArray iDA (
      .clk_i(clk_i),
      .rst_i(rst_i),
      .write_i(write_data_array_i),
      .data_i(data_i),
      .way_select_i(way_select),
      .set_idx_i(set_idx),
      .word_idx_i(word_idx),

      .first_way_data_o (first_data_out),
      .second_way_data_o(second_data_out)
  );

  // We write to the second line if the second "way" had a hit, else "way" 0 on a hit, otherwise we write to the line that is evicted,
  // if evict_first_way is high, we write to first line else second line.
  assign way_select = (hit_o) ? second_way_match : ~evict_first_way;

  // Instantiate the meta data array for the cache.
  MetaDataArray iMDA (
      .clk_i(clk_i),
      .rst_i(rst_i),
      .write_i(write_tag_array_i),
      .first_way_data_i(first_tag_in),
      .second_way_data_i(second_tag_in),
      .set_idx_i(set_idx),
      .set_first_lru_i(set_first_lru),

      .first_way_data_o (first_tag_out),
      .second_way_data_o(second_tag_out)
  );

  // Indicates the first line's LRU bit is set.
  assign first_tag_lru = first_tag_out[CACHE_META_LRU_BIT];

  // If the second cache line's LRU is 1, evict second_way (1), else evict first_way (0). (TagOut[0] == LRU)
  assign evict_first_way = first_tag_lru;

  // If we have a cache hit and the first line is a match, then we clear the first line's LRU bit. Otherwise, if the second line is a match
  // on a hit, then we set the set the first line's LRU bit. If there is a cache miss and we are evicting the first way, then we clear the
  // first cache line's LRU bit and set the second's, Otherwise, if the second way is evicted on a miss, then we set the first line's LRU bit
  // and clear the second line's.
  assign set_first_lru = (hit_o) ? ~first_way_match : ~evict_first_way;

  // If we had a hit on the this cycle, we keep the same tag, but internally update the LRU bits for each line.
  // Else if it is an eviction, we take the new tag to write in the corresponding line.
  assign first_tag_in = (hit_o) ? first_tag_out : ((evict_first_way) ? tag_i : first_tag_out);
  assign second_tag_in = (hit_o) ? second_tag_out : ((~evict_first_way) ? tag_i : second_tag_out);

  // Compare the tag stored in the cache currently at both "ways/lines" in parallel, 
  // checking for equality and valid bit set. (addr tag bits == stored tag and metadata valid bit == 1)
  assign first_way_match =
      (addr_i[CACHE_TAG_MSB:CACHE_TAG_LSB] == first_tag_out[CACHE_META_TAG_MSB:CACHE_META_TAG_LSB]) &
      first_tag_out[CACHE_META_VALID_BIT];
  assign second_way_match =
      (addr_i[CACHE_TAG_MSB:CACHE_TAG_LSB] == second_tag_out[CACHE_META_TAG_MSB:CACHE_META_TAG_LSB]) &
      second_tag_out[CACHE_META_VALID_BIT];

  // It is a cache hit if either of the "ways" resulted in a match, else it is a miss.
  assign hit_o = first_way_match | second_way_match;

  // Grab the data to be output based on which way had a read hit, else if not a read hit, just output 0s.
  assign data_o = (hit_o & ~write_data_array_i) ? ((second_way_match) ? second_data_out : first_data_out)
                                                : '0;

endmodule
