// ------------------------------------------------------------
// Package: Core_Cfg_pkg
// Description:
//   Centralized core configuration values and shared typedefs.
//   This package is intended to be the single source of truth
//   for architectural widths and common scalar types used by
//   RTL modules and testbench models.
// Author: Srivibhav Jonnalagadda
// Date: 03-04-2026
// ------------------------------------------------------------
package Core_Cfg_pkg;

  // ------------------------------------------------------------
  // Core Architectural Widths
  // ------------------------------------------------------------
  // ARCH_XLEN:
  //   Selected integer register width for the active architecture.
  //   Set to 32 for RV32-style datapath, 64 for RV64-style datapath.
  localparam int unsigned ARCH_XLEN = 32;

  // XLEN:
  //   Width of integer datapath operands/results used across RTL.
  localparam int unsigned XLEN = ARCH_XLEN;

  // PLEN:
  //   Width of addresses used on core memory paths.
  //   Current baseline = 32.
  localparam int unsigned PLEN = 32;

  // ILEN_BITS:
  //   Instruction container width in bits.
  //   RV32I instruction encoding = 32 bits.
  localparam int unsigned ILEN_BITS = 32;

  // ILEN_BYTES:
  //   Instruction size in bytes used by sequential PC stepping.
  //   RV32I base ISA = 4 bytes per instruction.
  localparam int unsigned ILEN_BYTES = 4;

  // SHAMT_W:
  //   Width of shift amount based on XLEN.
  //   RV32 -> 5 bits, RV64 -> 6 bits.
  localparam int unsigned SHAMT_W = (XLEN == 64) ? 6 : 5;

  // ------------------------------------------------------------
  // Register File Geometry
  // ------------------------------------------------------------
  // REG_COUNT:
  //   Number of integer architectural registers.
  localparam int unsigned REG_COUNT = 32;

  // REG_ADDR_W:
  //   Width of register index fields (rd/rs1/rs2).
  //   For 32 registers, this is 5 bits.
  localparam int unsigned REG_ADDR_W = 5;

  // ------------------------------------------------------------
  // Microarchitectural Baseline Dimensions
  // ------------------------------------------------------------
  // Dynamic Branch Predictor geometry parameters.
  localparam int unsigned BHT_ENTRIES = 128;  // Number of entries in the Branch History Table (BHT).
  localparam int unsigned BTB_ENTRIES = 128;  // Number of entries in the Branch Target Buffer (BTB).

  // Width of the BHT/BTB index (log2 of number of entries).
  localparam int unsigned BHT_IDX_W = $clog2(BHT_ENTRIES);
  localparam int unsigned BTB_IDX_W = $clog2(BTB_ENTRIES);

  // Number of always-zero PC LSBs for aligned instruction fetch.
  localparam int unsigned PC_ALIGN_LSB = $clog2(ILEN_BYTES);

  // Extracted index bit positions for BHT indexing from the PC.
  localparam int unsigned BHT_IDX_LSB = PC_ALIGN_LSB;
  localparam int unsigned BHT_IDX_MSB = BHT_IDX_LSB + BHT_IDX_W - 1;

  // Extracted index bit positions for BTB indexing from the PC.
  localparam int unsigned BTB_IDX_LSB = PC_ALIGN_LSB;
  localparam int unsigned BTB_IDX_MSB = BTB_IDX_LSB + BTB_IDX_W - 1;

  // Width of the tag stored in BHT entries after removing index and alignment bits.
  localparam int unsigned DBP_TAG_W = XLEN - (BHT_IDX_MSB + 1);

  // Total width of a BHT entry: tag bits + 2 bits for prediction + 1 valid bit.
  localparam int unsigned DBP_BHT_ENTRY_W = DBP_TAG_W + 3;

  // ================= Cache Geometry Parameters =================
  // Number of cache sets
  localparam int unsigned CACHE_SET_COUNT = 64;  // 64 sets
  localparam int unsigned CACHE_SET_IDX_W = $clog2(CACHE_SET_COUNT);  // 6 bits for set index

  // Number of ways per set
  localparam int unsigned CACHE_WAYS = 2;  // 2-way set associative
  localparam int unsigned CACHE_WAY_IDX_W = $clog2(CACHE_WAYS);  // 1 bit for way select

  // Block (cache line) parameters
  localparam int unsigned CACHE_LINE_WORDS = 8;  // 8 words per block
  localparam int unsigned CACHE_LINE_WORD_W = 32;  // 32-bit word width
  localparam int unsigned CACHE_LINE_BYTE_W = CACHE_LINE_WORD_W / 8;  // 4 bytes per word
  localparam int unsigned CACHE_LINE_SIZE_B = CACHE_LINE_WORDS * CACHE_LINE_BYTE_W; // 32 bytes per line

  // // 64 sets * 2 ways * 32B = 4096B = 4KB total cache size
  localparam int unsigned CACHE_SIZE_BYTES = CACHE_SET_COUNT * CACHE_WAYS * CACHE_LINE_SIZE_B;

  // Word/byte enable widths
  localparam int unsigned WORD_IDX_W = $clog2(CACHE_LINE_WORDS);  // 3 bits for word index
  localparam int unsigned BYTE_ENABLE_W = 4;  // 4 bytes per word

  // Cache address slice parameters
  localparam int unsigned CACHE_BYTE_IDX_W = $clog2(CACHE_LINE_BYTE_W);
  localparam int unsigned CACHE_BYTE_IDX_LSB = 0;
  localparam int unsigned CACHE_BYTE_IDX_MSB = CACHE_BYTE_IDX_LSB + CACHE_BYTE_IDX_W - 1;

  // Word index bits within the cache line (for 32B line = 8 words, so 3 bits).
  localparam int unsigned CACHE_WORD_IDX_LSB = CACHE_BYTE_IDX_MSB + 1;
  localparam int unsigned CACHE_WORD_IDX_MSB = CACHE_WORD_IDX_LSB + WORD_IDX_W - 1;

  // Cache line offset bits (byte index + word index).
  localparam int unsigned CACHE_LINE_OFFSET_W = CACHE_BYTE_IDX_W + WORD_IDX_W;
  localparam int unsigned CACHE_LINE_OFFSET_LSB = CACHE_BYTE_IDX_LSB;
  localparam int unsigned CACHE_LINE_OFFSET_MSB = CACHE_WORD_IDX_MSB;

  // Set index bits.
  localparam int unsigned CACHE_SET_WIDTH = CACHE_SET_IDX_W;
  localparam int unsigned CACHE_SET_IDX_LSB = CACHE_LINE_OFFSET_MSB + 1;
  localparam int unsigned CACHE_SET_IDX_MSB = CACHE_SET_IDX_LSB + CACHE_SET_IDX_W - 1;

  // Tag bits are the remaining upper bits after removing set index and line offset bits from the address.
  localparam int unsigned CACHE_TAG_LSB = CACHE_SET_IDX_MSB + 1;
  localparam int unsigned CACHE_TAG_MSB = PLEN - 1;
  localparam int unsigned CACHE_TAG_W = CACHE_TAG_MSB - CACHE_TAG_LSB + 1;

  // Metadata entry bit positions within the packed tag array entry.
  localparam int unsigned CACHE_META_LRU_BIT = 0;
  localparam int unsigned CACHE_META_VALID_BIT = 1;
  localparam int unsigned CACHE_META_TAG_LSB = 2;
  localparam int unsigned CACHE_META_TAG_MSB = CACHE_META_TAG_LSB + CACHE_TAG_W - 1;

  // Tag array parameters
  // TAG_WIDTH is the packed metadata-entry width, not just the raw line-tag width.
  // For a 32-bit address, 64 sets, and 32-byte cache lines:
  //   raw line tag = 32 - 6 set bits - 5 line-offset bits = 21 bits
  //   packed entry = 21 tag bits + 1 valid bit + 1 LRU bit = 23 bits
  localparam int unsigned TAG_WIDTH = CACHE_TAG_W + 2;

  // ================= Memory Geometry =================
  // Total address width from CPU
  localparam int unsigned MEM_ADDR_WIDTH = PLEN;

  // Word size
  localparam int unsigned MEM_WORD_BITS = XLEN;
  localparam int unsigned MEM_WORD_BYTES = MEM_WORD_BITS / 8;

  // Alignment (log2 of bytes per word)
  localparam int unsigned MEM_BYTE_OFFSET_W = $clog2(MEM_WORD_BYTES);

  // Depth and number of words in memory.
  localparam longint MEM_DEPTH = 1 << MEM_ADDR_WIDTH;
  localparam int unsigned MEM_WORD_COUNT = 1 << (MEM_ADDR_WIDTH - MEM_BYTE_OFFSET_W);

  // Address slice used for indexing memory
  localparam int unsigned MEM_ADDR_MSB = MEM_ADDR_WIDTH - 1;
  localparam int unsigned MEM_ADDR_LSB = MEM_BYTE_OFFSET_W;

  // ------------------------------------------------------------
  // ISA Feature Flags
  // ------------------------------------------------------------
  // HAS_RV64I:
  //   Indicates if RV64I-specific decode/execute paths should be enabled.
  localparam bit HAS_RV64I = (XLEN == 64);

  // HAS_M:
  //   Multiply/Divide extension feature gate.
  localparam bit HAS_M = 1'b0;

  // HAS_C:
  //   Compressed instruction extension feature gate.
  localparam bit HAS_C = 1'b0;

  // ------------------------------------------------------------
  // Shared Scalar Types
  // ------------------------------------------------------------
  // xlen_t:
  //   Generic integer datapath value (register/ALU operands).
  typedef logic [XLEN-1:0] xlen_t;

  // addr_t:
  //   Generic address value on core memory paths.
  typedef logic [PLEN-1:0] addr_t;

  // inst_t:
  //   Instruction word container.
  typedef logic [ILEN_BITS-1:0] inst_t;

  // reg_idx_t:
  //   Register index value used for rd/rs1/rs2 addressing.
  typedef logic [REG_ADDR_W-1:0] reg_idx_t;

endpackage
