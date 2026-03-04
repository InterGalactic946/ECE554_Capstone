// ------------------------------------------------------------
// Interface: fetch_decode_if
// Description:
//   Shared IF/ID bundle used to connect Fetch-stage outputs
//   to Decode-stage inputs with a single interface handle.
//
//   Purpose:
//   1) Keep module port lists short and readable.
//   2) Keep signal naming consistent across producer/consumer.
//   3) Make future pipeline refactors lower-risk by centralizing
//      the IF/ID boundary definition in one place.
//
// Notes:
//   - This file only defines the boundary contract.
//   - Existing modules may continue using discrete ports until
//     they are migrated incrementally.
// Author: Srivibhav Jonnalagadda
// Date: 03-04-2026
// ------------------------------------------------------------
interface Fetch_Decode_if #(
    parameter int unsigned XLEN = 32
);
    // --------------------------------------------------------
    // PC/Instruction bundle
    // --------------------------------------------------------
    logic [XLEN-1:0] pc_curr;           // Current instruction address.
    logic [XLEN-1:0] pc_next;           // Sequential next PC value.
    logic [XLEN-1:0] pc_inst;           // Instruction fetched at pc_curr.

    // --------------------------------------------------------
    // Branch prediction metadata
    // --------------------------------------------------------
    logic [1:0]      prediction;        // 2-bit prediction state.
    logic [XLEN-1:0] predicted_target;  // Predicted target from BTB.

    // Producer-side view (Fetch / IF stage source).
    modport producer (
        output pc_curr,
        output pc_next,
        output pc_inst,
        output prediction,
        output predicted_target
    );

    // Consumer-side view (Decode / ID stage sink).
    modport consumer (
        input pc_curr,
        input pc_next,
        input pc_inst,
        input prediction,
        input predicted_target
    );
endinterface
