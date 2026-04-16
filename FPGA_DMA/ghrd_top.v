// ============================================================================
// Copyright (c) 2013 by Terasic Technologies Inc.
// ============================================================================
//
// Permission:
//
//   Terasic grants permission to use and modify this code for use
//   in synthesis for all Terasic Development Boards and Altera Development 
//   Kits made by Terasic.  Other use of this code, including the selling 
//   ,duplication, or modification of any portion is strictly prohibited.
//
// Disclaimer:
//
//   This VHDL/Verilog or C/C++ source code is intended as a design reference
//   which illustrates how these types of functions can be implemented.
//   It is the user's responsibility to verify their design for
//   consistency and functionality through the use of formal
//   verification methods.  Terasic provides no warranty regarding the use 
//   or functionality of this code.
//
// ============================================================================
//           
//  Terasic Technologies Inc
//  9F., No.176, Sec.2, Gongdao 5th Rd, East Dist, Hsinchu City, 30070. Taiwan
//  
//  
//                     web: http://www.terasic.com/  
//                     email: support@terasic.com
//
// ============================================================================
//Date:  Mon Jun 17 20:35:29 2013
// ============================================================================

`define ENABLE_HPS

module ghrd_top(

//VERSÃO COM O CLOCK DO HPS ALTERADA PARA 925.
//NECESSÁRIO ALTERAR NO QSYS PARA 800, GERAR O HDL, E ACTUALIZA-LO NESTE DESIGN


      ///////// ADC /////////
      inout              ADC_CS_N,
      output             ADC_DIN,
      input              ADC_DOUT,
      output             ADC_SCLK,

      ///////// AUD /////////
      input              AUD_ADCDAT,
      inout              AUD_ADCLRCK,
      inout              AUD_BCLK,
      output             AUD_DACDAT,
      inout              AUD_DACLRCK,
      output             AUD_XCK,

      ///////// CLOCK2 /////////
      input              CLOCK2_50,

      ///////// CLOCK3 /////////
      input              CLOCK3_50,

      ///////// CLOCK4 /////////
      input              CLOCK4_50,

      ///////// CLOCK /////////
      input              CLOCK_50,

      ///////// DRAM /////////
      output      [12:0] DRAM_ADDR,
      output      [1:0]  DRAM_BA,
      output             DRAM_CAS_N,
      output             DRAM_CKE,
      output             DRAM_CLK,
      output             DRAM_CS_N,
      inout       [15:0] DRAM_DQ,
      output             DRAM_LDQM,
      output             DRAM_RAS_N,
      output             DRAM_UDQM,
      output             DRAM_WE_N,

      ///////// FAN /////////
      output             FAN_CTRL,

      ///////// FPGA /////////
      output             FPGA_I2C_SCLK,
      inout              FPGA_I2C_SDAT,

      ///////// GPIO /////////
      inout     [35:0]         GPIO_0,
      inout     [35:0]         GPIO_1,
 

      ///////// HEX0 /////////
      output   reg   [6:0]  HEX0,

      ///////// HEX1 /////////
      output   reg   [6:0]  HEX1,

      ///////// HEX2 /////////
      output   reg  [6:0]  HEX2,

      ///////// HEX3 /////////
      output   reg   [6:0]  HEX3,

      ///////// HEX4 /////////
      output   reg   [6:0]  HEX4,

      ///////// HEX5 /////////
      output   reg   [6:0]  HEX5,

`ifdef ENABLE_HPS
      ///////// HPS /////////
      inout              HPS_CONV_USB_N,
      output      [14:0] HPS_DDR3_ADDR,
      output      [2:0]  HPS_DDR3_BA,
      output             HPS_DDR3_CAS_N,
      output             HPS_DDR3_CKE,
      output             HPS_DDR3_CK_N,
      output             HPS_DDR3_CK_P,
      output             HPS_DDR3_CS_N,
      output      [3:0]  HPS_DDR3_DM,
      inout       [31:0] HPS_DDR3_DQ,
      inout       [3:0]  HPS_DDR3_DQS_N,
      inout       [3:0]  HPS_DDR3_DQS_P,
      output             HPS_DDR3_ODT,
      output             HPS_DDR3_RAS_N,
      output             HPS_DDR3_RESET_N,
      input              HPS_DDR3_RZQ,
      output             HPS_DDR3_WE_N,
      output             HPS_ENET_GTX_CLK,
      inout              HPS_ENET_INT_N,
      output             HPS_ENET_MDC,
      inout              HPS_ENET_MDIO,
      input              HPS_ENET_RX_CLK,
      input       [3:0]  HPS_ENET_RX_DATA,
      input              HPS_ENET_RX_DV,
      output      [3:0]  HPS_ENET_TX_DATA,
      output             HPS_ENET_TX_EN,
      inout       [3:0]  HPS_FLASH_DATA,
      output             HPS_FLASH_DCLK,
      output             HPS_FLASH_NCSO,
      inout              HPS_GSENSOR_INT,
      inout              HPS_I2C1_SCLK,
      inout              HPS_I2C1_SDAT,
      inout              HPS_I2C2_SCLK,
      inout              HPS_I2C2_SDAT,
      inout              HPS_I2C_CONTROL,
      inout              HPS_KEY,
      inout              HPS_LED,
      inout              HPS_LTC_GPIO,
      output             HPS_SD_CLK,
      inout              HPS_SD_CMD,
      inout       [3:0]  HPS_SD_DATA,
      output             HPS_SPIM_CLK,
      input              HPS_SPIM_MISO,
      output             HPS_SPIM_MOSI,
      inout              HPS_SPIM_SS,
      input              HPS_UART_RX,
      output             HPS_UART_TX,
      input              HPS_USB_CLKOUT,
      inout       [7:0]  HPS_USB_DATA,
      input              HPS_USB_DIR,
      input              HPS_USB_NXT,
      output             HPS_USB_STP,
`endif /*ENABLE_HPS*/

      ///////// IRDA /////////
      input              IRDA_RXD,
      output             IRDA_TXD,

      ///////// KEY /////////
      input       [3:0]  KEY,

      ///////// LEDR /////////
      output      [9:0]  LEDR,

      ///////// PS2 /////////
      inout              PS2_CLK,
      inout              PS2_CLK2,
      inout              PS2_DAT,
      inout              PS2_DAT2,

      ///////// SW /////////
      input       [9:0]  SW,

      ///////// TD /////////
      input              TD_CLK27,
      input      [7:0]  TD_DATA,
      input             TD_HS,
      output             TD_RESET_N,
      input             TD_VS,


      ///////// VGA /////////
      output      [7:0]  VGA_B,
      output             VGA_BLANK_N,
      output             VGA_CLK,
      output      [7:0]  VGA_G,
      output             VGA_HS,
      output      [7:0]  VGA_R,
      output             VGA_SYNC_N,
      output             VGA_VS
);



// internal wires and registers declaration
  wire [3:0]  fpga_debounced_buttons;
  wire [9:0]  fpga_led_internal;
  wire        hps_fpga_reset_n;
  wire [2:0]  hps_reset_req;
  wire        hps_cold_reset;
  wire        hps_warm_reset;
  wire        hps_debug_reset;
  wire [27:0] stm_hw_events;
  
   wire [31:0]pio_controlled_axi_signals;

// local parameters
  localparam AWCACHE_BASE = 0;
  localparam AWCACHE_SIZE = 4;
  localparam AWPROT_BASE  = 4;
  localparam AWPROT_SIZE  = 3;
  localparam AWUSER_BASE  = 7;
  localparam AWUSER_SIZE  = 5;
  localparam ARCACHE_BASE = 16;
  localparam ARCACHE_SIZE = 4;
  localparam ARPROT_BASE  = 20;
  localparam ARPROT_SIZE  = 3;
  localparam ARUSER_BASE  = 23;
  localparam ARUSER_SIZE  = 5;

// connection of internal logics
//  assign LEDR = fpga_led_internal;
  assign stm_hw_events    = {{3{1'b0}},SW, fpga_led_internal, fpga_debounced_buttons};
    // FIFO Interface wires
  wire [127:0] fifo_write_data;
  wire         fifo_write_en;
  wire         fifo_waitreq;

  // Acquisition control from HPS
  wire [7:0]  data_cntrl;
  wire        ps_ready_for_data;
  assign ps_ready_for_data = data_cntrl[0]; // Using bit 0 as the trigger

  soc_system u0 (
        // Memory Interface
        .memory_mem_a                          ( HPS_DDR3_ADDR),
        .memory_mem_ba                         ( HPS_DDR3_BA),
        .memory_mem_ck                         ( HPS_DDR3_CK_P),
        .memory_mem_ck_n                       ( HPS_DDR3_CK_N),
        .memory_mem_cke                        ( HPS_DDR3_CKE),
        .memory_mem_cs_n                       ( HPS_DDR3_CS_N),
        .memory_mem_ras_n                      ( HPS_DDR3_RAS_N),
        .memory_mem_cas_n                      ( HPS_DDR3_CAS_N),
        .memory_mem_we_n                       ( HPS_DDR3_WE_N),
        .memory_mem_reset_n                    ( HPS_DDR3_RESET_N),
        .memory_mem_dq                         ( HPS_DDR3_DQ),
        .memory_mem_dqs                        ( HPS_DDR3_DQS_P),
        .memory_mem_dqs_n                      ( HPS_DDR3_DQS_N),
        .memory_mem_odt                        ( HPS_DDR3_ODT),
        .memory_mem_dm                         ( HPS_DDR3_DM),
        .memory_oct_rzqin                      ( HPS_DDR3_RZQ),

        // HPS Peripherals (Ethernet, USB, etc.)
        .hps_0_hps_io_hps_io_emac1_inst_TX_CLK ( HPS_ENET_GTX_CLK),
        .hps_0_hps_io_hps_io_emac1_inst_TXD0   ( HPS_ENET_TX_DATA[0] ),
        .hps_0_hps_io_hps_io_emac1_inst_TXD1   ( HPS_ENET_TX_DATA[1] ),
        .hps_0_hps_io_hps_io_emac1_inst_TXD2   ( HPS_ENET_TX_DATA[2] ),
        .hps_0_hps_io_hps_io_emac1_inst_TXD3   ( HPS_ENET_TX_DATA[3] ),
        .hps_0_hps_io_hps_io_emac1_inst_RXD0   ( HPS_ENET_RX_DATA[0] ),
        .hps_0_hps_io_hps_io_emac1_inst_MDIO   ( HPS_ENET_MDIO ),
        .hps_0_hps_io_hps_io_emac1_inst_MDC    ( HPS_ENET_MDC  ),
        .hps_0_hps_io_hps_io_emac1_inst_RX_CTL ( HPS_ENET_RX_DV),
        .hps_0_hps_io_hps_io_emac1_inst_TX_CTL ( HPS_ENET_TX_EN),
        .hps_0_hps_io_hps_io_emac1_inst_RX_CLK ( HPS_ENET_RX_CLK),
        .hps_0_hps_io_hps_io_emac1_inst_RXD1   ( HPS_ENET_RX_DATA[1] ),
        .hps_0_hps_io_hps_io_emac1_inst_RXD2   ( HPS_ENET_RX_DATA[2] ),
        .hps_0_hps_io_hps_io_emac1_inst_RXD3   ( HPS_ENET_RX_DATA[3] ),
        .hps_0_hps_io_hps_io_qspi_inst_IO0     ( HPS_FLASH_DATA[0] ),
        .hps_0_hps_io_hps_io_qspi_inst_IO1     ( HPS_FLASH_DATA[1] ),
        .hps_0_hps_io_hps_io_qspi_inst_IO2     ( HPS_FLASH_DATA[2] ),
        .hps_0_hps_io_hps_io_qspi_inst_IO3     ( HPS_FLASH_DATA[3] ),
        .hps_0_hps_io_hps_io_qspi_inst_SS0     ( HPS_FLASH_NCSO ),
        .hps_0_hps_io_hps_io_qspi_inst_CLK     ( HPS_FLASH_DCLK ),
        .hps_0_hps_io_hps_io_sdio_inst_CMD     ( HPS_SD_CMD ),
        .hps_0_hps_io_hps_io_sdio_inst_D0      ( HPS_SD_DATA[0] ),
        .hps_0_hps_io_hps_io_sdio_inst_D1      ( HPS_SD_DATA[1] ),
        .hps_0_hps_io_hps_io_sdio_inst_CLK     ( HPS_SD_CLK ),
        .hps_0_hps_io_hps_io_sdio_inst_D2      ( HPS_SD_DATA[2] ),
        .hps_0_hps_io_hps_io_sdio_inst_D3      ( HPS_SD_DATA[3] ),
        .hps_0_hps_io_hps_io_usb1_inst_D0      ( HPS_USB_DATA[0] ),
        .hps_0_hps_io_hps_io_usb1_inst_D1      ( HPS_USB_DATA[1] ),
        .hps_0_hps_io_hps_io_usb1_inst_D2      ( HPS_USB_DATA[2] ),
        .hps_0_hps_io_hps_io_usb1_inst_D3      ( HPS_USB_DATA[3] ),
        .hps_0_hps_io_hps_io_usb1_inst_D4      ( HPS_USB_DATA[4] ),
        .hps_0_hps_io_hps_io_usb1_inst_D5      ( HPS_USB_DATA[5] ),
        .hps_0_hps_io_hps_io_usb1_inst_D6      ( HPS_USB_DATA[6] ),
        .hps_0_hps_io_hps_io_usb1_inst_D7      ( HPS_USB_DATA[7] ),
        .hps_0_hps_io_hps_io_usb1_inst_CLK     ( HPS_USB_CLKOUT ),
        .hps_0_hps_io_hps_io_usb1_inst_STP     ( HPS_USB_STP ),
        .hps_0_hps_io_hps_io_usb1_inst_DIR     ( HPS_USB_DIR ),
        .hps_0_hps_io_hps_io_usb1_inst_NXT     ( HPS_USB_NXT ),
        .hps_0_hps_io_hps_io_spim1_inst_CLK    ( HPS_SPIM_CLK ),
        .hps_0_hps_io_hps_io_spim1_inst_MOSI   ( HPS_SPIM_MOSI ),
        .hps_0_hps_io_hps_io_spim1_inst_MISO   ( HPS_SPIM_MISO ),
        .hps_0_hps_io_hps_io_spim1_inst_SS0    ( HPS_SPIM_SS ),
        .hps_0_hps_io_hps_io_uart0_inst_RX     ( HPS_UART_RX ),
        .hps_0_hps_io_hps_io_uart0_inst_TX     ( HPS_UART_TX ),
        .hps_0_hps_io_hps_io_i2c0_inst_SDA     ( HPS_I2C1_SDAT ),
        .hps_0_hps_io_hps_io_i2c0_inst_SCL     ( HPS_I2C1_SCLK ),
        .hps_0_hps_io_hps_io_i2c1_inst_SDA     ( HPS_I2C2_SDAT ),
        .hps_0_hps_io_hps_io_i2c1_inst_SCL     ( HPS_I2C2_SCLK ),
        .hps_0_hps_io_hps_io_gpio_inst_GPIO09  ( HPS_CONV_USB_N),
        .hps_0_hps_io_hps_io_gpio_inst_GPIO35  ( HPS_ENET_INT_N),
        .hps_0_hps_io_hps_io_gpio_inst_GPIO40  ( HPS_LTC_GPIO),
        .hps_0_hps_io_hps_io_gpio_inst_GPIO48  ( HPS_I2C_CONTROL),
        .hps_0_hps_io_hps_io_gpio_inst_GPIO53  ( HPS_LED),
        .hps_0_hps_io_hps_io_gpio_inst_GPIO54  ( HPS_KEY),
        .hps_0_hps_io_hps_io_gpio_inst_GPIO61  ( HPS_GSENSOR_INT),

        // System Control and Resets
        .clk_clk                               (CLOCK_50),
        .reset_reset_n                         (hps_fpga_reset_n),
        .hps_0_f2h_stm_hw_events_stm_hwevents  (stm_hw_events),
	.hps_0_h2f_reset_reset_n(hps_fpga_reset_n),
        // AXI Coherency Signals
        .mcu_axi_signals_export                (pio_controlled_axi_signals),
        .axi_signals_awcache                   (pio_controlled_axi_signals[AWCACHE_BASE+:AWCACHE_SIZE]),
        .axi_signals_awprot                    (pio_controlled_axi_signals[AWPROT_BASE+: AWPROT_SIZE]),
        .axi_signals_awuser                    (pio_controlled_axi_signals[AWUSER_BASE+: AWUSER_SIZE]),
        .axi_signals_arcache                   (pio_controlled_axi_signals[ARCACHE_BASE+:ARCACHE_SIZE]),
        .axi_signals_aruser                    (pio_controlled_axi_signals[ARUSER_BASE+: ARUSER_SIZE]),
        .axi_signals_arprot                    (pio_controlled_axi_signals[ARPROT_BASE+: ARPROT_SIZE]),

        // New FIFO Interface
        .fifo_in_writedata                     (fifo_write_data),
        .fifo_in_write                         (fifo_write_en),
        .fifo_in_waitrequest                   (fifo_waitreq),

        // New Control Signal
        .data_cntrl_export                     (data_cntrl)
    );

    assign LEDR[9] = fifo_waitreq;
    assign LEDR[8] = ps_ready_for_data;
    assign LEDR[7] = mic1_valid && mic3_valid; // Both mics have valid data
    assign LEDR[6] = mic2_valid && mic4_valid; // Both mics have valid data
    assign LEDR[5] = pos_neg_valid; // Cross-validity (should not ever happen)
    assign LEDR[0] = rst; // Show reset state on LEDR[0]

    reg pos_neg_valid;

    always @(posedge CLOCK_50, posedge rst) begin
      if (rst) begin
        pos_neg_valid <= 1'b0;
      end else if ((mic1_valid && mic4_valid) || (mic2_valid && mic3_valid) || (mic1_valid && mic2_valid) || (mic3_valid && mic4_valid)) begin
        pos_neg_valid <= 1'b1;
      end else if (~fpga_debounced_buttons[1]) begin
        pos_neg_valid <= 1'b0;
      end
    end

  // Debounce logic to clean out glitches within 1ms
  debounce debounce_inst (
    .clk                                  (CLOCK3_50),
    .reset_n                              (hps_fpga_reset_n),  
    .data_in                              (KEY),
    .data_out                             (fpga_debounced_buttons)
  );

  wire rst;
  wire [1:0] curr_mode;
  wire pdm_in1, pdm_in2;
  wire data_val; 
  wire [15:0] mic1_pcm, mic2_pcm, mic3_pcm, mic4_pcm;
  wire mic1_valid, mic2_valid, mic3_valid, mic4_valid;

  assign pdm_in1 = data_val ? GPIO_0[1] : 1'b0;
  assign pdm_in2 = data_val ? GPIO_0[2] : 1'b0;

  // Active high synchronous reset.
  assign rst = ~fpga_debounced_buttons[0];

  // We don't care about the remaining GPIO pins.
  assign GPIO_0[35:3] = 32'hzzzz;

  // Instatiate the Audio Front End.
  Audio_Front_End iAUD_FRONT (
      .clk_i(CLOCK_50),
      .rst_i(rst),
      .mode_req_i(SW[1:0]),
      .en_adc_i(~SW[2]), // Default ADC on
      .ADC_data_out_i(ADC_DOUT),
      .ADC_SCLK_o(ADC_SCLK),
      .ADC_CS_o(ADC_CS_N),
      .ADC_data_in_o(ADC_DIN),

      .curr_mode_o(curr_mode),
      .data_val_o (data_val),
      .mic_clk_o  (GPIO_0[0])
  );

  PCM_no_comp iPDM_PCM_1 (
    .clk(CLOCK_50),
    .mic_clk(GPIO_0[0]),
    .dec_mode(SW[4:3]),
    .rst_n(~rst),
    .mic_raw(pdm_in1),
    .pcm_valid_pos(mic1_valid),
    .pcm_valid_neg(mic2_valid),
    .pcm_pos(mic1_pcm),
    .pcm_neg(mic2_pcm)
  );

  PCM_no_comp iPDM_PCM_2 (
    .clk(CLOCK_50),
    .mic_clk(GPIO_0[0]),
    .dec_mode(SW[4:3]),
    .rst_n(~rst),
    .mic_raw(pdm_in2),
    .pcm_valid_pos(mic3_valid),
    .pcm_valid_neg(mic4_valid),
    .pcm_pos(mic3_pcm),
    .pcm_neg(mic4_pcm)
  );

  // Drive Mode (HEX0) manually
  always @(*) begin
    HEX0 = 7'b1111111;
    HEX1 = 7'b1111111;
    HEX2 = 7'b1111111;
    HEX3 = 7'b1111111;
    HEX4 = 7'b1111111;
    HEX5 = 7'b1111111;

    case (curr_mode)
      2'b00: HEX0 = 7'b1000000;  // 0
      2'b01: HEX0 = 7'b1111001;  // 1
      2'b10: HEX0 = 7'b0100100;  // 2
      2'b11: HEX0 = 7'b0110000;  // 3
      default: begin
        HEX0 = 7'b1111111;
        HEX1 = 7'b1111111;
        HEX2 = 7'b1111111;
        HEX3 = 7'b1111111;
        HEX4 = 7'b1111111;
        HEX5 = 7'b1111111;
      end
    endcase
  end

  wire [15:0] mock_data_1, mock_data_2, mock_data_3, mock_data_4;
  wire data_valid_1, data_valid_2, data_valid_3, data_valid_4;

  mock_data mock_data_inst_1 (
    .clk(CLOCK_50),
    .rst_n(~rst),
    .ready_for_data(ps_ready_for_data && mic1_valid), 
    .data_out(mock_data_1),
    .data_valid(data_valid_1),
  );

  mock_data mock_data_inst_2 (
    .clk(CLOCK_50),
    .rst_n(~rst),
    .ready_for_data(ps_ready_for_data && mic2_valid), 
    .data_out(mock_data_2),
    .data_valid(data_valid_2),
  );

    mock_data mock_data_inst_3 (
    .clk(CLOCK_50),
    .rst_n(~rst),
    .ready_for_data(ps_ready_for_data && mic3_valid), 
    .data_out(mock_data_3),
    .data_valid(data_valid_3),
  );

  mock_data mock_data_inst_4 (
    .clk(CLOCK_50),
    .rst_n(~rst),
    .ready_for_data(ps_ready_for_data && mic4_valid), 
    .data_out(mock_data_4),
    .data_valid(data_valid_4),
  );

  pcm_to_mem pcm_to_mem_inst (
    .clk(CLOCK_50),
    .rst_n(~rst),
    .pcm_pos_1(SW[9] ? mock_data_1 : mic1_pcm),
    .pcm_pos_valid_1(SW[9] ? data_valid_1 : mic1_valid),
    .pcm_neg_1(SW[9] ? mock_data_2 : mic2_pcm),
    .pcm_neg_valid_1(SW[9] ? data_valid_2 : mic2_valid),
    .pcm_pos_2(SW[9] ? mock_data_3 : mic3_pcm),
    .pcm_pos_valid_2(SW[9] ? data_valid_3 : mic3_valid),
    .pcm_neg_2(SW[9] ? mock_data_4 : mic4_pcm),
    .pcm_neg_valid_2(SW[9] ? data_valid_4 : mic4_valid),
    .ps_ready_for_data(ps_ready_for_data),
    .write_pending(fifo_waitreq),
    .write_en(fifo_write_en),
    .write_data(fifo_write_data)
  );

// Source/Probe megawizard instance
hps_reset hps_reset_inst (
  .source_clk (CLOCK_50),
  .source     (hps_reset_req)
);

endmodule

  
