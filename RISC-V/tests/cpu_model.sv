///////////////////////////////////////////////////////////
// cpu.sv: Central Processing Unit Module                //  
//                                                       //
// This module represents the CPU, responsible for       //
// fetching, decoding, executing instructions, and       //
// It integrates the processor core with main memory     //
// to facilitate program execution.                      //
///////////////////////////////////////////////////////////
module cpu_model (clk, rst_n, hlt, pc);

  input logic clk;         // System clock
  input logic rst_n;       // Active low synchronous reset
  output logic hlt;        // Asserted once the processor finishes an instruction before a HLT instruction
  output logic [31:0] pc;  // PC value over the course of program execution

  ///////////////////////////////////
  // Declare any internal signals //
  /////////////////////////////////  
  logic rst;                 // Active-high reset (internal)
  logic mem_wr;              // Memory write enable
  logic mem_en;              // Memory enable
  logic [31:0] mem_addr;     // Address to memory
  logic [31:0] mem_data_in;  // Data to write to memory
  logic [31:0] mem_data_out; // Data read from memory
  logic mem_data_valid;      // Valid signal from memory
  logic [15:0] mem_addr_legacy;     // Legacy 16-bit memory address path
  logic [15:0] mem_data_in_legacy;  // Legacy 16-bit memory write data path
  logic [15:0] mem_data_out_legacy; // Legacy 16-bit memory read data path
  /////////////////////////////////

  /////////////////////////////////////////
  // Make reset active high for modules //
  ///////////////////////////////////////
  assign rst = ~rst_n;
  assign mem_addr_legacy = mem_addr[15:0];
  assign mem_data_in_legacy = mem_data_in[15:0];
  assign mem_data_out = {16'h0000, mem_data_out_legacy};

  /////////////////////////////////////
  // Instantiate the processor core //
  ///////////////////////////////////
  proc_model iPROC (
    .clk(clk),
    .rst(rst),
    
    .mem_data_valid(mem_data_valid),
    .mem_data_in(mem_data_out),
    
    .mem_en(mem_en),
    .mem_addr(mem_addr),
    .mem_wr(mem_wr),
    .mem_data_out(mem_data_in),

    .hlt(hlt),
    .pc(pc)
  );

  //////////////////////////////
  // Instantiate main memory  //
  //////////////////////////////
  memory iMAIN_MEM (
    .clk(clk),
    .rst(rst),
    .enable(mem_en),
    .addr(mem_addr_legacy),
    .wr(mem_wr),
    .data_in(mem_data_in_legacy),
    
    .data_valid(mem_data_valid),
    .data_out(mem_data_out_legacy)
  );

endmodule

`default_nettype wire  // Reset default behavior at the end
