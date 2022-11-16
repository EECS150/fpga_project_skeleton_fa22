`timescale 1ns/1ns
`include "mem_path.vh"

module asm_tb();
  reg clk, rst;
  parameter CPU_CLOCK_PERIOD = 20;
  parameter CPU_CLOCK_FREQ   = 1_000_000_000 / CPU_CLOCK_PERIOD;

  initial clk = 0;
  always #(CPU_CLOCK_PERIOD/2) clk = ~clk;
  
  reg bp_enable = 1'b0;

  cpu # (
    .CPU_CLOCK_FREQ(CPU_CLOCK_FREQ)
  ) cpu (
    .clk(clk),
    .rst(rst),
    .bp_enable(bp_enable),
    .serial_in(1'b1),
    .serial_out()
  );

  // A task to check if the value contained in a register equals an expected value
  task check_reg;
    input [4:0] reg_number;
    input [31:0] expected_value;
    input [10:0] test_num;
    if (expected_value !== `RF_PATH.mem[reg_number]) begin
      $display("FAIL - test %d, got: %d, expected: %d for reg %d",
               test_num, `RF_PATH.mem[reg_number], expected_value, reg_number);
      $finish();
    end
    else begin
      $display("PASS - test %d, got: %d for reg %d", test_num, expected_value, reg_number);
    end
  endtask

  // A task that runs the simulation until a register contains some value
  task wait_for_reg_to_equal;
    input [4:0] reg_number;
    input [31:0] expected_value;
    while (`RF_PATH.mem[reg_number] !== expected_value)
      @(posedge clk);
  endtask

  initial begin
    $readmemh("../../software/asm/asm.hex", `BIOS_PATH.mem, 0, 4095);

    `ifndef IVERILOG
        $vcdpluson;
    `endif
    `ifdef IVERILOG
        $dumpfile("asm_tb.fst");
        $dumpvars(0, asm_tb);
    `endif
    rst = 0;

    // Reset the CPU
    rst = 1;
    repeat (10) @(posedge clk);             // Hold reset for 10 cycles
    @(negedge clk);
    rst = 0;

    // Your processor should begin executing the code in /software/asm/start.s

    // Test ADD
    wait_for_reg_to_equal(20, 32'd1);       // Run the simulation until the flag is set to 1
    check_reg(1, 32'd300, 1);               // Verify that x1 contains 300

    // Test BEQ
    wait_for_reg_to_equal(20, 32'd2);       // Run the simulation until the flag is set to 2
    check_reg(1, 32'd500, 2);               // Verify that x1 contains 500
    check_reg(2, 32'd100, 3);               // Verify that x2 contains 100
    $display("ALL ASSEMBLY TESTS PASSED!");
    $finish();
  end

  initial begin
    repeat (100) @(posedge clk);
    $display("Failed: timing out");
    $fatal();
  end
endmodule
