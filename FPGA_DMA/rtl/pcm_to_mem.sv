`timescale 1ns / 1ps
// ------------------------------------------------------------
// Module: pcm_to_mem
// Description: Captures one PCM sample from each microphone
//              stream and packs the completed frame into
//              sequential 128-bit DMA beats for transfer to
//              the HPS. Stream 0 occupies the lowest halfword
//              of the first DMA beat, stream 1 the next halfword,
//              and so on.
// Author: ECE554 Capstone Team
// Date: 04-16-2026
// ------------------------------------------------------------
module pcm_to_mem #(
    parameter int unsigned NUM_STREAMS = 16,
    parameter int unsigned SAMPLE_WIDTH = 16,
    parameter int unsigned BEAT_WIDTH = 128
) (
    input logic clk_i,
    input logic rst_n_i,
    input logic [NUM_STREAMS*SAMPLE_WIDTH-1:0] pcm_data_i,
    input logic [NUM_STREAMS-1:0] pcm_valid_i,
    input logic write_pending_i,
    input logic ps_ready_for_data_i,
    output logic [BEAT_WIDTH-1:0] write_data_o,
    output logic write_en_o
);

  localparam int unsigned STREAMS_PER_BEAT = BEAT_WIDTH / SAMPLE_WIDTH;
  localparam int unsigned FRAME_BEATS = (NUM_STREAMS + STREAMS_PER_BEAT - 1) / STREAMS_PER_BEAT;
  localparam int unsigned FRAME_WIDTH = FRAME_BEATS * BEAT_WIDTH;
  localparam int unsigned BEAT_INDEX_W = (FRAME_BEATS > 1) ? $clog2(FRAME_BEATS) : 1;
  localparam int unsigned PENDING_COUNT_W = $clog2(FRAME_BEATS + 1);

  /////////////////////////////////////////////////
  // Declare any internal signals as type logic //
  ///////////////////////////////////////////////
  logic [FRAME_WIDTH-1:0] capture_buffer;
  logic [FRAME_WIDTH-1:0] packet_buffer;
  logic [NUM_STREAMS-1:0] stream_captured;
  logic frame_ready;
  logic [BEAT_INDEX_W-1:0] beat_index;
  logic [PENDING_COUNT_W-1:0] pending_beats;
  logic write_accepted;
  integer stream_idx;
  ///////////////////////////////////////////////

  //////////////////////////////////////
  // Generate DMA output handshake   //
  ////////////////////////////////////
  assign write_en_o = (pending_beats != '0);
  assign write_accepted = write_en_o && !write_pending_i;

  // Present the active 128-bit beat while the frame is draining to DMA.
  always_comb begin
    write_data_o = '0;

    if (pending_beats != '0) begin
      write_data_o = packet_buffer[beat_index*BEAT_WIDTH+:BEAT_WIDTH];
    end
  end

  //////////////////////////////////////
  // Capture frames and drain beats  //
  ////////////////////////////////////
  always_ff @(posedge clk_i, negedge rst_n_i) begin
    if (!rst_n_i) begin
      capture_buffer <= '0;
      packet_buffer <= '0;
      stream_captured <= '0;
      frame_ready <= 1'b0;
      beat_index <= '0;
      pending_beats <= '0;
    end else begin
      if (pending_beats != '0) begin
        if (write_accepted) begin
          if (pending_beats == 1) begin
            pending_beats <= '0;
            beat_index <= '0;
          end else begin
            pending_beats <= pending_beats - 1'b1;
            beat_index <= beat_index + 1'b1;
          end
        end
      end else if (frame_ready) begin
        // Freeze the completed frame and start draining it as sequential DMA beats.
        packet_buffer <= capture_buffer;
        capture_buffer <= '0;
        stream_captured <= '0;
        frame_ready <= 1'b0;
        beat_index <= '0;
        pending_beats <= FRAME_BEATS[PENDING_COUNT_W-1:0];
      end else if (!ps_ready_for_data_i) begin
        // If software de-asserts acquisition between frames, clear the partial frame.
        capture_buffer <= '0;
        stream_captured <= '0;
        frame_ready <= 1'b0;
      end else begin
        // Latch the first valid sample seen for each stream into the frame buffer.
        for (stream_idx = 0; stream_idx < NUM_STREAMS; stream_idx = stream_idx + 1) begin
          if (pcm_valid_i[stream_idx] && !stream_captured[stream_idx]) begin
            capture_buffer[stream_idx*SAMPLE_WIDTH+:SAMPLE_WIDTH] <=
                pcm_data_i[stream_idx*SAMPLE_WIDTH+:SAMPLE_WIDTH];
            stream_captured[stream_idx] <= 1'b1;
          end
        end

        // Once all streams have contributed one sample, mark the frame as ready.
        if (&(stream_captured | pcm_valid_i)) begin
          frame_ready <= 1'b1;
        end
      end
    end
  end

endmodule
