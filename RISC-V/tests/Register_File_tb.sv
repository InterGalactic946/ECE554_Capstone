// ------------------------------------------------------------
// Testbench: Register_File_tb
// Description: Testbench for the register file. Verifies
//              correct read/write behavior and ensures
//              register x0 remains hardwired to zero.
// Author: Srivibhav Jonnalagadda
// Date: 03-13-2026
// ------------------------------------------------------------
import Core_Cfg_pkg::*;

module Register_File_tb ();

  // Calculate the total stimulus width based on the fields needed for testing.
  localparam int STIM_W = XLEN + (3 * REG_ADDR_W) + 1;

  localparam int WEN_BIT = 0;  // Bit position of the write enable signal in the stimulus vector

  localparam int DST_LO  = 1; // Bit position of the destination register index in the stimulus vector
  localparam int DST_HI  = DST_LO + REG_ADDR_W - 1; // Bit position of the destination register index in the stimulus vector

  localparam int SRC2_LO = DST_HI + 1; // Bit position of the second source register index in the stimulus vector
  localparam int SRC2_HI = SRC2_LO + REG_ADDR_W - 1; // Bit position of the second source register index in the stimulus vector

  localparam int SRC1_LO = SRC2_HI + 1; // Bit position of the first source register index in the stimulus vector
  localparam int SRC1_HI = SRC1_LO + REG_ADDR_W - 1; // Bit position of the first source register index in the stimulus vector

  localparam int DATA_LO = SRC1_HI + 1; // Bit position of the data to be written in the stimulus vector
  localparam int DATA_HI = DATA_LO + XLEN - 1; // Bit position of the data to be written in the stimulus vector

  logic [STIM_W-1:0] stim;  // stimulus vector of type reg
  logic clk, rst;  // system clock and active high synchronous reset
  xlen_t src_data_1;  // source data of first register
  xlen_t src_data_2;  // source data of second register
  xlen_t regfile[REG_COUNT];  // expected register file contents
  logic wen;  // write enable
  logic [16:0] read_operations;  // number of read operations performed
  logic [16:0] write_operations;  // number of write operations performed
  logic error;  // set an error flag on error
  logic [$clog2(REG_COUNT):0] i;  // loop variable

  //////////////////////
  // Instantiate DUT //
  ////////////////////
  Register_File iDUT (
      .clk_i(clk),
      .rst_i(rst),
      .SrcReg1_i(stim[SRC1_HI:SRC1_LO]),
      .SrcReg2_i(stim[SRC2_HI:SRC2_LO]),
      .DstReg_i(stim[DST_HI:DST_LO]),
      .WriteReg_i(wen),
      .DstData_i(stim[DATA_HI:DATA_LO]),
      .SrcData1_o(src_data_1),
      .SrcData2_o(src_data_2)
  );

  task automatic read_write_reg(input reg_idx_t reg_read1,  // First register to read from
                                input reg_idx_t reg_read2,  // Second register to read from
                                input reg_idx_t reg_write,  // Register to write to
                                input xlen_t write_data,  // Data to be written
                                input logic enable_write    // Write enable signal
  );
    begin
      @(negedge clk);

      // Set the stimulus values
      wen = enable_write;  // Enable or disable write

      @(posedge clk);

      // Check slightly after positive edge of clock.
      #1;

      // If writing is enabled, update expected register file contents
      if (enable_write && reg_write !== '0) begin
        regfile[reg_write] = write_data;  // Write only if not register 0
      end

      // Verify read outputs with bypassing check
      if (reg_read1 === reg_write && enable_write) begin
        if (reg_read1 !== '0) begin
          // Bypassing case: read register is same as write register
          if (src_data_1 !== write_data) begin
            $display("ERROR: Bypassing failed for SrcReg1[%d]. Expected 0x%h, got 0x%h", reg_read1,
                     write_data, src_data_1);
            error = 1'b1;
          end
        end else begin
          // If register 0, should always be 0
          if (src_data_1 !== '0) begin
            $display("ERROR: x0 read failure for SrcReg1. Expected 0x00000000, got 0x%h",
                     src_data_1);
            error = 1'b1;
          end
        end
      end else begin
        // Normal read case: Check against register file contents
        if (reg_read1 !== '0) begin
          if (src_data_1 !== regfile[reg_read1]) begin
            $display("ERROR: Reading from SrcReg1[%d] expected 0x%h, got 0x%h", reg_read1,
                     regfile[reg_read1], src_data_1);
            error = 1'b1;
          end
        end else begin
          // If register 0, should always be 0
          if (src_data_1 !== '0) begin
            $display("ERROR: x0 read failure for SrcReg1. Expected 0x00000000, got 0x%h",
                     src_data_1);
            error = 1'b1;
          end
        end
      end

      // Verify read outputs with bypassing check
      if (reg_read2 === reg_write && enable_write) begin
        if (reg_read2 !== '0) begin
          // Bypassing case: read register is same as write register
          if (src_data_2 !== write_data) begin
            $display("ERROR: Bypassing failed for SrcReg2[%d]. Expected 0x%h, got 0x%h", reg_read2,
                     write_data, src_data_2);
            error = 1'b1;
          end
        end else begin
          // If register 0, should always be 0
          if (src_data_2 !== '0) begin
            $display("ERROR: x0 read failure for SrcReg2. Expected 0x00000000, got 0x%h",
                     src_data_2);
            error = 1'b1;
          end
        end
      end else begin
        // Normal read case: Check against register file contents
        if (reg_read2 !== '0) begin
          if (src_data_2 !== regfile[reg_read2]) begin
            $display("ERROR: Reading from SrcReg2[%d] expected 0x%h, got 0x%h", reg_read2,
                     regfile[reg_read2], src_data_2);
            error = 1'b1;
          end
        end else begin
          // If register 0, should always be 0
          if (src_data_2 !== '0) begin
            $display("ERROR: x0 read failure for SrcReg2. Expected 0x00000000, got 0x%h",
                     src_data_2);
            error = 1'b1;
          end
        end
      end

      // Count successful operations if no errors occurred
      if (!error) begin
        read_operations = read_operations + 1'b1;
        read_operations = read_operations + 1'b1;
        if (enable_write) write_operations = write_operations + 1'b1;
      end

      // Print error and stop simulation if any errors occurred
      if (error) begin
        $display("\nTotal operations performed: 0x%h.", read_operations + write_operations);
        $display("Number of Successful Reads Performed: 0x%h.", read_operations);
        $display("Number of Successful Writes Performed: 0x%h.", write_operations);
        $stop();
      end

      // Disable write
      @(negedge clk) wen = 1'b0;
    end
  endtask

  // Initialize the inputs and expected outputs and wait till all tests finish.
  initial begin
    clk = 1'b0;  // initially clk is low
    rst = 1'b0;  // initally rst is low
    i = '0;  // initialize loop variable
    wen = 1'b0;  // initialize write enable
    stim = '0;  // initialize stimulus'
    regfile = '{default: '0};  // initialize the register file
    read_operations = 17'h00000;  // initialize read operation count
    write_operations = 17'h00000;  // initialize write operation count
    error = 1'b0;  // initialize error flag

    // Wait to initialize inputs.
    repeat (2) @(posedge clk);

    // Wait for a negative edge to assert rst.
    @(negedge clk) rst = 1'b1;

    // Wait for a full clock cycle before deasserting rst.
    @(negedge clk) rst = 1'b0;

    /* TEST CASE 1*/
    // Check that all registers have zero values initially.
    // Check all REG_COUNT register values, reading out of both bitlines.
    for (i = '0; i < REG_COUNT; i = i + 1) begin
      // Set both source register ids.
      stim[SRC1_HI:SRC1_LO] = i;
      stim[SRC2_HI:SRC2_LO] = i;

      // Wait a while for each check.
      #1

      // Ensure both bitlines have the correct value.
      read_write_reg(
          .reg_read1(stim[SRC1_HI:SRC1_LO]),
          .reg_read2(stim[SRC2_HI:SRC2_LO]),
          .reg_write('0),
          .write_data('0),
          .enable_write(1'b0));

      $display("Checked initial value of register %0d: SrcData1=0x%h, SrcData2=0x%h", i,
               src_data_1, src_data_2);
    end

    /* TEST CASE 2*/
    // Check that trying to write to register zero with a random value will have no effect.
    read_write_reg(.reg_read1('0), .reg_read2('0), .reg_write('0), .write_data('1),
                   .enable_write(1'b1));

    // Apply stimulus as 100000 random input vectors.
    repeat (100000) begin
      stim = $urandom;

      // Wait to process the change in the input.
      #1;

      // Perform 2 reads and a write each clock cycle.
      read_write_reg(.reg_read1(stim[SRC1_HI:SRC1_LO]), .reg_read2(stim[SRC2_HI:SRC2_LO]),
                     .reg_write(stim[DST_HI:DST_LO]), .write_data(stim[DATA_HI:DATA_LO]),
                     .enable_write(stim[WEN_BIT]));
    end

    // Print out the number of oprations performed.
    $display("\nTotal operations performed: 0x%h.", read_operations + write_operations);
    $display("Number of Successful Reads Performed: 0x%h.", read_operations);
    $display("Number of Successful Writes Performed: 0x%h.", write_operations);

    // If we reached here, it means that all tests passed.
    $display("YAHOO!! All tests passed.");
    $stop();
  end

  always #5 clk = ~clk;  // toggle clock every 5 time units.

endmodule
