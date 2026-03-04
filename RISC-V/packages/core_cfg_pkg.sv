// ------------------------------------------------------------
// Package: core_cfg_pkg
// Description:
//   Centralized core configuration values and shared typedefs.
//   This package is intended to be the single source of truth
//   for architectural widths and common scalar types used by
//   RTL modules and testbench models.
//
//   Goal:
//   Keep module files short and consistent by avoiding repeated
//   hardcoded widths (for example [31:0]) across the codebase.
//
// Author: Srivibhav Jonnalagadda
// Date: 03-04-2026
// ------------------------------------------------------------
package core_cfg_pkg;

    // ------------------------------------------------------------
    // Core Architectural Widths
    // ------------------------------------------------------------
    // XLEN:
    //   Width of integer datapath operands/results.
    //   RV32I baseline = 32.
    localparam int unsigned XLEN = 32;

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
    // These values describe current predictor/cache implementation
    // sizing so modules can reference one shared definition.
    localparam int unsigned BHT_ENTRIES = 8;
    localparam int unsigned BTB_ENTRIES = 8;
    localparam int unsigned CACHE_SET_COUNT = 64;
    localparam int unsigned CACHE_WAYS = 2;
    localparam int unsigned CACHE_LINE_WORDS = 8;

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
