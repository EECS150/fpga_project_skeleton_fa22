`timescale 1ns/1ns
`include "mem_path.vh"

module isa_tb();
  reg clk, rst;
  parameter CPU_CLOCK_PERIOD = 20;
  parameter CPU_CLOCK_FREQ   = 1_000_000_000 / CPU_CLOCK_PERIOD;

  localparam TIMEOUT_CYCLE = 1000;

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
    .serial_in(1'b1),
    .serial_out()
  );

  reg [31:0] cycle;
  always @(posedge clk) begin
    if (rst === 1)
      cycle <= 0;
    else
      cycle <= cycle + 1;
  end

  string hex_file;
  string test_name;
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

    $dumpfile({test_name, ".fst"});
    $dumpvars(0, isa_tb);

    rst = 0;

    // Reset the CPU
    rst = 1;
    repeat (30) @(posedge clk); // Hold reset for 30 cycles

    @(negedge clk);
    rst = 0;

    // Wait until csr[0] is asserted
    while (`CSR_PATH[0] !== 1'b1)
      @(posedge clk);

    if (`CSR_PATH[0] === 1'b1 && `CSR_PATH[31:1] === 31'b0) begin
      $display("[passed] - %s in %d simulation cycles", test_name, cycle);
    end else begin
      $display("[failed] - %s. Failed test: %d", test_name, `CSR_PATH[31:1]);
    end
    $finish();
  end

  initial begin
    repeat (TIMEOUT_CYCLE) @(posedge clk);
    $display("Timeout!");
    $finish();
  end

endmodule
