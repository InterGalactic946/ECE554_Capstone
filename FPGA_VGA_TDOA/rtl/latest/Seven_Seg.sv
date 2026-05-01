// ------------------------------------------------------------
// Module: Seven_Seg
// Description: This module takes a 4-bit binary input and
//              converts it to a 7-segment display output.
// Author: Srivibhav Jonnalagadda
// Date: 04-06-2026
// ------------------------------------------------------------
module Seven_Seg (
    input  logic [4:0] bin_i,
    output logic [6:0] hex_o
);
  always_comb begin
    case (bin_i)
      5'h00: hex_o = 7'b1000000;
      5'h01: hex_o = 7'b1111001;
      5'h02: hex_o = 7'b0100100;
      5'h03: hex_o = 7'b0110000;
      5'h04: hex_o = 7'b0011001;
      5'h05: hex_o = 7'b0010010;
      5'h06: hex_o = 7'b0000010;
      5'h07: hex_o = 7'b1111000;
      5'h08: hex_o = 7'b0000000;
      5'h09: hex_o = 7'b0011000;
      5'h0A: hex_o = 7'b0001000;
      5'h0b: hex_o = 7'b0000011;
      5'h0C: hex_o = 7'b1000110;
      5'h0d: hex_o = 7'b0100001;
      5'h0E: hex_o = 7'b0000110;
      5'h0F: hex_o = 7'b0001110;
      5'h1F: hex_o = 7'b0111111;
      default: hex_o = 7'b1111111;
    endcase
  end
endmodule
