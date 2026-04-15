`include "fixed.sv"

module audio_codec #(
    parameter WINDOW_SIZE = 1024,
    parameter WBITS = $clog2(WINDOW_SIZE)  
) (
    input clk,
    input rst,

    input [15:0] pcm_data,
    input pcm_valid,
    input en_dac,

    // CODEC FACING IO
    input i_aud_adcdat,
    output o_aud_dacdat,
    output o_aud_bclk,
    output o_aud_xck,
    output o_aud_lrck,
    output o_fpga_i2c_sclk,
    output o_fpga_i2c_sdat,

    // FPGA FACING IO
    input [9:0] SW,
    output [9:0] LEDR
);

// ----------------------------------------------------------------
// Internal Signals and logic
// ----------------------------------------------------------------

// Audio control status signals 
logic config_done, config_err;

// Input data normalization
audio_t ldata, rdata;
logic [31:0] adc_data;
assign ldata = signed'(adc_data[31:16]);
assign rdata = signed'(adc_data[15:0]);

// PSOLA outputs (left and right channels)


// FIFO read logic
logic adc_en, adc_empty;
assign adc_en = !adc_empty;

// FIFO write logic
logic dac_en, dac_full;
logic [31:0] dac_data;
assign dac_en = en_dac && pcm_valid;
assign dac_data = {pcm_data, pcm_data};

// pitch period signals
logic [9:0] pitch_period;
logic pitch_valid;
logic pitch_done;

// ----------------------------------------------------------------
// Audio Control
// ----------------------------------------------------------------
audio_cntrl #(
    .P24_BIT(0)
) iAUD_CNTRL (
    .i_clk_50M(clk),
    .i_rst(rst),
    .i_data(dac_data),
    .i_fifo_wr_en(dac_en),
    .i_fifo_rd_en(adc_en),
    .o_read_empty(adc_empty),
    .o_write_full(dac_full),
    .o_data(adc_data),
    .o_config_err(config_err),
    .o_config_done(config_done),
    .i_aud_adcdat(i_aud_adcdat),
    .o_aud_dacdat(o_aud_dacdat),
    .o_bck(o_aud_bclk),
    .o_aud_lrck(o_aud_lrck),
    .o_aud_xck(o_aud_xck),
    .o_i2c_sclk(o_fpga_i2c_sclk),
    .o_i2c_sdat(o_fpga_i2c_sdat)
);

// ----------------------------------------------------------------
// FPGA IO Control 
// ----------------------------------------------------------------
assign LEDR[0] = config_done;
assign LEDR[1] = config_err;
assign LEDR[2] = pitch_valid;
assign LEDR[3] = adc_empty;
assign LEDR[4] = dac_full;
// assign LEDR[7] = adc_empty;
// assign LEDR[8] = dac_full;
assign LEDR[9] = rst;
endmodule
