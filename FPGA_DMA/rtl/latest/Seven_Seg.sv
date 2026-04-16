// ------------------------------------------------------------
// Module: Seven_Seg
// Description: This module takes a 4-bit binary input and
//              converts it to a 7-segment display output.
// Author: Srivibhav Jonnalagadda
// Date: 04-06-2026
// ------------------------------------------------------------
module Seven_Seg (
    input  logic [3:0] bin_i,
    output logic [6:0] hex_o
);
  always_comb begin
    case (bin_i)
      4'h0: hex_o = 7'b1000000;
      4'h1: hex_o = 7'b1111001;
      4'h2: hex_o = 7'b0100100;
      4'h3: hex_o = 7'b0110000;
      4'h4: hex_o = 7'b0011001;
      4'h5: hex_o = 7'b0110010;
      4'h6: hex_o = 7'b0100010;
      4'h7: hex_o = 7'b1111000;
      4'h8: hex_o = 7'b0000000;
      4'h9: hex_o = 7'b0011000;
      4'hA: hex_o = 7'b0001000;
      4'hb: hex_o = 7'b0000011;
      4'hC: hex_o = 7'b1000110;
      4'hd: hex_o = 7'b0100001;
      4'hE: hex_o = 7'b0000110;
      4'hF: hex_o = 7'b0001110;
      default: hex_o = 7'b1111111;
    endcase
  end
endmodule
