`timescale 1ns / 1ps
// ------------------------------------------------------------
// Module: Pcm_To_Mem
// Description: Captures one PCM sample from each microphone
//              stream, stores the completed frame, and sends
//              that frame to the HPS DMA FIFO as consecutive
//              fixed-width beats.
// Author: Srivibhav Jonnalagadda
// Date: 04-17-2026
// ------------------------------------------------------------
module Pcm_To_Mem #(
    parameter int unsigned NUM_STREAMS  = 16,
    parameter int unsigned SAMPLE_WIDTH = 16,
    parameter int unsigned BEAT_WIDTH   = 128
) (
    input logic clk_i,
    input logic rst_i,

    input logic [SAMPLE_WIDTH-1:0] pcm_data_i [NUM_STREAMS],
    input logic [NUM_STREAMS-1:0] pcm_valid_i,
    input logic ps_ready_for_data_i,
    input logic write_pending_i,

    output logic [BEAT_WIDTH-1:0] write_data_o,
    output logic write_en_o
);

  // This packetizer assumes the microphone frame width divides evenly into
  // the outgoing DMA beat width. The current 16 x 16-bit frame maps to
  // two 128-bit beats.
  localparam int unsigned STREAMS_PER_BEAT = BEAT_WIDTH / SAMPLE_WIDTH;
  localparam int unsigned FRAME_BEATS = NUM_STREAMS / STREAMS_PER_BEAT;
  localparam int unsigned BEAT_COUNT_W = (FRAME_BEATS > 1) ? $clog2(FRAME_BEATS + 1) : 1;

  ////////////////////////////////////////
  // Declare state types as enumerated //
  //////////////////////////////////////
  typedef enum logic [1:0] {
    IDLE,
    CAPTURE,
    LOAD_PKT,
    WRITE
  } state_t;

  typedef logic [SAMPLE_WIDTH-1:0] sample_t;

  /////////////////////////////////////////////////
  // Declare any internal signals as type logic //
  ///////////////////////////////////////////////
  logic cap_frame;  // Allows the capture datapath to latch new PCM samples.
  logic clr_capture;  // Clears the in-progress frame capture registers.
  logic load_packet;  // Snapshots the completed frame for DMA transmission.
  logic load_dma_cntr;  // Loads the number of beats left to transmit.
  logic dec_dma_cntr;  // Decrements the pending beat count after an accepted write.
  logic shift_packet;  // Shifts the queued DMA beats toward the output after an accepted write.
  logic set_write_en;  // Asserts the registered DMA write enable output.
  logic clr_write_en;  // De-asserts the registered DMA write enable output.
  logic load_first_write_data;  // Loads the first DMA beat into the output register.
  logic load_next_write_data;  // Loads the next DMA beat into the output register.
  logic clr_write_data;  // Clears the registered DMA write data output.
  logic [NUM_STREAMS-1:0] stream_captured;  // Tracks which streams have contributed to the current frame.
  logic frame_captured;  // Indicates the current cycle finishes the full PCM frame.
  logic beat_accepted;  // Indicates the current DMA beat was accepted by the FIFO.
  logic last_beat;  // Indicates the DMA beat currently on the output is the final beat.
  sample_t capture_buffer[NUM_STREAMS];  // Holds the in-progress PCM frame while streams arrive.
  sample_t packet_buffer[NUM_STREAMS];  // Holds the captured frame while DMA drains it.
  logic [BEAT_COUNT_W-1:0] pending_beats;  // Number of DMA beats still left to send.
  state_t state, nxt_state;
  ///////////////////////////////////////////////

  // A frame is complete once every stream has either already been captured
  // or is being captured on the current cycle.
  assign frame_captured = &(stream_captured | pcm_valid_i);

  // A beat is consumed only when the FIFO is not applying backpressure.
  assign beat_accepted = write_en_o & ~write_pending_i;

  // The current beat is the last beat when one beat remains in the transfer.
  assign last_beat = (pending_beats == BEAT_COUNT_W'(1));

  ///////////////////////////////
  // Per-stream capture logic //
  /////////////////////////////
  genvar stream_idx;
  generate
    for (stream_idx = 0; stream_idx < NUM_STREAMS; stream_idx++) begin : gen_stream_capture
      // Latch each PCM sample independently.
      always_ff @(posedge clk_i) begin
        if (rst_i) begin
          capture_buffer[stream_idx] <= '0;
        end else if (clr_capture) begin
          capture_buffer[stream_idx] <= '0;
        end else if (cap_frame & pcm_valid_i[stream_idx] & ~stream_captured[stream_idx]) begin
          capture_buffer[stream_idx] <= pcm_data_i[stream_idx];
        end
      end

      // Track whether this stream has already contributed to the current frame.
      always_ff @(posedge clk_i) begin
        if (rst_i) begin
          stream_captured[stream_idx] <= 1'b0;
        end else if (clr_capture) begin
          stream_captured[stream_idx] <= 1'b0;
        end else if (cap_frame & pcm_valid_i[stream_idx]) begin
          stream_captured[stream_idx] <= 1'b1;
        end
      end
  end
  endgenerate

  ///////////////////////////////
  // DMA packet buffer logic  //
  /////////////////////////////
  // Snapshot the completed PCM frame into the packet buffer, then shift
  // samples forward by one DMA beat whenever a beat is accepted.
  genvar packet_stream_idx;
  generate
    for (packet_stream_idx = 0; packet_stream_idx < NUM_STREAMS;
         packet_stream_idx++) begin : gen_packet_buffer
      if (packet_stream_idx < (NUM_STREAMS - STREAMS_PER_BEAT)) begin : gen_shift_packet_reg
        always_ff @(posedge clk_i) begin
          if (rst_i) begin
            packet_buffer[packet_stream_idx] <= '0;
          end else if (load_packet) begin
            packet_buffer[packet_stream_idx] <= capture_buffer[packet_stream_idx];
          end else if (shift_packet) begin
            packet_buffer[packet_stream_idx] <= packet_buffer[packet_stream_idx+STREAMS_PER_BEAT];
          end
        end
      end else begin : gen_tail_packet_reg
        always_ff @(posedge clk_i) begin
          if (rst_i) begin
            packet_buffer[packet_stream_idx] <= '0;
          end else if (load_packet) begin
            packet_buffer[packet_stream_idx] <= capture_buffer[packet_stream_idx];
          end else if (shift_packet) begin
            packet_buffer[packet_stream_idx] <= '0;
          end
        end
      end
    end
  endgenerate

  ///////////////////////////////
  // DMA beat counter logic   //
  /////////////////////////////
  // Count how many beats of the current frame still need to be written.
  always_ff @(posedge clk_i) begin
    if (rst_i) begin
      pending_beats <= '0;
    end else if (load_dma_cntr) begin
      pending_beats <= BEAT_COUNT_W'(FRAME_BEATS);
    end else if (dec_dma_cntr) begin
      pending_beats <= pending_beats - 1'b1;
    end
  end

  // Registered DMA write enable output.
  always_ff @(posedge clk_i) begin
    if (rst_i) begin
      write_en_o <= 1'b0;
    end else if (clr_write_en) begin
      write_en_o <= 1'b0;
    end else if (set_write_en) begin
      write_en_o <= 1'b1;
    end
  end

  // Registered DMA write data output. Each slice is loaded from the packet
  // buffer so the outgoing beat is fully registered.
  genvar write_stream_idx;
  generate
    for (write_stream_idx = 0; write_stream_idx < STREAMS_PER_BEAT;
         write_stream_idx++) begin : gen_write_data
      if (FRAME_BEATS > 1) begin : gen_multi_beat_write_data
        always_ff @(posedge clk_i) begin
          if (rst_i) begin
            write_data_o[write_stream_idx*SAMPLE_WIDTH+:SAMPLE_WIDTH] <= '0;
          end else if (clr_write_data) begin
            write_data_o[write_stream_idx*SAMPLE_WIDTH+:SAMPLE_WIDTH] <= '0;
          end else if (load_first_write_data) begin
            write_data_o[write_stream_idx*SAMPLE_WIDTH+:SAMPLE_WIDTH] <=
                packet_buffer[write_stream_idx];
          end else if (load_next_write_data) begin
            write_data_o[write_stream_idx*SAMPLE_WIDTH+:SAMPLE_WIDTH] <=
                packet_buffer[STREAMS_PER_BEAT+write_stream_idx];
          end
        end
      end else begin : gen_single_beat_write_data
        always_ff @(posedge clk_i) begin
          if (rst_i) begin
            write_data_o[write_stream_idx*SAMPLE_WIDTH+:SAMPLE_WIDTH] <= '0;
          end else if (clr_write_data) begin
            write_data_o[write_stream_idx*SAMPLE_WIDTH+:SAMPLE_WIDTH] <= '0;
          end else if (load_first_write_data) begin
            write_data_o[write_stream_idx*SAMPLE_WIDTH+:SAMPLE_WIDTH] <=
                packet_buffer[write_stream_idx];
          end
        end
      end
    end
  endgenerate

  /////////////////////////////////////
  // Implements State Machine Logic //
  ///////////////////////////////////
  always_ff @(posedge clk_i) begin
    if (rst_i) begin
      state <= IDLE;
    end else begin
      state <= nxt_state;
    end
  end

  //////////////////////////////////////////////////////////////////////////////////////////
  // Implements the combinational state transition and output logic of the state machine. //
  ////////////////////////////////////////////////////////////////////////////////////////
  always_comb begin
    nxt_state = state;
    cap_frame = 1'b0;
    clr_capture = 1'b0;
    load_packet = 1'b0;
    load_dma_cntr = 1'b0;
    dec_dma_cntr = 1'b0;
    shift_packet = 1'b0;
    set_write_en = 1'b0;
    clr_write_en = 1'b0;
    load_first_write_data = 1'b0;
    load_next_write_data = 1'b0;
    clr_write_data = 1'b0;

    case (state)
      CAPTURE: begin
        if (ps_ready_for_data_i) begin
          cap_frame = 1'b1;

          if (frame_captured) begin
            nxt_state = LOAD_PKT;
          end
        end else begin
          clr_capture = 1'b1;
          nxt_state   = IDLE;
        end
      end

      LOAD_PKT: begin
        load_packet = 1'b1;
        clr_capture = 1'b1;
        load_dma_cntr = 1'b1;
        nxt_state = WRITE;
      end

      WRITE: begin
        if (~write_en_o) begin
          set_write_en = 1'b1;
          load_first_write_data = 1'b1;
        end else if (beat_accepted) begin
          dec_dma_cntr = 1'b1;

          if (last_beat) begin
            clr_write_en = 1'b1;
            clr_write_data = 1'b1;
            nxt_state = (ps_ready_for_data_i) ? CAPTURE : IDLE;
          end else begin
            shift_packet = 1'b1;
            load_next_write_data = 1'b1;
          end
        end
      end

      default: begin  // IDLE
        if (ps_ready_for_data_i) begin
          cap_frame = 1'b1;

          if (frame_captured) begin
            nxt_state = LOAD_PKT;
          end else begin
            nxt_state = CAPTURE;
          end
        end
      end
    endcase
  end

endmodule
