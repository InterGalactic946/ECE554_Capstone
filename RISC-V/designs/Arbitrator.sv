///////////////////////////////////////////////////////////
// Arbitrator.sv                                         //
// This module implements arbitration logic for main     //
// memory access when both ICACHE and DCACHE requests    //
// occur simultaneously. It ensures that only one cache  //
// accesses main memory at a time to avoid bus contention//
///////////////////////////////////////////////////////////
module Arbitrator (
    input  logic        clk,         // Clock signal
    input  logic        rst,         // Active-high reset

    // ICACHE Interface
    input  logic        ICACHE_hit,           // Indicates a hit in ICACHE
    input  logic        ICACHE_miss_mem_en,   // ICACHE miss memory enable
    input  logic [15:0] ICACHE_miss_addr,     // Address used for ICACHE miss

    // DCACHE Interface
    input  logic        DCACHE_hit,         // Indicates a hit in DCACHE
    input  logic        DCACHE_en,          // DCACHE request enable
    input  logic        DCACHE_write,       // DCACHE write enable
    input  logic        DCACHE_miss_mem_en, // DCACHE miss memory enable
    input  logic [15:0] DCACHE_miss_addr,   // Address used for DCACHE miss
    input  logic [15:0] DCACHE_hit_addr,    // Address used for DCACHE hit

    // Arbitration Outputs
    output logic        ICACHE_proceed,  // Grant signal for ICACHE to proceed to access main memory
    output logic        DCACHE_proceed,  // Grant signal for DCACHE to proceed to access main memory

    // Main Memory Interface
    output logic        mem_en,     // Enable signal for main memory access
    output logic [15:0]  mem_addr   // Address for main memory access
);
  
  ///////////////////////////////////////
  // Declare state types as enumerated //
  ///////////////////////////////////////
  typedef enum logic [1:0] {IDLE, DSERV, ISERV} state_t;

  /////////////////////////////////////////////////
  // Declare any internal signals as type wire  //
  ///////////////////////////////////////////////
  logic ICACHE_miss;         // Indicates a miss in ICACHE.
  logic DCACHE_miss;         // Indicates a miss in DCACHE.
  logic set_ICACHE_proceed;  // Set signal for ICACHE proceed.
  logic set_DCACHE_proceed;  // Set signal for DCACHE proceed.
  logic clr_ICACHE_proceed;  // Clear signal for ICACHE proceed.
  logic clr_DCACHE_proceed;  // Clear signal for DCACHE proceed.
  state_t state;             // Holds the current state.
  state_t nxt_state;         // Holds the next state. 
  logic error;               // Error flag raised when state machine is in an invalid state.  
  ////////////////////////////////////////////////

  // Miss detected when not a hit.
  assign ICACHE_miss = ~ICACHE_hit;
  assign DCACHE_miss = DCACHE_en & ~DCACHE_hit;

  /////////////////////////////////////
  // Implements State Machine Logic //
  ///////////////////////////////////
  // Implements state machine register, holding current state or next state, accordingly.
  always_ff @(posedge clk) begin
    if(rst)
      state <= IDLE; // Reset into the idle state if machine is reset.
    else
      state <= nxt_state; // Store the next state as the current state by default.
  end

  // Implements an SR flop for the ICACHE and DCACHE proceed signals.
  always_ff @(posedge clk)
    if (rst)
      ICACHE_proceed <= 1'b0; // Reset ICACHE proceed signal.
    else if (clr_ICACHE_proceed)
      ICACHE_proceed <= 1'b0; // Clear ICACHE proceed signal.
    else if (set_ICACHE_proceed)
      ICACHE_proceed <= 1'b1; // Set ICACHE proceed signal.

  always_ff @(posedge clk)
    if (rst)
      DCACHE_proceed <= 1'b0; // Reset DCACHE proceed signal.
    else if (clr_DCACHE_proceed)
      DCACHE_proceed <= 1'b0; // Clear DCACHE proceed signal.
    else if (set_DCACHE_proceed)
      DCACHE_proceed <= 1'b1; // Set DCACHE proceed signal.
  ////////////////////////////////////

  //////////////////////////////////////////////////////////////////////////////////////////
  // Implements the combinational state transition and output logic of the state machine.//
  ////////////////////////////////////////////////////////////////////////////////////////
  always_comb begin
    /* Default all SM outputs & nxt_state */
    nxt_state = state;          // By default, assume we are in the current state.
    set_ICACHE_proceed = 1'b0;  // Default set ICACHE proceed signal is low.
    set_DCACHE_proceed = 1'b0;  // Default set DCACHE proceed signal is low.
    clr_ICACHE_proceed = 1'b0;  // Default clear ICACHE proceed signal is low.
    clr_DCACHE_proceed = 1'b0;  // Default clear DCACHE proceed signal is low.
    mem_en = 1'b0;              // Default memory enable signal is low.
    mem_addr = 16'h0000;        // Default memory address is 0.
    error = 1'b0;               // Default no error state.

    case (state)
      ISERV : begin // ISERV state - waiting for ICACHE to finish access to memory.
        mem_en = ICACHE_miss_mem_en; // Enable memory access for ICACHE.
        mem_addr = ICACHE_miss_addr; // Set the memory address to the ICACHE miss address.
        if (ICACHE_hit) begin // If ICACHE is a hit
          clr_ICACHE_proceed = 1'b1; // Clear ICACHE proceed signal.
          if (DCACHE_miss) begin // and DCACHE misses, go to DSERV state.
            set_DCACHE_proceed = 1'b1; // Grant DCACHE access to main memory.
            nxt_state = DSERV;         // Go to DSERV state.
          end else begin // If ICACHE is a hit and DCACHE does not miss
            nxt_state = IDLE; // Go to IDLE state.
          end
        end
      end

      DSERV : begin  // DSERV state - waiting for DCACHE to finish access to memory.
        mem_en   = DCACHE_miss_mem_en;     // Enable memory access for DCACHE.
        mem_addr = DCACHE_miss_addr;       // Set the memory address to the DCACHE miss address.

        // If DCACHE hit and ICACHE misses, we need to arbitrate.
        if (DCACHE_hit) begin
          clr_DCACHE_proceed = 1'b1; // Clear DCACHE proceed signal.
          if (DCACHE_write) begin // If DCACHE is a hit and write, we need to write to memory.
            mem_en   = 1'b1;              // Set memory enable signal high.
            mem_addr = DCACHE_hit_addr;   // Set the memory address to the DCACHE hit address.
          end 
          if (ICACHE_miss) begin // If DCACHE is a hit and ICACHE misses, go to ISERV state.
            set_ICACHE_proceed = 1'b1; // Grant ICACHE access to main memory.
            nxt_state  = ISERV;        // Go to ISERV state.
          end else begin                  // If DCACHE does not miss, we're done.
            nxt_state = IDLE;             // Go to IDLE state.
          end
        end
      end

      IDLE : begin // IDLE state - waits for a cache miss to occur.
        if (ICACHE_miss & DCACHE_miss) begin // If both caches miss, we need to arbitrate.
            set_ICACHE_proceed = 1'b1; // Grant ICACHE access to main memory.
            nxt_state = ISERV;     // Go to ISERV state.
        end else if (ICACHE_miss) begin // If only ICACHE misses, go to ISERV state.
            set_ICACHE_proceed = 1'b1; // Grant ICACHE access to main memory.
            nxt_state = ISERV;     // Go to ISERV state.
        end else if (DCACHE_miss) begin // If only DCACHE misses, go to DSERV state.
            set_DCACHE_proceed = 1'b1; // Grant DCACHE access to main memory.
            nxt_state = DSERV;     // Go to DSERV state.
        end else begin // If no cache misses, enable main memory in case of DCACHE write hit.
            mem_en = DCACHE_hit & DCACHE_en & DCACHE_write; // Enable memory access for DCACHE.
            mem_addr = DCACHE_hit_addr; // Set the memory address to the DCACHE hit address.
        end
      end

      default : begin // ERROR state - invalid state.
        nxt_state = IDLE;            // Go to IDLE state on error.
        set_ICACHE_proceed = 1'b0;  // Default set ICACHE proceed signal is low.
        set_DCACHE_proceed = 1'b0;  // Default set DCACHE proceed signal is low.
        clr_ICACHE_proceed = 1'b0;  // Default clear ICACHE proceed signal is low.
        clr_DCACHE_proceed = 1'b0;  // Default clear DCACHE proceed signal is low.
        mem_en = 1'b0;               // Clear memory enable signal.
        mem_addr = 16'h0000;         // Clear memory address.
        error = 1'b1;                // Default error state.
      end
    endcase
  end
endmodule