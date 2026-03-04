`default_nettype none // Set the default as none to avoid errors.

///////////////////////////////////////////////////////////////////////////
// IF_ID_pipe_reg.sv                                                     //
//                                                                       //
// Instruction Fetch to Decode pipeline register with interface-based    //
// boundary wiring.                                                      //
///////////////////////////////////////////////////////////////////////////
module IF_ID_pipe_reg (
    clk_i,
    rst_i,
    stall_i,
    flush_i,
    if_id_if_i,
    if_id_if_o
  );

  input logic clk_i;    // System clock
  input logic rst_i;    // Active high synchronous reset
  input logic stall_i;  // Stall signal (prevents updates)
  input logic flush_i;  // Flush pipeline register (clears instruction/prediction)

  // Interface from Fetch stage into IF/ID pipeline register.
  Fetch_Decode_if if_id_if_i;

  // Interface from IF/ID pipeline register into Decode stage.
  Fetch_Decode_if if_id_if_o;

  ///////////////////////////////////////////////
  // Declare any internal signals as type logic//
  ///////////////////////////////////////////////
  logic wen; // Register write enable signal.
  logic clr; // Clear signal for instruction word register
  ///////////////////////////////////////////////

  ///////////////////////////////////////
  // Model the IF/ID Pipeline Register //
  ///////////////////////////////////////
  // We write to the register whenever we don't stall.
  assign wen = ~stall_i;
 
  // We clear the instruction word register whenever we flush or during rst.
  assign clr = flush_i | rst_i;

  // Model register for storing the current instruction's address.
  always_ff @(posedge clk_i)
    if (rst_i)
      if_id_if_o.pc_curr <= 32'h0000_0000;
    else if (wen)
      if_id_if_o.pc_curr <= if_id_if_i.pc_curr;
  
  // Model register for storing the next instruction's address.
  always_ff @(posedge clk_i)
    if (rst_i)
      if_id_if_o.pc_next <= 32'h0000_0000;
    else if (wen)
      if_id_if_o.pc_next <= if_id_if_i.pc_next;
  
  // Model register for storing the fetched instruction word (clear the instruction on flush).
  always_ff @(posedge clk_i)
    if (clr)
      if_id_if_o.pc_inst <= 32'h0000_0000;
    else if (wen)
      if_id_if_o.pc_inst <= if_id_if_i.pc_inst;
  
  // Model register for storing the predicted branch taken signal (clear the signal on flush).
  always_ff @(posedge clk_i)
    if (clr)
      if_id_if_o.prediction <= 2'b00;
    else if (wen)
      if_id_if_o.prediction <= if_id_if_i.prediction;
  
  // Model register for storing the predicted target address (clear the data on flush).
  always_ff @(posedge clk_i)
    if (clr)
      if_id_if_o.predicted_target <= 32'h0000_0000;
    else if (wen)
      if_id_if_o.predicted_target <= if_id_if_i.predicted_target;
  /////////////////////////////////////////////////////////////////////////////

endmodule

`default_nettype wire // Reset default behavior at the end.
