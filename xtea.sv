//======================================================================
//
// xtea.v
// ------
// Top level wrapper for the XTEA block cipher core.
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

module xtea(
            // Clock and reset.
            input wire               clk,
            input wire               reset_n,

            // Control.
            input wire               cs,
            input wire               we,

            // Data ports.
            input wire      [7 : 0]  address,
            input wire      [31 : 0] write_data,
            output wire     [31 : 0] read_data
           );


  //----------------------------------------------------------------
  // Internal constant and parameter definitions.
  //----------------------------------------------------------------

  localparam ADDR_CTRL         = 8'h08;
  localparam CTRL_NEXT_BIT     = 1;

  localparam STATUS_READY_BIT  = 0;

  localparam ADDR_CONFIG       = 8'h0a;
  localparam CONFIG_ENCDEC_BIT = 0;

  localparam ADDR_ROUNDS       = 8'h0c;

  localparam ADDR_KEY0         = 8'h10;
  localparam ADDR_KEY3         = 8'h13;

  localparam ADDR_BLOCK0       = 8'h20;
  localparam ADDR_BLOCK1       = 8'h21;

  localparam ADDR_RESULT0      = 8'h30;
  localparam ADDR_RESULT1      = 8'h31;

  localparam CORE_NAME0        = 32'h78746561; // "xtea"
  localparam CORE_NAME1        = 32'h2d313238; // "-128"
  localparam CORE_VERSION      = 32'h302e3630; // "0.60"

  localparam NUM_ROUNDS        = 32;


  //----------------------------------------------------------------
  // Registers including update variables and write enable.
  //----------------------------------------------------------------
  logic next;
  logic next_new;

  logic encdec;
  logic config_we;

  logic [31 : 0] block_reg [0 : 1];
  logic          block_we;

  logic [31 : 0] key_reg [0 : 3];
  logic          key_we;

  logic [5 : 0]  rounds;
  logic          rounds_we;
  logic [31 : 0]   tmp_read_data;

  //----------------------------------------------------------------
  // Wires.
  //----------------------------------------------------------------

  wire           ready;
  wire [127 : 0] key;
  wire [63 : 0]  block;
  wire [63 : 0]  result;


  //----------------------------------------------------------------
  // Concurrent connectivity for ports etc.
  //----------------------------------------------------------------
  assign read_data = tmp_read_data;

  assign key = {key_reg[0], key_reg[1], key_reg[2], key_reg[3]};
  assign block  = {block_reg[0], block_reg[1]};


  //----------------------------------------------------------------
  // core instantiation.
  //----------------------------------------------------------------
  xtea_core core(.*);
  
  
  enum {ADDR_NAME0 = 4'h0, ADDR_NAME1 = 4'h1, ADDR_VERSION = 4'h2, ADDR_STATUS = 4'h9} address_reg;
 

  //----------------------------------------------------------------
  // reg_update
  // Update functionality for all registers in the core.
  // All registers are positive edge triggered with asynchronous
  // active low reset.
  //----------------------------------------------------------------
  always_ff @ (posedge clk or negedge reset_n)
    begin : reg_update
      integer i;

      if (reset_n == 0)//!
        begin
          for (i = 0 ; i < 2 ; i++)
            block_reg[i] <= 32'h0;

          for (i = 0 ; i < 4 ; i++)
            key_reg[i] <= 32'h0;

          rounds <= NUM_ROUNDS;
          next   <= 1'h0;
          encdec <= 1'h0;
        end
      else
        begin
          next <= next_new;

          if (config_we)
            begin
              encdec <= write_data[CONFIG_ENCDEC_BIT];
            end

          if (rounds_we)
            rounds <= write_data[5 : 0];

          if (key_we)
            key_reg[address[1 : 0]] <= write_data;

          if (block_we)
            block_reg[address[0]] <= write_data;
        end
    end // reg_update


  //----------------------------------------------------------------
  // api
  //
  // The interface command decoding logic.
  //----------------------------------------------------------------
  always_comb
    begin : api
      rounds_we     = 1'h0;
      next_new      = 1'h0;
      config_we     = 1'h0;
      key_we        = 1'h0;
      block_we      = 1'h0;
      tmp_read_data = 32'h0;

      if (cs)
        begin
          if (we)
            begin
              if (ready)
                begin
                  if (address == ADDR_CTRL)
                    next_new = write_data[CTRL_NEXT_BIT];

                  if (address == ADDR_CONFIG)
                    config_we = 1'h1;

                  if (address == ADDR_ROUNDS)
                    config_we = 1'h1;

                  if ((address >= ADDR_KEY0) && (address <= ADDR_KEY3))
                    key_we = 1'h1;

                  if ((address >= ADDR_BLOCK0) && (address <= ADDR_BLOCK1))
                    block_we = 1'h1;
                end
            end

          else
            begin
              case (address)
                ADDR_NAME0:   tmp_read_data = CORE_NAME0;
                ADDR_NAME1:   tmp_read_data = CORE_NAME1;
                ADDR_VERSION: tmp_read_data = CORE_VERSION;
                ADDR_STATUS:  tmp_read_data = {31'h0, ready};

                default:
                  begin
                  end
              endcase // case (address)

              if ((address >= ADDR_RESULT0) && (address <= ADDR_RESULT1))
                tmp_read_data = result[(1 - (address - ADDR_RESULT0)) * 32 +: 32];
            end
        end
    end // addr_decoder
endmodule // xtea

//======================================================================
// EOF xtea.v
//======================================================================
