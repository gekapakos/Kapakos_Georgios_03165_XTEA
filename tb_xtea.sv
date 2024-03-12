//======================================================================
//
// tb_xtea.v
// ---------
// Testbench for the xtea top level wrapper
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

module tb_xtea();

  //----------------------------------------------------------------
  // Internal constant and parameter definitions.
  //----------------------------------------------------------------
  parameter DEBUG     = 0;
  parameter DUMP_WAIT = 0;

  parameter CLK_HALF_PERIOD = 1;
  parameter CLK_PERIOD = 2 * CLK_HALF_PERIOD;

  localparam ADDR_NAME0        = 8'h00;
  localparam ADDR_NAME1        = 8'h01;
  localparam ADDR_VERSION      = 8'h02;

  localparam ADDR_CTRL         = 8'h08;
  localparam CTRL_NEXT_BIT     = 1;

  localparam ADDR_STATUS       = 8'h09;
  localparam STATUS_READY_BIT  = 0;

  localparam ADDR_CONFIG       = 8'h0a;
  localparam CONFIG_ENCDEC_BIT = 0;

  localparam ADDR_KEY0         = 8'h10;
  localparam ADDR_KEY1         = 8'h11;
  localparam ADDR_KEY2         = 8'h12;
  localparam ADDR_KEY3         = 8'h13;

  localparam ADDR_BLOCK0       = 8'h20;
  localparam ADDR_BLOCK1       = 8'h21;

  localparam ADDR_RESULT0      = 8'h30;
  localparam ADDR_RESULT1      = 8'h31;

  //----------------------------------------------------------------
  // Register and Wire declarations.
  //----------------------------------------------------------------
  logic [31 : 0] cycle_ctr;
  logic [31 : 0] error_ctr;
  logic [31 : 0] tc_ctr;
  logic          tb_monitor;

  logic           clk;
  logic           reset_n;
  logic           cs;
  logic           we;
  logic [7 : 0]   tb_address;
  logic [31 : 0]  write_data;
  wire [31 : 0] tb_read_data;

  logic [31 : 0] read_data;
  logic [31 : 0] res0;
  logic [31 : 0] res1;


  //----------------------------------------------------------------
  // Device Under Test.
  //----------------------------------------------------------------
  xtea dut(
           .clk,
           .reset_n,

           .cs,
           .we,

           .address(tb_address),
           .write_data,
           .read_data(tb_read_data)
           );


  //----------------------------------------------------------------
  // clk_gen
  //
  // Always running clock generator process.
  //----------------------------------------------------------------
  always
    begin : clk_gen
      #CLK_HALF_PERIOD;
      clk = !clk;
    end // clk_gen


  //----------------------------------------------------------------
  // sys_monitor()
  //
  // An always running process that creates a cycle counter and
  // conditionally displays information about the DUT.
  //----------------------------------------------------------------
  always
    begin : sys_monitor
      cycle_ctr = cycle_ctr + 1;
      #(CLK_PERIOD);
      if (tb_monitor)
        begin
          dump_dut_state();
        end
    end


  //----------------------------------------------------------------
  // dump_dut_state()
  //
  // Dump the state of the dump when needed.
  //----------------------------------------------------------------
  task dump_dut_state;
    begin
      $display("State of DUT");
      $display("------------");
      $display("Cycle: %08d", cycle_ctr);
      $display("Inputs and outputs:");
      $display("");
    end
  endtask // dump_dut_state


  //----------------------------------------------------------------
  // reset_dut()
  //
  // Toggle reset to put the DUT into a well known state.
  //----------------------------------------------------------------
  task reset_dut;
    begin
      $display("*** Toggle reset.");
      reset_n = 0;
      #(2 * CLK_PERIOD);
      reset_n = 1;
    end
  endtask // reset_dut


  //----------------------------------------------------------------
  // display_test_result()
  //
  // Display the accumulated test results.
  //----------------------------------------------------------------
  task display_test_result;
    begin
      if (error_ctr == 0)
        begin
          $display("*** All %02d test cases completed successfully", tc_ctr);
        end
      else
        begin
          $display("*** %02d tests completed - %02d test cases did not complete successfully.",
                   tc_ctr, error_ctr);
        end
    end
  endtask // display_test_result


  //----------------------------------------------------------------
  // init_sim()
  //
  // Initialize all counters and testbed functionality as well
  // as setting the DUT inputs to defined values.
  //----------------------------------------------------------------
  task init_sim;
    begin
      cycle_ctr  = 0;
      error_ctr  = 0;
      tc_ctr     = 0;
      tb_monitor = 0;

      clk        = 1'h0;
      reset_n    = 1'h1;
      cs         = 1'h0;
      we         = 1'h0;
      tb_address    = 8'h0;
      write_data = 32'h0;
    end
  endtask // init_sim


  //----------------------------------------------------------------
  // write_word()
  //
  // Write the given word to the DUT using the DUT interface.
  //----------------------------------------------------------------
  task write_word(input [11 : 0] address,
                  input [31 : 0] word);
    begin
      if (DEBUG)
        begin
          $display("*** Writing 0x%08x to 0x%02x.", word, address);
          $display("");
        end

      tb_address = address;
      write_data = word;
      cs = 1;
      we = 1;
      #(2 * CLK_PERIOD);
      cs = 0;
      we = 0;
    end
  endtask // write_word


  //----------------------------------------------------------------
  // read_word()
  //
  // Read a data word from the given address in the DUT.
  // the word read will be available in the global variable
  // read_data.
  //----------------------------------------------------------------
  task read_word(input [11 : 0]  address);
    begin
      tb_address = address;
      cs = 1;
      we = 0;
      #(CLK_PERIOD);
      read_data = tb_read_data;
      cs = 0;

      if (DEBUG)
        begin
          $display("*** Reading 0x%08x from 0x%02x.", read_data, address);
          $display("");
        end
    end
  endtask // read_word


  //----------------------------------------------------------------
  // wait_ready()
  //
  // Wait for the ready flag to be set in dut.
  //----------------------------------------------------------------
  task wait_ready;
    begin : wready
      read_word(ADDR_STATUS);
      while (read_data == 0)
        read_word(ADDR_STATUS);
    end
  endtask // wait_ready


  //----------------------------------------------------------------
  // tc1()
  //----------------------------------------------------------------
  task tc1;
    begin : tc1
      tc_ctr = tc_ctr + 1;

      $display("*** TC1 - encryption started.");

      write_word(ADDR_KEY0, 32'h00010203);
      write_word(ADDR_KEY1, 32'h04050607);
      write_word(ADDR_KEY2, 32'h08090a0b);
      write_word(ADDR_KEY3, 32'h0c0d0e0f);

      write_word(ADDR_BLOCK0, 32'h41424344);
      write_word(ADDR_BLOCK1, 32'h45464748);

      write_word(ADDR_CONFIG, 32'h1);
      write_word(ADDR_CTRL, 32'h2);

      wait_ready();

      read_word(ADDR_RESULT0);
      res0 = read_data;
      read_word(ADDR_RESULT1);
      res1 = read_data;

      if ({res0, res1} == 64'h497df3d072612cb5)
        begin
          $display("*** Correct result received.");
        end
      else
        begin
          $display("*** Incorrect result received. Expexted 64'h497df3d072612cb5, got 0x%016x", {res0, res1});
          error_ctr = error_ctr + 1;
        end

      $display("*** TC1 completed.");
      $display("");
    end
  endtask // tc1


  //----------------------------------------------------------------
  // tc2()
  //----------------------------------------------------------------
  task tc2;
    begin : tc2

      tc_ctr = tc_ctr + 1;

      $display("*** TC2 - decryption started.");

      write_word(ADDR_KEY0, 32'h00010203);
      write_word(ADDR_KEY1, 32'h04050607);
      write_word(ADDR_KEY2, 32'h08090a0b);
      write_word(ADDR_KEY3, 32'h0c0d0e0f);

      write_word(ADDR_BLOCK0, 32'h497df3d0);
      write_word(ADDR_BLOCK1, 32'h72612cb5);

      write_word(ADDR_CONFIG, 32'h0);
      write_word(ADDR_CTRL, 32'h2);

      wait_ready();

      read_word(ADDR_RESULT0);
      res0 = read_data;
      read_word(ADDR_RESULT1);
      res1 = read_data;

      if ({res0, res1} == 64'h4142434445464748)
        begin
          $display("*** Correct result received.");
        end
      else
        begin
          $display("*** Incorrect result received. Expexted 64'h4142434445464748, got 0x%016x", {res0, res1});
          error_ctr = error_ctr + 1;
        end

      $display("*** TC2 completed.");
      $display("");
    end
  endtask // tc2
  
  //-------------------------------------------------//
  /*Assertions*/
  //--------------------------------------------------//
  
  /*(1)Assertion: Check if res1 is equal to 72612cb5(hex), when tc_ctr is equal to 2(hex)*/
  assert property (
    @(posedge clk) (tc_ctr==2) |-> (res1 == 'h72612cb5)
  ) $display("(1)Assertion successful: res1 matches tc_ctr");
  else $fatal("(1)Assertion failed: Output does not match selected input at time %0t", $time);
  
  /*(2)Assertion: Check if write_data is equal to 2(hex), when tb_address is 8, 9, or 30(hex)*/
  assert property (
    @(posedge clk) (tb_address=='h08 || tb_address=='h09 || tb_address=='h30 || tb_address=='h31) |-> (write_data == 'h2)
  ) $display("(2)Assertion successful: write_data meets its conditions");
  else $fatal("(2)Assertion failed: Output does not match selected input at time %0t", $time);
  
  /*(3)Assertion: Check if tb_address is equal to 9, 30 or 31(hex), when we is 0 and cs is 1(hex)*/
  assert property (
    @(posedge clk) (we==0 && cs==1) |-> (tb_address == 'h09 || tb_address == 'h30 || tb_address == 'h31)
    ) $display("(3)Assertion successful: tb_address meets its conditions");
    else $fatal("(3)Assertion failed: Output does not match selected input at time %0t", $time);
  
  /*(4)If in this period the value of we is 1 then after 16 periods it should be 0.*/
  assert property (
    @(posedge clk) (we==1) |-> ##16 (we == 0)
  ) $display("(4)Assertion successful: we meets its condition");
  else $fatal("(4)Assertion failed: Output does not match selected input at time %0t", $time);
  
  /*(5)If write_data is 1 then tb_address should be a(hex).*/
  assert property (
    @(posedge clk) (write_data==1) |-> (tb_address == 'h0a)
  ) $display("(5)Assertion successful: tb_address is 'h0a when write_data is 1.");
  else $fatal("(5)Assertion failed: Output does not match selected input at time %0t", $time);
  
  /*(6)If read_data is 0(hex) then tb_address should be 9(hex).*/
  assert property (
    @(posedge clk) (read_data==0) |-> (tb_address =='h09)
  ) $display("(6)Assertion successful: read_data is 0 when tb_address is 'h09.");
  else $fatal("(6)Assertion failed: Output does not match selected input at time %0t", $time);
  
  /*(7)If read_data is 0(hex) then tb_read_data should be 0(hex).*/
  assert property (
    @(posedge clk) (read_data==0) |-> (tb_read_data =='h0)
  ) $display("(7)Assertion successful: tb_read_data is 0 when read_data is 0.");
  else $fatal("(7)Assertion failed: Output does not match selected input at time %0t", $time);
  
  /*(8)If write_data is 10203(hex) then tb_address should be 10(hex).*/
  assert property (
    @(posedge clk) (write_data=='h010203) |-> (tb_address == 'h10)
  ) $display("(8)Assertion successful: tb_address is 'h10 when write_data is 'h010203.");
  else $fatal("(8)Assertion failed: Output does not match selected input at time %0t", $time);
  
  /*(9)If write_data is 4050607(hex) then tb_address should be 11(hex).*/
  assert property (
    @(posedge clk) (write_data=='h04050607) |-> (tb_address == 'h11)
  ) $display("(9)Assertion successful: tb_address is 'h11 when write_data is 'h04050607.");
  else $fatal("(9)Assertion failed: Output does not match selected input at time %0t", $time);
  
  /*(10)If write_data is 8090a0b(hex) then tb_address should be 12(hex).*/
  assert property (
    @(posedge clk) (write_data=='h08090a0b) |-> (tb_address == 'h12)
  ) $display("(10)Assertion successful: tb_address is 'h12 when write_data is 'h08090a0b.");
  else $fatal("(10)Assertion failed: Output does not match selected input at time %0t", $time);
  
  /*(11)If write_data is 0c0d0e0f(hex) then tb_address should be 13(hex).*/
  assert property (
    @(posedge clk) (write_data=='h0c0d0e0f) |-> (tb_address == 'h13)
  ) $display("(11)Assertion successful: tb_address is 'h13 when write_data is 'h0c0d0e0f.");
  else $fatal("(11)Assertion failed: Output does not match selected input at time %0t", $time);
  
  /*(12)If write_data is 41424344(hex) then tb_address should be 20(hex).*/
  assert property (
    @(posedge clk) (write_data=='h41424344) |-> (tb_address == 'h20)
  ) $display("(12)Assertion successful: tb_address is 'h20 when write_data is 'h41424344.");
  else $fatal("(12)Assertion failed: Output does not match selected input at time %0t", $time);
  
  /*(13)If write_data is 45464748(hex) then tb_address should be 21(hex).*/
  assert property (
    @(posedge clk) (write_data=='h45464748) |-> (tb_address == 'h21)
  ) $display("(13)Assertion successful: tb_address is 'h20 when write_data is 'h45464748.");
  else $fatal("(13)Assertion failed: Output does not match selected input at time %0t", $time);
  
  /*(15)If we is 1 then tb_read_data should be 0.*/
  assert property (
    @(posedge clk) (we=='h01) |-> (tb_read_data == 'h00)
  ) $display("(15)Assertion successful: tb_read_data is 'h00 when we is 'h01.");
  else $fatal("(15)Assertion failed: Output does not match selected input at time %0t", $time);

  //----------------------------------------------------------------
  // xtea_core_test
  //
  // Test vectors from:
  //----------------------------------------------------------------
  initial
    begin : xtea_test
      $display("   -= Testbench for xtea started =-");
      $display("     ============================");
      $display("");

      init_sim();
      reset_dut();

      tc1();
      tc2();

      display_test_result();
      $display("");
      $display("*** xtea simulation done. ***");
      $finish;
    end // xtea_test
endmodule // tb_xtea

//======================================================================
// EOF tb_xtea.v
//======================================================================
