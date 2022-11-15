`timescale 1ns/1ns
`include "mem_path.vh"

// This testbench consolidates all the software tests that relies on the CSR check.
// A software test is compiled to a hex file, then loaded to the testbench for simulation.
// All the software tests have the same CSR check: if the expected result matches
// the generated result, 1 is written to the CSR which indicates a passing status.

module c_tests_tb();
  reg clk, rst;
  parameter CPU_CLOCK_PERIOD = 20;
  parameter CPU_CLOCK_FREQ   = 1_000_000_000 / CPU_CLOCK_PERIOD;

  localparam TIMEOUT_CYCLE = 100_000;

  initial clk = 0;
  always #(CPU_CLOCK_PERIOD/2) clk = ~clk;

  reg bp_enable = 1'b0;

  cpu # (
    .CPU_CLOCK_FREQ(CPU_CLOCK_FREQ),
    .RESET_PC(32'h1000_0000)
  ) cpu (
    .clk(clk),
    .rst(rst),
    .bp_enable(bp_enable),
    .serial_in(1'b1), // input
    .serial_out()     // output
  );

  reg [31:0] cycle;
  always @(posedge clk) begin
    if (rst === 1)
      cycle <= 0;
    else
      cycle <= cycle + 1;
  end

  reg [255:0] MIF_FILE;
  string hex_file, test_name;
  initial begin
    if (!$value$plusargs("hex_file=%s", hex_file)) begin
      $display("Must supply hex_file!");
      $fatal();
    end

    if (!$value$plusargs("test_name=%s", test_name)) begin
      $display("Must supply test_name!");
      $fatal();
    end

    $readmemh(hex_file, `IMEM_PATH.mem, 0, 16384-1);
    $readmemh(hex_file, `DMEM_PATH.mem, 0, 16384-1);

    `ifndef IVERILOG
      $vcdpluson;
    `endif
    `ifdef IVERILOG
      $dumpfile({test_name, ".fst"});
      $dumpvars(0, c_tests_tb);
    `endif

    rst = 1;

    // Hold reset for a while
    repeat (10) @(posedge clk);

    @(negedge clk);
    rst = 0;

    // Delay for some time
    repeat (10) @(posedge clk);

    // Wait until csr is updated
    while (`CSR_PATH === 0)
      @(posedge clk);

    if (`CSR_PATH === 32'b1) begin
      $display("[%d sim. cycles] CSR test PASSED!", cycle);
    end else begin
      $display("[%d sim. cycles] CSR test FAILED!", cycle);
    end

    repeat (100) @(posedge clk);
    $finish();
  end

  initial begin
    repeat (TIMEOUT_CYCLE) @(posedge clk);
    $display("Timeout!");
    $finish();
  end

endmodule
