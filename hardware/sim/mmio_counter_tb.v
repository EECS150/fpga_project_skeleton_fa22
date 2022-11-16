`timescale 1ns/1ns

`include "../src/riscv_core/opcode.vh"
`include "mem_path.vh"

/*
  This testbench contains small sets of RV32I instructions to verify MMIO counters are working.
  It is based on cpu_tb.v.

  How does the testbench work?
  For each test, the testbench initializes IMem with one or several instructions
  (encoded in binary format as specified in the spec) for testing.
  RegFile and DMem are also initialized with some data.

  Each test program should contain the following instructions:
  1. Reset MMIO counters (task write_reset_cntr_inst)
  2. Some user-defined instructions
  3. Load MMIO counter values to registers, set CSR to 1, and then set CSR to 0 (task write_load_cntr_insts)

  Then, the clock is advanced until the CSR is set to 1 (indicating end of program).
  If no correct result is returned after a "timeout" cycle, the testbench will be terminated (or failed).

  Once all instructions are written into CPU's IMEM, the task run_cpu should be called,
  which will reset the CPU, wait for the program to finish, and then print counter values.

  Don't just run the testbench, look at the tests, see what they do.
  The testbench is intended to provide you some examples to get started.
  Feel free to make your own change.
  Note that the testbench is by no means exhaustive.
  You should add your own tests if there are cases you think the testbench
  does not cover.
*/

module mmio_counter_tb();
  reg clk, rst;
  parameter CPU_CLOCK_PERIOD = 20;
  parameter CPU_CLOCK_FREQ   = 1_000_000_000 / CPU_CLOCK_PERIOD;

  initial clk = 0;
  always #(CPU_CLOCK_PERIOD/2) clk = ~clk;
  wire [31:0] csr;
  reg bp_enable = 1'b0;

  // Init PC with 32'h1000_0000 -- address space of IMem
  // When PC is in IMem's address space, IMem is read-only
  // DMem can be R/W as long as the addr bits [31:28] is 4'b00x1
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

  wire [31:0] timeout_cycle = 100;  // TODO: change this to a larger number if longer program tests are added.

  // Reset IMem, DMem, and RegFile before running new test
  task reset;
    integer i;
    begin
      for (i = 0; i < `RF_PATH.DEPTH; i = i + 1) begin
        `RF_PATH.mem[i] = 0;
      end
      for (i = 0; i < `DMEM_PATH.DEPTH; i = i + 1) begin
        `DMEM_PATH.mem[i] = 0;
      end
      for (i = 0; i < `IMEM_PATH.DEPTH; i = i + 1) begin
        `IMEM_PATH.mem[i] = 0;
      end
    end
  endtask

  task reset_cpu;
    @(negedge clk);
    rst = 1;
    @(negedge clk);
    rst = 0;
  endtask

  reg [31:0] cycle;
  reg done;
  reg [255:0] current_test_type;
  reg all_tests_passed = 0;


  // Check for timeout
  // If a test does not set CSR to 1 in a given timeout cycle, we terminate the testbench
  initial begin
    while (all_tests_passed === 0) begin
      @(posedge clk);
      if (cycle === timeout_cycle) begin
        $display("[Failed] Timeout at test %s, CSR = %x", current_test_type, `CSR_PATH);
        $finish();
      end
    end
  end

  always @(posedge clk) begin
    if (done === 0)
      cycle <= cycle + 1;
    else
      cycle <= 0;
  end

  integer i;

  reg [31:0] IMM;
  reg [14:0] INST_ADDR;

  // Display RegFile register value
  task display_result_rf;
    input [31:0]  rf_addr;
    input [255:0] test_type;
    begin
      $display("%s : %d", test_type, `RF_PATH.mem[rf_addr]);
    end
  endtask

  task display_counter_values;
    begin
      display_result_rf(5'd7, "Cycle");
      display_result_rf(5'd8, "Instruction");
      display_result_rf(5'd9, "Branch Instruction");
      display_result_rf(5'd10, "Correct Branch Prediction");
    end
  endtask

  task write_reset_cntr_inst;
    begin
      `RF_PATH.mem[1] = 32'hxxxx_xxxx;
      `RF_PATH.mem[2] = 32'h8000_0018;  // The reset counter address
      `IMEM_PATH.mem[INST_ADDR] = {7'd0, 5'd1, 5'd2, `FNC_SW, 5'd0, `OPC_STORE};
      INST_ADDR = INST_ADDR + 'd1;
    end
  endtask

  task write_load_cntr_insts;
    begin
      `RF_PATH.mem[3] = 32'h8000_0010;  // The cycle counter address
      `RF_PATH.mem[4] = 32'h8000_0014;  // The instruction counter address
      `RF_PATH.mem[5] = 32'h8000_001c;  // The branch instruction counter address
      `RF_PATH.mem[6] = 32'h8000_0020;  // The correct branch prediction counter address

      `IMEM_PATH.mem[INST_ADDR + 0] = {12'd0,   5'd3, `FNC_LW, 5'd7,  `OPC_LOAD};
      `IMEM_PATH.mem[INST_ADDR + 1] = {12'd0,   5'd4, `FNC_LW, 5'd8,  `OPC_LOAD};
      `IMEM_PATH.mem[INST_ADDR + 2] = {12'd0,   5'd5, `FNC_LW, 5'd9,  `OPC_LOAD};
      `IMEM_PATH.mem[INST_ADDR + 3] = {12'd0,   5'd6, `FNC_LW, 5'd10, `OPC_LOAD};
      `IMEM_PATH.mem[INST_ADDR + 4] = {12'h51e, 5'd1, 3'b101,  5'd0,  `OPC_CSR};
      `IMEM_PATH.mem[INST_ADDR + 5] = {12'h51e, 5'd0, 3'b101,  5'd0,  `OPC_CSR};
      INST_ADDR = INST_ADDR + 'd6;
    end
  endtask

  task write_nop_inst;
    begin
      // NOP (ADDI x0, x0, 0)
      `IMEM_PATH.mem[INST_ADDR] = {12'd0, 5'd0, `FNC_ADD_SUB, 5'd0, `OPC_ARI_ITYPE};
      INST_ADDR = INST_ADDR + 'd1;
    end
  endtask

  task write_for_loop_program_insts;
    input [11:0]  max_iter;
    reg [4:0] RVAR;
    /*
    
    Implements the following code:
    1. Initialize RVAR to max_iter (ADDI RVAR, x0, max_iter)
    2. Decrement RVAR by 1         (SUB  RVAR, RVAR, -1)
    3. Go back to #2 if RVAR != 0  (BEQ  RVAR, x0, -4)

    In other words, the pseudocode is "for (x = max_iter - 1; x != 0; x = x - 1);"
    */
    begin
      RVAR = 5'd11;
      IMM  = 32'hffff_fffc;
      `IMEM_PATH.mem[INST_ADDR + 0] = {max_iter, 5'd0, `FNC_ADD_SUB, RVAR, `OPC_ARI_ITYPE};
      `IMEM_PATH.mem[INST_ADDR + 1] = {12'hfff, RVAR, `FNC_ADD_SUB, RVAR, `OPC_ARI_ITYPE};
      `IMEM_PATH.mem[INST_ADDR + 2] = {IMM[12], IMM[10:5], 5'd0, RVAR, `FNC_BNE, IMM[4:1], IMM[11], `OPC_BRANCH};
      INST_ADDR = INST_ADDR + 'd3;
    end
  endtask

  task run_cpu;
    begin
      reset_cpu();
      done = 0;
      wait (`CSR_PATH === 1);
      done = 1;
      display_counter_values();
      wait (`CSR_PATH === 0);
    end
  endtask

  initial begin
    `ifndef IVERILOG
        $vcdpluson;
        $vcdplusmemon;
    `endif
    `ifdef IVERILOG
        $dumpfile("mmio_counter_tb.fst");
        $dumpvars(0, mmio_counter_tb);
    `endif

    #0;
    rst = 0;

    // Reset the CPU
    rst = 1;
    // Hold reset for a while
    repeat (10) @(posedge clk);

    @(negedge clk);
    rst = 0;

    // Test NOP Insts --------------------------------------------------
    current_test_type = "NOP";
    $display("Benchmarking %s Program", current_test_type);

    reset();

    // Write program
    INST_ADDR = 14'h0000;
    write_reset_cntr_inst();
    for (i = 0; i < 10; i = i + 1) begin
      write_nop_inst();
    end
    write_load_cntr_insts();

    run_cpu();

    // Test Branching Insts --------------------------------------------
    current_test_type = "For Loop";
    $display("Benchmarking %s Program", current_test_type);
    reset();

    // Write program
    INST_ADDR = 14'h0000;
    write_reset_cntr_inst();
    write_for_loop_program_insts(10);
    write_load_cntr_insts();

    run_cpu();

    // ... what else?
    all_tests_passed = 1'b1;

    repeat (100) @(posedge clk);
    $display("All tests passed!");
    $finish();
  end

endmodule
