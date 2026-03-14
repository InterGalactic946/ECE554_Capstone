// ------------------------------------------------------------
// Module: Register_File
// Description: Implements the processor register file.
//              Provides two asynchronous read ports and one
//              synchronous write port. Supports register file
//              bypassing when a read and write target the
//              same register in the same cycle. Register x0
//              is hardwired to zero.
// Author: Srivibhav Jonnalagadda
// Date: 03-13-2026
// ------------------------------------------------------------
import Core_Cfg_pkg::*;

module Register_File (
    input  logic     clk_i,       // system clock
    input  logic     rst_i,       // Active high synchronous reset
    input  reg_idx_t SrcReg1_i,   // reg_idx_t-bit register ID for the first source register
    input  reg_idx_t SrcReg2_i,   // reg_idx_t-bit register ID for the second source register
    input  reg_idx_t DstReg_i,    // reg_idx_t-bit register ID for the destination register
    input  logic     WriteReg_i,  // enable writing to a register
    input  xlen_t    DstData_i,   // XLEN-bit data to be written to the destination register
    output xlen_t    SrcData1_o,  // read output of first source register
    output xlen_t    SrcData2_o   // read output of second source register
);

  /////////////////////////////////////////////////
  // Declare any internal signals as type wire  //
  ///////////////////////////////////////////////
  xlen_t regfile[REG_COUNT];  // xlen_t x REG_COUNT register file
  xlen_t DstData_operand;  // Data to write to a register
  //////////////////////////////////////////////////////////////////

  //////////////////////////////
  // Implement Register_File //
  ////////////////////////////
  // Hardcode register 0 to always hold 32'h0000_0000.
  assign DstData_operand = (DstReg_i == '0) ? '0 : DstData_i;

  // Alllow for RF-bypassing by checking if the source register matches the destination register and if a write is enabled.
  assign SrcData1_o = (WriteReg_i && (DstReg_i == SrcReg1_i)) ? DstData_operand : regfile[SrcReg1_i];
  assign SrcData2_o = (WriteReg_i && (DstReg_i == SrcReg2_i)) ? DstData_operand : regfile[SrcReg2_i];

  // Synchronously write to the regfile.
  always_ff @(posedge clk_i) begin
    if (rst_i) begin
      regfile <= '{default: '0};
    end else if (WriteReg_i) begin
      regfile[DstReg_i] <= DstData_operand;
    end
  end

endmodule
