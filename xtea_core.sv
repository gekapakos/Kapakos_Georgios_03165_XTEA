//======================================================================
//
// xtea_core.v
// -----------
// XTEA block cipher core.
//
//
// Author: Joachim Strombergson
// Copyright (c) 2019, Assured AB
// All rights reserved.
//
// Redistribution and use in source and binary forms, with or
// without modification, are permitted provided that the following
// conditions are met:
//
// 1. Redistributions of source code must retain the above copyright
//    notice, this list of conditions and the following disclaimer.
//
// 2. Redistributions in binary form must reproduce the above copyright
//    notice, this list of conditions and the following disclaimer in
//    the documentation and/or other materials provided with the
//    distribution.
//
// THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS
// "AS IS" AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT
// LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS
// FOR A PARTICULAR PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL THE
// COPYRIGHT OWNER OR CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT,
// INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING,
// BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES;
// LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER
// CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT,
// STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE)
// ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF
// ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
//
//======================================================================

`default_nettype none

module xtea_core(
                 input wire           clk,
                 input wire           reset_n,

                 input wire           encdec,
                 input wire           next,
                 output wire          ready,

                 input wire [5 : 0]   rounds,
                 input wire [127 : 0] key,

                 input wire [63 : 0]  block,
                 output wire [63 : 0] result
                );


  //----------------------------------------------------------------
  // Internal constant and parameter definitions.
  //----------------------------------------------------------------
  enum {CTRL_IDLE = 2'h0, CTRL_INIT = 2'h1, CTRL_ROUNDS0 = 2'h2, CTRL_ROUNDS1 = 2'h3} core_ctrl_reg, core_ctrl_new;
  localparam DELTA        = 32'h9e3779b9;
  localparam NUM_ROUNDS   = 32;


  //----------------------------------------------------------------
  // Registers including update variables and write enable.
  //----------------------------------------------------------------
  logic [31 : 0] v0_reg;
  logic [31 : 0] v0_new;
  logic          v0_we;

  logic [31 : 0] v1_reg;
  logic [31 : 0] v1_new;
  logic          v1_we;

  logic [31 : 0] sum_reg;
  logic [31 : 0] sum_new;
  logic          sum_we;

  logic          ready_reg;
  logic          ready_new;
  logic          ready_we;

  logic [5 : 0]  round_ctr_reg;
  logic [5 : 0]  round_ctr_new;
  logic          round_ctr_rst;
  logic          round_ctr_inc;
  logic          round_ctr_we;

  //logic [1 : 0]  core_ctrl_new;
  logic          core_ctrl_we;


  //----------------------------------------------------------------
  // Wires.
  //----------------------------------------------------------------
  logic init_state;
  logic update_v0;
  logic update_v1;
  logic update_sum;


  //----------------------------------------------------------------
  // Concurrent connectivity for ports etc.
  //----------------------------------------------------------------
  assign ready  = ready_reg;
  assign result = {v0_reg, v1_reg};


  //----------------------------------------------------------------
  // reg_update
  //
  // Update functionality for all registers in the core.
  // All registers are positive edge triggered with asynchronous
  // active low reset. All registers have write enable.
  //----------------------------------------------------------------
  always_ff @ (posedge clk or negedge reset_n)
    begin: reg_update
      if (!reset_n)
        begin
          ready_reg     <= 1'h1;
          v0_reg        <= 32'h0;
          v1_reg        <= 32'h0;
          sum_reg       <= 32'h0;
          round_ctr_reg <= NUM_ROUNDS;
          core_ctrl_reg <= CTRL_IDLE;
        end
      else
        begin
          if (ready_we)
            ready_reg <= ready_new;

          if (v0_we)
              v0_reg <= v0_new;

          if (v1_we)
              v1_reg <= v1_new;

          if (sum_we)
            sum_reg <= sum_new;

          if (round_ctr_we)
            round_ctr_reg <= round_ctr_new;

          if (core_ctrl_we)
            core_ctrl_reg <= core_ctrl_new;
        end
    end // reg_update


  //----------------------------------------------------------------
  // xtea_core_dp
  //
  // Datapath with state update logic.
  //----------------------------------------------------------------
  always_comb 
    begin : xtea_core_dp
      logic [31 : 0] keyw [0 : 3];

      logic [31 : 0] v0_0;
      logic [31 : 0] v0_0_0;
      logic [31 : 0] v0_0_1;
      logic [31 : 0] v0_1;
      logic [31 : 0] v0_delta;

      logic [31 : 0] v1_0;
      logic [31 : 0] v1_0_0;
      logic [31 : 0] v1_0_1;
      logic [31 : 0] v1_1;
      logic [31 : 0] v1_delta;

      v0_new  = 32'h0;
      v0_we   = 1'h0;
      v1_new  = 32'h0;
      v1_we   = 1'h0;
      sum_new = 32'h0;
      sum_we  = 1'h0;

      keyw[0] = key[127 : 096];
      keyw[1] = key[095 : 064];
      keyw[2] = key[063 : 032];
      keyw[3] = key[031 : 000];

      if (init_state)
        begin
          v0_new = block[63 : 32];
          v1_new = block[31 : 0];
          v0_we   = 1'h1;
          v1_we   = 1'h1;
          sum_we  = 1'h1;

          if (encdec)
            sum_new = 32'h0;
          else
            sum_new = DELTA * NUM_ROUNDS;
        end


      v0_0_0 = {v1_reg[27 : 0], 4'h0};
      v0_0_1 = {5'h0, v1_reg[31 : 5]};
      v0_0 = ((v0_0_0 ^ v0_0_1) + v1_reg);
      v0_1 = (sum_reg + keyw[sum_reg[1 : 0]]);
      v0_delta =  v0_0 ^ v0_1;

      if (update_v0)
        begin
          v0_we = 1'h1;
          if (encdec)
            v0_new = v0_reg + v0_delta;
          else
            v0_new = v0_reg - v0_delta;;
        end


      v1_0_0 = {v0_reg[27 : 0], 4'h0};
      v1_0_1 = {5'h0, v0_reg[31 : 5]};
      v1_0 = ((v1_0_0 ^ v1_0_1) + v0_reg);
      v1_1 = (sum_reg + keyw[sum_reg[12 : 11]]);
      v1_delta =  v1_0 ^ v1_1;

      if (update_v1)
        begin
          v1_we = 1'h1;
          if (encdec)
            v1_new = v1_reg + v1_delta;
          else
            v1_new = v1_reg - v1_delta;
        end

      if (update_sum)
        begin
          sum_we  = 1'h1;
          if (encdec)
            sum_new = sum_reg + DELTA;
          else
            sum_new = sum_reg - DELTA;
        end
    end // xtea_core_dp


  //----------------------------------------------------------------
  // round_ctr
  //
  // Update logic for the round counter.
  //----------------------------------------------------------------
  always_comb
    begin : round_ctr
      round_ctr_new = 6'h0;
      round_ctr_we  = 1'h0;

      if (round_ctr_rst)
        round_ctr_we  = 1'h1;

      if (round_ctr_inc)
        begin
          round_ctr_new = round_ctr_reg + 1'h1;
          round_ctr_we  = 1'h1;
        end
    end // round_ctr


  //----------------------------------------------------------------
  // xtea_core_ctrl
  //
  // Control FSM for aes core.
  //----------------------------------------------------------------
  always_comb
    begin : xtea_core_ctrl
      init_state    = 1'h0;
      update_v0     = 1'h0;
      update_v1     = 1'h0;
      update_sum    = 1'h0;
      ready_new     = 1'h0;
      ready_we      = 1'h0;
      round_ctr_rst = 1'h0;
      round_ctr_inc = 1'h0;
      core_ctrl_new = CTRL_IDLE;
      core_ctrl_we  = 1'h0;

      case (core_ctrl_reg)
        CTRL_IDLE:
          begin
            if (next)
              begin
                ready_new     = 1'h0;
                ready_we      = 1'h1;
                core_ctrl_new = CTRL_INIT;
                core_ctrl_we  = 1'h1;
              end
          end

        CTRL_INIT:
          begin
            round_ctr_rst = 1'h1;
            init_state    = 1'h1;
            core_ctrl_new = CTRL_ROUNDS0;
            core_ctrl_we  = 1'h1;
          end

        CTRL_ROUNDS0:
          begin
            update_sum         = 1'h1;

            if (encdec)
              update_v0        = 1'h1;
            else
              update_v1        = 1'h1;

            core_ctrl_new = CTRL_ROUNDS1;
            core_ctrl_we  = 1'b1;
          end

        CTRL_ROUNDS1:
          begin
            if (encdec)
              update_v1 = 1'h1;
            else
              update_v0 = 1'h1;

            if (round_ctr_reg == (rounds - 1))
              begin
                ready_new     = 1'h1;
                ready_we      = 1'h1;
                core_ctrl_new = CTRL_IDLE;
                core_ctrl_we  = 1'b1;
              end
            else
              begin
                round_ctr_inc = 1'h1;
                core_ctrl_new = CTRL_ROUNDS0;
                core_ctrl_we  = 1'b1;
              end
          end

        default:
          begin
          end
      endcase // case (core_ctrl_reg)
    end // xtea_core_ctrl

endmodule // xtea_core

//======================================================================
// EOF xtea_core.v
//======================================================================
