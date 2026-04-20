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


// ------------------------------------------------------------
// Module: ghrd_top
// Description: Top-level integration for the DE1-SoC audio and
//              DMA pipeline. The design generates the shared
//              microphone clock, converts eight PDM GPIO lanes
//              into sixteen PCM streams, packs those streams
//              for DMA transfer to the HPS, and exposes one
//              selected stream on the HEX display path.
// Author(s): Terasic Technologies Inc. and ECE554 Capstone Team
// Date: 04-16-2026
// ------------------------------------------------------------
module ghrd_top (

    //VERSÃO COM O CLOCK DO HPS ALTERADA PARA 925.
    //NECESSÁRIO ALTERAR NO QSYS PARA 800, GERAR O HDL, E ACTUALIZA-LO NESTE DESIGN


    ///////// ADC /////////
    inout  ADC_CS_N,
    output ADC_DIN,
    input  ADC_DOUT,
    output ADC_SCLK,

    ///////// AUD /////////
    input  AUD_ADCDAT,
    inout  AUD_ADCLRCK,
    inout  AUD_BCLK,
    output AUD_DACDAT,
    inout  AUD_DACLRCK,
    output AUD_XCK,

    ///////// CLOCK2 /////////
    input CLOCK2_50,

    ///////// CLOCK3 /////////
    input CLOCK3_50,

    ///////// CLOCK4 /////////
    input CLOCK4_50,

    ///////// CLOCK /////////
    input CLOCK_50,

    ///////// DRAM /////////
    output [12:0] DRAM_ADDR,
    output [ 1:0] DRAM_BA,
    output        DRAM_CAS_N,
    output        DRAM_CKE,
    output        DRAM_CLK,
    output        DRAM_CS_N,
    inout  [15:0] DRAM_DQ,
    output        DRAM_LDQM,
    output        DRAM_RAS_N,
    output        DRAM_UDQM,
    output        DRAM_WE_N,

    ///////// FAN /////////
    output FAN_CTRL,

    ///////// FPGA /////////
    output FPGA_I2C_SCLK,
    inout  FPGA_I2C_SDAT,

    ///////// GPIO /////////
    inout [35:0] GPIO_0,
    inout [35:0] GPIO_1,


    ///////// HEX0 /////////
    output [6:0] HEX0,

    ///////// HEX1 /////////
    output [6:0] HEX1,

    ///////// HEX2 /////////
    output [6:0] HEX2,

    ///////// HEX3 /////////
    output [6:0] HEX3,

    ///////// HEX4 /////////
    output [6:0] HEX4,

    ///////// HEX5 /////////
    output [6:0] HEX5,

`ifdef ENABLE_HPS
    ///////// HPS /////////
    inout         HPS_CONV_USB_N,
    output [14:0] HPS_DDR3_ADDR,
    output [ 2:0] HPS_DDR3_BA,
    output        HPS_DDR3_CAS_N,
    output        HPS_DDR3_CKE,
    output        HPS_DDR3_CK_N,
    output        HPS_DDR3_CK_P,
    output        HPS_DDR3_CS_N,
    output [ 3:0] HPS_DDR3_DM,
    inout  [31:0] HPS_DDR3_DQ,
    inout  [ 3:0] HPS_DDR3_DQS_N,
    inout  [ 3:0] HPS_DDR3_DQS_P,
    output        HPS_DDR3_ODT,
    output        HPS_DDR3_RAS_N,
    output        HPS_DDR3_RESET_N,
    input         HPS_DDR3_RZQ,
    output        HPS_DDR3_WE_N,
    output        HPS_ENET_GTX_CLK,
    inout         HPS_ENET_INT_N,
    output        HPS_ENET_MDC,
    inout         HPS_ENET_MDIO,
    input         HPS_ENET_RX_CLK,
    input  [ 3:0] HPS_ENET_RX_DATA,
    input         HPS_ENET_RX_DV,
    output [ 3:0] HPS_ENET_TX_DATA,
    output        HPS_ENET_TX_EN,
    inout  [ 3:0] HPS_FLASH_DATA,
    output        HPS_FLASH_DCLK,
    output        HPS_FLASH_NCSO,
    inout         HPS_GSENSOR_INT,
    inout         HPS_I2C1_SCLK,
    inout         HPS_I2C1_SDAT,
    inout         HPS_I2C2_SCLK,
    inout         HPS_I2C2_SDAT,
    inout         HPS_I2C_CONTROL,
    inout         HPS_KEY,
    inout         HPS_LED,
    inout         HPS_LTC_GPIO,
    output        HPS_SD_CLK,
    inout         HPS_SD_CMD,
    inout  [ 3:0] HPS_SD_DATA,
    output        HPS_SPIM_CLK,
    input         HPS_SPIM_MISO,
    output        HPS_SPIM_MOSI,
    inout         HPS_SPIM_SS,
    input         HPS_UART_RX,
    output        HPS_UART_TX,
    input         HPS_USB_CLKOUT,
    inout  [ 7:0] HPS_USB_DATA,
    input         HPS_USB_DIR,
    input         HPS_USB_NXT,
    output        HPS_USB_STP,
`endif  /*ENABLE_HPS*/

    ///////// IRDA /////////
    input  IRDA_RXD,
    output IRDA_TXD,

    ///////// KEY /////////
    input [3:0] KEY,

    ///////// LEDR /////////
    output [9:0] LEDR,

    ///////// PS2 /////////
    inout PS2_CLK,
    inout PS2_CLK2,
    inout PS2_DAT,
    inout PS2_DAT2,

    ///////// SW /////////
    input [9:0] SW,

    ///////// TD /////////
    input        TD_CLK27,
    input  [7:0] TD_DATA,
    input        TD_HS,
    output       TD_RESET_N,
    input        TD_VS,


    ///////// VGA /////////
    output [7:0] VGA_B,
    output       VGA_BLANK_N,
    output       VGA_CLK,
    output [7:0] VGA_G,
    output       VGA_HS,
    output [7:0] VGA_R,
    output       VGA_SYNC_N,
    output       VGA_VS
);

  // Maps GPIO_0 correctly.
  function automatic int gpio0_map(input int hw_pin);
    begin
      case (hw_pin)

        1:  gpio0_map = 0;
        2:  gpio0_map = 1;
        3:  gpio0_map = 2;
        4:  gpio0_map = 3;
        5:  gpio0_map = 4;
        6:  gpio0_map = 5;
        7:  gpio0_map = 6;
        8:  gpio0_map = 7;
        9:  gpio0_map = 8;
        10: gpio0_map = 9;

        13: gpio0_map = 10;
        14: gpio0_map = 11;
        15: gpio0_map = 12;
        16: gpio0_map = 13;
        17: gpio0_map = 14;
        18: gpio0_map = 15;

        19: gpio0_map = 16;
        20: gpio0_map = 17;
        21: gpio0_map = 18;
        22: gpio0_map = 19;
        23: gpio0_map = 20;
        24: gpio0_map = 21;
        25: gpio0_map = 22;
        26: gpio0_map = 23;
        27: gpio0_map = 24;
        28: gpio0_map = 25;

        31: gpio0_map = 26;
        32: gpio0_map = 27;
        33: gpio0_map = 28;
        34: gpio0_map = 29;
        35: gpio0_map = 30;
        36: gpio0_map = 31;
        37: gpio0_map = 32;
        38: gpio0_map = 33;
        39: gpio0_map = 34;
        40: gpio0_map = 35;

        default: gpio0_map = -1;  // invalid
      endcase
    end
  endfunction

  /////////////////////////////////////////////////
  // Declare local parameters used in this module //
  /////////////////////////////////////////////////
  localparam AWCACHE_BASE = 0;
  localparam AWCACHE_SIZE = 4;
  localparam AWPROT_BASE = 4;
  localparam AWPROT_SIZE = 3;
  localparam AWUSER_BASE = 7;
  localparam AWUSER_SIZE = 5;
  localparam ARCACHE_BASE = 16;
  localparam ARCACHE_SIZE = 4;
  localparam ARPROT_BASE = 20;
  localparam ARPROT_SIZE = 3;
  localparam ARUSER_BASE = 23;
  localparam ARUSER_SIZE = 5;
  localparam integer NUM_PDM_LANES = 2;
  localparam integer NUM_MIC_STREAMS = NUM_PDM_LANES * 2;
  localparam integer PCM_SAMPLE_WIDTH = 16;
  localparam integer FRAME_WIDTH = NUM_MIC_STREAMS * PCM_SAMPLE_WIDTH;
  localparam integer MIC_CLK_GPIO_INDEX = (NUM_PDM_LANES == 8) ? gpio0_map(19) : gpio0_map(1);
  localparam integer PULSE_GEN_GPIO_INDEX = gpio0_map(6);
  localparam integer MIC_DATA_GPIO_INDEX[NUM_PDM_LANES] = '{2, 3};
  // (NUM_PDM_LANES == 8) ? '{4, 2, 8, 6, 36, 38, 34, 40}
  localparam integer STREAM_SEL_WIDTH = $clog2(NUM_MIC_STREAMS);
  // 50 MHz / 5,000,000 = 10 Hz display update rate.
  localparam integer DISPLAY_UPDATE_DIV = 5000000;

  ////////////////////////////////////////////////////
  // Declare system-control and status LED signals  //
  //////////////////////////////////////////////////
  wire [                 3:0] fpga_debounced_buttons;
  wire [                 9:0] fpga_led_internal;
  wire                        hps_fpga_reset_n;
  wire [                 2:0] hps_reset_req;
  wire                        hps_cold_reset;
  wire                        hps_warm_reset;
  wire                        hps_debug_reset;
  wire [                27:0] stm_hw_events;
  wire [                31:0] pio_controlled_axi_signals;

  /////////////////////////////////////////////////
  // Declare DMA and acquisition control signals //
  ///////////////////////////////////////////////
  wire [     FRAME_WIDTH-1:0] fifo_write_data;
  wire                        fifo_write_en;
  wire                        fifo_waitreq;
  wire [                 7:0] data_cntrl;
  reg                         ps_data_rdy_int;
  reg                         ps_data_rdy_stable;
  wire                        ps_ready_for_data;

  /////////////////////////////////////////////////
  // Declare audio-front-end control signals     //
  ///////////////////////////////////////////////
  wire                        clk_i;
  wire                        rst_i;
  wire                        mic_clk_o;
  wire                        mic_data_val;
  wire [                 1:0] curr_mode;
  wire [                 2:0] freq_sel;

  ///////////////////////////////////////////////////
  // Declare PDM-to-PCM and mock-test-path signals //
  /////////////////////////////////////////////////
  wire [PCM_SAMPLE_WIDTH-1:0] conv_pcm_pos               [  NUM_PDM_LANES];
  wire [PCM_SAMPLE_WIDTH-1:0] conv_pcm_neg               [  NUM_PDM_LANES];
  wire [   NUM_PDM_LANES-1:0] conv_pcm_valid_pos;
  wire [   NUM_PDM_LANES-1:0] conv_pcm_valid_neg;
  wire [   NUM_PDM_LANES-1:0] conv_pos_pcm_cap_rdy;
  wire [   NUM_PDM_LANES-1:0] conv_neg_pcm_cap_rdy;
  wire [   NUM_PDM_LANES-1:0] mic_data_gpio;
  wire [PCM_SAMPLE_WIDTH-1:0] conv_pcm                   [NUM_MIC_STREAMS];
  wire [ NUM_MIC_STREAMS-1:0] conv_pcm_valid;
  wire [PCM_SAMPLE_WIDTH-1:0] mock_pcm                   [NUM_MIC_STREAMS];
  wire [ NUM_MIC_STREAMS-1:0] mock_pcm_valid;
  wire [PCM_SAMPLE_WIDTH-1:0] active_pcm                 [NUM_MIC_STREAMS];
  wire [ NUM_MIC_STREAMS-1:0] active_pcm_valid;
  reg  [                 5:0] band_visual;

  /////////////////////////////////////////////////
  // Declare display FIFO and HEX output signals //
  ///////////////////////////////////////////////
  wire [STREAM_SEL_WIDTH-1:0] pcm_stream_sel;
  reg  [PCM_SAMPLE_WIDTH-1:0] fifo_data;
  reg                         fifo_pcm_valid;
  wire                        fifo_wrreq;
  wire                        fifo_rdreq;
  wire                        fifo_empty;
  wire                        fifo_full;
  wire                        clr_fifo;
  wire [                15:0] fifo_q;
  wire [                12:0] fifo_usedw;
  reg                         fifo_rdreq_q;
  reg  [                15:0] latest_fifo_sample;
  reg  [                15:0] display_sample;
  reg  [                22:0] display_div_cnt;

  /////////////////////////////////////////////////
  // Declare pulse generation signals signals   //
  ///////////////////////////////////////////////
  wire                        pulse;

  //////////////////////////////////////
  // System-control top-level assigns //
  ////////////////////////////////////
  assign stm_hw_events = {{3{1'b0}}, SW, fpga_led_internal, fpga_debounced_buttons};

  // Bit 0 of data_cntrl gates whether the FPGA is allowed to acquire and emit frames.
  assign ps_ready_for_data = ps_data_rdy_stable;

  // Status LEDs for reset and DMA backpressure visibility.
  assign LEDR[9:4] = band_visual;
  assign LEDR[2] = fifo_waitreq;
  assign LEDR[1] = ps_ready_for_data;
  assign LEDR[0] = rst_i;

  //////////////////////////////
  // System-control instances //
  ////////////////////////////
  soc_system u0 (
      // Memory Interface
      .memory_mem_a      (HPS_DDR3_ADDR),
      .memory_mem_ba     (HPS_DDR3_BA),
      .memory_mem_ck     (HPS_DDR3_CK_P),
      .memory_mem_ck_n   (HPS_DDR3_CK_N),
      .memory_mem_cke    (HPS_DDR3_CKE),
      .memory_mem_cs_n   (HPS_DDR3_CS_N),
      .memory_mem_ras_n  (HPS_DDR3_RAS_N),
      .memory_mem_cas_n  (HPS_DDR3_CAS_N),
      .memory_mem_we_n   (HPS_DDR3_WE_N),
      .memory_mem_reset_n(HPS_DDR3_RESET_N),
      .memory_mem_dq     (HPS_DDR3_DQ),
      .memory_mem_dqs    (HPS_DDR3_DQS_P),
      .memory_mem_dqs_n  (HPS_DDR3_DQS_N),
      .memory_mem_odt    (HPS_DDR3_ODT),
      .memory_mem_dm     (HPS_DDR3_DM),
      .memory_oct_rzqin  (HPS_DDR3_RZQ),

      // HPS Peripherals (Ethernet, USB, etc.)
      .hps_0_hps_io_hps_io_emac1_inst_TX_CLK(HPS_ENET_GTX_CLK),
      .hps_0_hps_io_hps_io_emac1_inst_TXD0  (HPS_ENET_TX_DATA[0]),
      .hps_0_hps_io_hps_io_emac1_inst_TXD1  (HPS_ENET_TX_DATA[1]),
      .hps_0_hps_io_hps_io_emac1_inst_TXD2  (HPS_ENET_TX_DATA[2]),
      .hps_0_hps_io_hps_io_emac1_inst_TXD3  (HPS_ENET_TX_DATA[3]),
      .hps_0_hps_io_hps_io_emac1_inst_RXD0  (HPS_ENET_RX_DATA[0]),
      .hps_0_hps_io_hps_io_emac1_inst_MDIO  (HPS_ENET_MDIO),
      .hps_0_hps_io_hps_io_emac1_inst_MDC   (HPS_ENET_MDC),
      .hps_0_hps_io_hps_io_emac1_inst_RX_CTL(HPS_ENET_RX_DV),
      .hps_0_hps_io_hps_io_emac1_inst_TX_CTL(HPS_ENET_TX_EN),
      .hps_0_hps_io_hps_io_emac1_inst_RX_CLK(HPS_ENET_RX_CLK),
      .hps_0_hps_io_hps_io_emac1_inst_RXD1  (HPS_ENET_RX_DATA[1]),
      .hps_0_hps_io_hps_io_emac1_inst_RXD2  (HPS_ENET_RX_DATA[2]),
      .hps_0_hps_io_hps_io_emac1_inst_RXD3  (HPS_ENET_RX_DATA[3]),
      .hps_0_hps_io_hps_io_qspi_inst_IO0    (HPS_FLASH_DATA[0]),
      .hps_0_hps_io_hps_io_qspi_inst_IO1    (HPS_FLASH_DATA[1]),
      .hps_0_hps_io_hps_io_qspi_inst_IO2    (HPS_FLASH_DATA[2]),
      .hps_0_hps_io_hps_io_qspi_inst_IO3    (HPS_FLASH_DATA[3]),
      .hps_0_hps_io_hps_io_qspi_inst_SS0    (HPS_FLASH_NCSO),
      .hps_0_hps_io_hps_io_qspi_inst_CLK    (HPS_FLASH_DCLK),
      .hps_0_hps_io_hps_io_sdio_inst_CMD    (HPS_SD_CMD),
      .hps_0_hps_io_hps_io_sdio_inst_D0     (HPS_SD_DATA[0]),
      .hps_0_hps_io_hps_io_sdio_inst_D1     (HPS_SD_DATA[1]),
      .hps_0_hps_io_hps_io_sdio_inst_CLK    (HPS_SD_CLK),
      .hps_0_hps_io_hps_io_sdio_inst_D2     (HPS_SD_DATA[2]),
      .hps_0_hps_io_hps_io_sdio_inst_D3     (HPS_SD_DATA[3]),
      .hps_0_hps_io_hps_io_usb1_inst_D0     (HPS_USB_DATA[0]),
      .hps_0_hps_io_hps_io_usb1_inst_D1     (HPS_USB_DATA[1]),
      .hps_0_hps_io_hps_io_usb1_inst_D2     (HPS_USB_DATA[2]),
      .hps_0_hps_io_hps_io_usb1_inst_D3     (HPS_USB_DATA[3]),
      .hps_0_hps_io_hps_io_usb1_inst_D4     (HPS_USB_DATA[4]),
      .hps_0_hps_io_hps_io_usb1_inst_D5     (HPS_USB_DATA[5]),
      .hps_0_hps_io_hps_io_usb1_inst_D6     (HPS_USB_DATA[6]),
      .hps_0_hps_io_hps_io_usb1_inst_D7     (HPS_USB_DATA[7]),
      .hps_0_hps_io_hps_io_usb1_inst_CLK    (HPS_USB_CLKOUT),
      .hps_0_hps_io_hps_io_usb1_inst_STP    (HPS_USB_STP),
      .hps_0_hps_io_hps_io_usb1_inst_DIR    (HPS_USB_DIR),
      .hps_0_hps_io_hps_io_usb1_inst_NXT    (HPS_USB_NXT),
      .hps_0_hps_io_hps_io_spim1_inst_CLK   (HPS_SPIM_CLK),
      .hps_0_hps_io_hps_io_spim1_inst_MOSI  (HPS_SPIM_MOSI),
      .hps_0_hps_io_hps_io_spim1_inst_MISO  (HPS_SPIM_MISO),
      .hps_0_hps_io_hps_io_spim1_inst_SS0   (HPS_SPIM_SS),
      .hps_0_hps_io_hps_io_uart0_inst_RX    (HPS_UART_RX),
      .hps_0_hps_io_hps_io_uart0_inst_TX    (HPS_UART_TX),
      .hps_0_hps_io_hps_io_i2c0_inst_SDA    (HPS_I2C1_SDAT),
      .hps_0_hps_io_hps_io_i2c0_inst_SCL    (HPS_I2C1_SCLK),
      .hps_0_hps_io_hps_io_i2c1_inst_SDA    (HPS_I2C2_SDAT),
      .hps_0_hps_io_hps_io_i2c1_inst_SCL    (HPS_I2C2_SCLK),
      .hps_0_hps_io_hps_io_gpio_inst_GPIO09 (HPS_CONV_USB_N),
      .hps_0_hps_io_hps_io_gpio_inst_GPIO35 (HPS_ENET_INT_N),
      .hps_0_hps_io_hps_io_gpio_inst_GPIO40 (HPS_LTC_GPIO),
      .hps_0_hps_io_hps_io_gpio_inst_GPIO48 (HPS_I2C_CONTROL),
      .hps_0_hps_io_hps_io_gpio_inst_GPIO53 (HPS_LED),
      .hps_0_hps_io_hps_io_gpio_inst_GPIO54 (HPS_KEY),
      .hps_0_hps_io_hps_io_gpio_inst_GPIO61 (HPS_GSENSOR_INT),

      // System Control and Resets
      .clk_clk                             (CLOCK_50),
      .reset_reset_n                       (hps_fpga_reset_n),
      .hps_0_f2h_stm_hw_events_stm_hwevents(stm_hw_events),
      .hps_0_h2f_reset_reset_n             (hps_fpga_reset_n),

      // AXI Coherency Signals
      .mcu_axi_signals_export(pio_controlled_axi_signals),
      .axi_signals_awcache   (pio_controlled_axi_signals[AWCACHE_BASE+:AWCACHE_SIZE]),
      .axi_signals_awprot    (pio_controlled_axi_signals[AWPROT_BASE+:AWPROT_SIZE]),
      .axi_signals_awuser    (pio_controlled_axi_signals[AWUSER_BASE+:AWUSER_SIZE]),
      .axi_signals_arcache   (pio_controlled_axi_signals[ARCACHE_BASE+:ARCACHE_SIZE]),
      .axi_signals_aruser    (pio_controlled_axi_signals[ARUSER_BASE+:ARUSER_SIZE]),
      .axi_signals_arprot    (pio_controlled_axi_signals[ARPROT_BASE+:ARPROT_SIZE]),

      // DMA input FIFO interface
      .fifo_in_writedata  (fifo_write_data),
      .fifo_in_write      (fifo_write_en),
      .fifo_in_waitrequest(fifo_waitreq),

      // Software acquisition control
      .data_cntrl_export(data_cntrl)
  );

  // Debounce the push buttons before using KEY[0] as the board reset input.
  debounce debounce_inst (
      .clk     (CLOCK_50),
      .reset_n (hps_fpga_reset_n),
      .data_in (KEY),
      .data_out(fpga_debounced_buttons)
  );

  // Source/Probe megawizard instance.
  hps_reset hps_reset_inst (
      .source_clk(CLOCK_50),
      .source    (hps_reset_req)
  );

  // Synchronize the software acquisition request into the 50 MHz clock domain.
  always @(posedge clk_i) begin
    if (rst_i) begin
      ps_data_rdy_int <= 1'b0;
      ps_data_rdy_stable <= 1'b0;
    end else begin
      ps_data_rdy_int <= data_cntrl[0];
      ps_data_rdy_stable <= ps_data_rdy_int;
    end
  end

  ///////////////////////////////////
  // Audio-front-end local assigns //
  /////////////////////////////////
  assign clk_i = CLOCK_50;
  assign rst_i = ~fpga_debounced_buttons[0];
  assign freq_sel = SW[4:2];

  // Route the shared microphone clock onto GPIO_0.
  assign GPIO_0[MIC_CLK_GPIO_INDEX] = mic_clk_o;

  // Route pulse generation onto GPIO_0
  assign GPIO_0[PULSE_GEN_GPIO_INDEX] = pulse;

  ///////////////////////////////
  // Audio-front-end instance //
  /////////////////////////////
  Audio_Front_End iAUD_FRONT (
      .clk_i(clk_i),
      .rst_i(rst_i),
      .mode_req_i(SW[1:0]),

      .ADC_data_out_i(ADC_DOUT),
      .ADC_SCLK_o(ADC_SCLK),
      .ADC_CS_o(ADC_CS_N),
      .ADC_data_in_o(ADC_DIN),

      .curr_mode_o(curr_mode),
      .data_val_o (mic_data_val),
      .mic_clk_o  (mic_clk_o)
  );
  

  ////////////////////////////////////////////
  // PDM-to-PCM conversion and mock-data mux //
  ////////////////////////////////////////////
  genvar lane_idx;
  genvar stream_idx;

  generate
    // Each PDM lane produces two PCM streams by decoding the positive and
    // negative microphone-clock edges independently. The lane order above is
    // chosen so the stream indices map to M1 through M16.
    for (lane_idx = 0; lane_idx < NUM_PDM_LANES; lane_idx = lane_idx + 1) begin : gen_pdm_lanes
      // Map each logical PDM lane onto the GPIO pin used by the board wiring.
      assign mic_data_gpio[lane_idx] = GPIO_0[gpio0_map(MIC_DATA_GPIO_INDEX[lane_idx])];

      Pdm_To_Pcm iCONV (
          .clk_i            (clk_i),
          .rst_i            (rst_i),
          .mic_clk_i        (mic_clk_o),
          .mic_clk_val_i    (mic_data_val),
          .freq_sel_i       (freq_sel),
          .mic_data_i       (mic_data_gpio[lane_idx]),
          .pos_pcm_cap_rdy_i(conv_pos_pcm_cap_rdy[lane_idx]),
          .neg_pcm_cap_rdy_i(conv_neg_pcm_cap_rdy[lane_idx]),

          .pcm_pos_o      (conv_pcm_pos[lane_idx]),
          .pcm_valid_pos_o(conv_pcm_valid_pos[lane_idx]),
          .pcm_neg_o      (conv_pcm_neg[lane_idx]),
          .pcm_valid_neg_o(conv_pcm_valid_neg[lane_idx])
      );

      assign conv_pcm[2*lane_idx] = conv_pcm_pos[lane_idx];
      assign conv_pcm[2*lane_idx+1] = conv_pcm_neg[lane_idx];
      assign conv_pcm_valid[2*lane_idx] = conv_pcm_valid_pos[lane_idx];
      assign conv_pcm_valid[2*lane_idx+1] = conv_pcm_valid_neg[lane_idx];
      assign conv_pos_pcm_cap_rdy[lane_idx] = 1'b1;
      assign conv_neg_pcm_cap_rdy[lane_idx] = 1'b1;
    end

    // Generate mock samples for DMA and display-path testing. The mock streams
    // step only when the corresponding real stream produces a valid pulse so
    // the synthetic traffic stays aligned to the real sample cadence.
    for (
        stream_idx = 0; stream_idx < NUM_MIC_STREAMS; stream_idx = stream_idx + 1
    ) begin : gen_mock_data
      mock_data iMOCK_DATA (
          .clk_i(clk_i),
          .rst_n_i(~rst_i),
          .step_i(ps_ready_for_data && conv_pcm_valid[stream_idx]),
          .data_o(mock_pcm[stream_idx]),
          .data_valid_o(mock_pcm_valid[stream_idx])
      );

      assign active_pcm[stream_idx] = SW[9] ? mock_pcm[stream_idx] : conv_pcm[stream_idx];
      assign active_pcm_valid[stream_idx] = SW[9] ? mock_pcm_valid[stream_idx] :
          conv_pcm_valid[stream_idx];
    end
  endgenerate

  ///////////////////////////
  // DMA packetizer block  //
  /////////////////////////
  // Capture one sample from all streams, then packetize the
  // completed frame.
  Pcm_To_Mem #(
      .NUM_STREAMS (NUM_MIC_STREAMS),
      .SAMPLE_WIDTH(PCM_SAMPLE_WIDTH),
      .BEAT_WIDTH  (FRAME_WIDTH)
  ) pcm_to_mem_inst (
      .clk_i(clk_i),
      .rst_i(rst_i),
      .pcm_data_i(active_pcm),
      .pcm_valid_i(active_pcm_valid),
      .ps_ready_for_data_i(ps_ready_for_data),
      .write_pending_i(fifo_waitreq),
      .write_en_o(fifo_write_en),
      .write_data_o(fifo_write_data)
  );

  ///////////////////////////
  // DMA packetizer block  //
  ///////////////////////////
  pulse_gen #(.PULSE_LENGTH_MS(100), .PULSE_GAP_MS(500)) pulse_gen_inst (
    .clk(clk_i),
    .rst_n(~rst_i),
    .freq_sel(2'b10),
    .pulse(pulse)
);

  wire [2:0] quadrant_code;
  wire quadrant_valid, collect_sample;

  tdoa tdoa_inst (
    .clk(clk_i),
    .rst_n(~rst_i),
    .mic_valid({conv_pcm_valid_pos[0], conv_pcm_valid_neg[0], conv_pcm_valid_pos[1], conv_pcm_valid_neg[1]}),
    .mic_pcm_0(conv_pcm_pos[0]),
    .mic_pcm_1(conv_pcm_neg[0]),
    .mic_pcm_2(conv_pcm_pos[1]),
    .mic_pcm_3(conv_pcm_neg[1]),
    .quadrant_valid(quadrant_valid),
    .quadrant_code(quadrant_code),
    .collect_sample(collect_sample)
  );

  /////////////////////////////////////
  // Display FIFO selection and flow //
  ///////////////////////////////////
  // Select which PCM stream to show on the HEX display path.
  // Stream order is M1, M2, M3, M4, ... , M15, M16.
  assign pcm_stream_sel = SW[STREAM_SEL_WIDTH+4:5];

  // Write selected PCM samples when the display FIFO can accept data.
  assign fifo_wrreq = fifo_pcm_valid & ~fifo_full;

  // Read continuously so the most recent captured sample reaches the display.
  assign fifo_rdreq = ~fifo_empty;

  // Select one of the sixteen active PCM streams to feed the display FIFO.
  always @(*) begin
    fifo_data = active_pcm[pcm_stream_sel];
    fifo_pcm_valid = active_pcm_valid[pcm_stream_sel];
  end

  // Instantiate the PCM display FIFO.
  FIFO iPCM_DISPLAY_FIFO (
      .clock(clk_i),
      .data (fifo_data),
      .rdreq(fifo_rdreq),
      .sclr (clr_fifo),
      .wrreq(fifo_wrreq),

      .empty(fifo_empty),
      .full (fifo_full),
      .q    (fifo_q),
      .usedw(fifo_usedw)
  );

  // clear the FIFO periodically.
  assign clr_fifo = rst_i | fifo_full;

  // Register the FIFO output one cycle after each read request.
  always @(posedge clk_i) begin
    if (rst_i) begin
      fifo_rdreq_q <= 1'b0;
      latest_fifo_sample <= 16'h0000;
    end else begin
      fifo_rdreq_q <= fifo_rdreq;

      if (fifo_rdreq_q) begin
        latest_fifo_sample <= fifo_q;
      end
    end
  end

  //////////////////////////
  // HEX display logic   //
  ////////////////////////
  // Slow the visible update rate so the HEX display can be read by eye.
  always @(posedge clk_i) begin
    if (rst_i) begin
      display_div_cnt <= 23'd0;
      display_sample  <= 16'h0000;
    end else if (display_div_cnt == DISPLAY_UPDATE_DIV - 1) begin
      display_div_cnt <= 23'd0;
      display_sample  <= latest_fifo_sample;
    end else begin
      display_div_cnt <= display_div_cnt + 1'b1;
    end
  end

  reg [3:0] hex0_data, hex1_data, hex2_data, hex3_data, hex4_data, hex5_data;
  reg page_sel;

  always @(posedge clk_i) begin
    if (rst_i) begin
      page_sel <= '0;
    end else if (fpga_debounced_buttons[3]) begin
      page_sel <= page_sel + 1;
    end
  end

  always @(*) begin
    if (page_sel == 0) begin
      // Show PCM sample and stream/mode info.
      hex0_data = display_sample[3:0];
      hex1_data = display_sample[7:4];
      hex2_data = display_sample[11:8];
      hex3_data = display_sample[15:12];
      hex4_data = {2'b00, pcm_stream_sel};
      hex5_data = {2'b00, curr_mode};
    end else if (page_sel == 1) begin
      // Show TDOA quadrant code and validity.
      hex0_data = {1'b0, quadrant_code};
      hex1_data = {3'b0, quadrant_valid};
      hex2_data = {3'b0, collect_sample};
      hex3_data = 0;
      hex4_data = 0;
      hex5_data = 0;
    end
  end

  always @(*) begin
    case(freq_sel)
      3'b100: band_visual = 6'b110000;
      3'b000: band_visual = 6'b011000;
      3'b001: band_visual = 6'b001100;
      3'b010: band_visual = 6'b000110;
      3'b011: band_visual = 6'b000011;
      default: band_visual = 6'b000000;
    endcase
  end

  // Display the selected PCM sample as four hexadecimal digits.
  Seven_Seg iHEX0 (
      .bin_i(hex0_data),
      .hex_o(HEX0)
  );

  Seven_Seg iHEX1 (
      .bin_i(hex1_data),
      .hex_o(HEX1)
  );

  Seven_Seg iHEX2 (
      .bin_i(hex2_data),
      .hex_o(HEX2)
  );

  Seven_Seg iHEX3 (
      .bin_i(hex3_data),
      .hex_o(HEX3)
  );

  // Display the selected PCM stream number on HEX4.
  Seven_Seg iHEX4 (
      .bin_i(hex4_data),
      .hex_o(HEX4)
  );

  // Display the current microphone mode on HEX5.
  Seven_Seg iHEX5 (
      .bin_i(hex5_data),
      .hex_o(HEX5)
  );


endmodule
