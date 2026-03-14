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
  localparam int unsigned BHT_ENTRIES = 8;  // Number of entries in the Branch History Table (BHT).
  localparam int unsigned BTB_ENTRIES = 8;  // Number of entries in the Branch Target Buffer (BTB).
  localparam int unsigned BHT_IDX_W = $clog2(
      BHT_ENTRIES
  );  // Width of the BHT index (log2 of number of entries).
  localparam int unsigned BTB_IDX_W = $clog2(
      BTB_ENTRIES
  );  // Width of the BTB index (log2 of number of entries).
  localparam int unsigned PC_ALIGN_LSB = $clog2(
      ILEN_BYTES
  );  // Number of always-zero PC LSBs for aligned instruction fetch.
  localparam int unsigned BHT_IDX_LSB = PC_ALIGN_LSB; // Least-significant bit used for BHT index extraction from PC.
  localparam int unsigned BHT_IDX_MSB = BHT_IDX_LSB + BHT_IDX_W - 1; // Most-significant bit used for BHT index extraction.
  localparam int unsigned BTB_IDX_LSB = PC_ALIGN_LSB; // Least-significant bit used for BTB index extraction from PC.
  localparam int unsigned BTB_IDX_MSB = BTB_IDX_LSB + BTB_IDX_W - 1; // Most-significant bit used for BTB index extraction.
  localparam int unsigned DBP_TAG_W = XLEN - (BHT_IDX_MSB + 1); // Width of the tag stored in BHT entries after removing index and alignment bits.
  localparam int unsigned DBP_BHT_ENTRY_W = DBP_TAG_W + 3; // Total width of a BHT entry: tag bits + 2 bits for prediction + 1 valid bit.

  // Cache geometry parameters (for potential future use in cache modules).
  localparam int unsigned CACHE_SET_COUNT = 64;
  localparam int unsigned CACHE_WAYS = 2;
  localparam int unsigned CACHE_LINE_WORDS = 8;

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
