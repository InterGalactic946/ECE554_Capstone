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
      5'h0: hex_o = 7'b1000000;
      5'h1: hex_o = 7'b1111001;
      5'h2: hex_o = 7'b0100100;
      5'h3: hex_o = 7'b0110000;
      5'h4: hex_o = 7'b0011001;
      5'h5: hex_o = 7'b0110010;
      5'h6: hex_o = 7'b0100010;
      5'h7: hex_o = 7'b1111000;
      5'h8: hex_o = 7'b0000000;
      5'h9: hex_o = 7'b0011000;
      5'hA: hex_o = 7'b0001000;
      5'hb: hex_o = 7'b0000011;
      5'hC: hex_o = 7'b1000110;
      5'hd: hex_o = 7'b0100001;
      5'hE: hex_o = 7'b0000110;
      5'hF: hex_o = 7'b0001110;
      5'h1F: hex_o = 7'b0111111;
      default: hex_o = 7'b1111111;
    endcase
  end
endmodule
