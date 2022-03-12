`timescale 1ns/1ns
`include "../src/riscv_core/Opcode.vh"
`include "mem_path.vh"

`define FNC7_0  7'b0000000 // ADD, SRL
`define FNC7_1  7'b0100000 // SUB, SRA
`define OPC_CSR 7'b1110011

module bios_testbench();
  reg clk, rst;
  parameter CPU_CLOCK_PERIOD = 20;
  parameter CPU_CLOCK_FREQ   = 1_000_000_000 / CPU_CLOCK_PERIOD;
  localparam BAUD_RATE       = 115_200;
  localparam BAUD_PERIOD     = 1_000_000_000 / BAUD_RATE; // 8680.55 ns

  localparam TIMEOUT_CYCLE = 10_000_000;

  initial clk = 0;
  always #(CPU_CLOCK_PERIOD/2) clk = ~clk;

  reg  serial_in;
  wire serial_out;

  Riscv151 # (
    .CPU_CLOCK_FREQ(CPU_CLOCK_FREQ),
    .BIOS_MIF_HEX("bios151v3.mif")
  ) CPU (
    .clk(clk),
    .rst(rst),
    .FPGA_SERIAL_RX(serial_in),   // input
    .FPGA_SERIAL_TX(serial_out),  // output
    .csr()
  );

  integer i, j;
  reg [31:0] cycle;
  always @(posedge clk) begin
    if (rst === 1)
      cycle <= 0;
    else
      cycle <= cycle + 1;
  end

  // Host off-chip UART --> FPGA on-chip UART (receiver)
  // The host (testbench) sends a character to the CPU via the serial line
  task host_to_fpga;
    input [7:0] char_in;
    begin
      serial_in = 0;
      #(BAUD_PERIOD);
      // Data bits (payload)
      for (i = 0; i < 8; i = i + 1) begin
        serial_in = char_in[i];
        #(BAUD_PERIOD);
      end
      // Stop bit
      serial_in = 1;
      #(BAUD_PERIOD);

      $display("[time %t, sim. cycle %d] [Host (tb) --> FPGA_SERIAL_RX] Sent char 8'h%h",
               $time, cycle, char_in);
    end
  endtask

  reg [9:0] char_out;
  reg [63:0] test_status;
  reg [31:0] num_failed_tests = 0;

  // Host off-chip UART <-- FPGA on-chip UART (transmitter)
  // The host (testbench) expects to receive a character from the CPU via the serial line 
  task fpga_to_host;
    input [7:0] expected_char;
    begin
      // Wait until serial_out is LOW (start of transaction)
      wait (serial_out === 1'b0);

      for (j = 0; j < 10; j = j + 1) begin
        // sample output half-way through the baud period to avoid tricky edge cases
        #(BAUD_PERIOD / 2);
        char_out[j] = serial_out;
        #(BAUD_PERIOD / 2);
      end

      if (expected_char === char_out[8:1]) begin
        test_status = "PASSED";
      end
      else begin
        test_status = "FAILED";
        num_failed_tests = num_failed_tests + 1;
      end

      $display("[time %t, sim. cycle %d] [Host (tb) <-- FPGA_SERIAL_TX] Got char 8'h%h, expected 8'h%h, == %s [ %s ]",
               $time, cycle, char_out[8:1], expected_char, expected_char, test_status);
    end
  endtask

  reg [14:0] INST_ADDR;
  reg [31:0] IMM;

  initial begin
     #1;

     // Initialize IMem with the instruction: addi x3, x0, 8
    IMM[11:0] = 8;
    INST_ADDR = 14'h0000;
    `IMEM_PATH.mem[INST_ADDR + 0] = {IMM[11:0], 5'd0, `FNC_ADD_SUB, 5'd3, `OPC_ARI_ITYPE};
  end

  initial begin
    $dumpfile("bios_testbench.vcd");
    $dumpvars;

    #0;
    rst = 1;
    serial_in = 1;

    // Hold reset for a while
    repeat (10) @(posedge clk);

    @(negedge clk);
    rst = 0;

    // Delay for some time
    repeat (10) @(posedge clk);

    $display("[TEST 1] BIOS startup. Expect to see: \\r\\n151> ");

    // initial printout from BIOS program
    fpga_to_host(8'h0d); // \r
    fpga_to_host(8'h0a); // \n
    fpga_to_host(8'h31); // 1
    fpga_to_host(8'h35); // 5
    fpga_to_host(8'h31); // 1
    fpga_to_host(8'h3e); // >
    fpga_to_host(8'h20); // [space]

    // Test invalid command
    $display("[TEST 2] Send an invalid command. Expect to see: \\n\\rUnrecognized token: ");
    fork
      begin
        host_to_fpga(8'h61); // 'a'
        host_to_fpga(8'h62); // 'b'
        host_to_fpga(8'h63); // 'c'
        host_to_fpga(8'h64); // 'd'
        host_to_fpga(8'h20); // [space]
      end
      begin
        // echo back the input characters ...
        fpga_to_host(8'h61); // 'a'
        fpga_to_host(8'h62); // 'b'
        fpga_to_host(8'h63); // 'c'
        fpga_to_host(8'h64); // 'd'
        fpga_to_host(8'h20); // '[space]'

        // message from BIOS program
        fpga_to_host(8'h0a); // '\n'
        fpga_to_host(8'h0d); // '\r'
        fpga_to_host(8'h55); // 'U'
        fpga_to_host(8'h6e); // 'n'
        fpga_to_host(8'h72); // 'r'
        fpga_to_host(8'h65); // 'e'
        fpga_to_host(8'h63); // 'c'
        fpga_to_host(8'h6f); // 'o'
        fpga_to_host(8'h67); // 'g'
        fpga_to_host(8'h6e); // 'n'
        fpga_to_host(8'h69); // 'i'
        fpga_to_host(8'h7a); // 'z'
        fpga_to_host(8'h65); // 'e'
        fpga_to_host(8'h64); // 'd'
        fpga_to_host(8'h20); // [space]
        fpga_to_host(8'h74); // 't'
        fpga_to_host(8'h6f); // 'o'
        fpga_to_host(8'h6b); // 'k'
        fpga_to_host(8'h65); // 'e'
        fpga_to_host(8'h6e); // 'n'
        fpga_to_host(8'h3a); // ':'
        fpga_to_host(8'h20); // [space]

        fpga_to_host(8'h61); // 'a'
        fpga_to_host(8'h62); // 'b'
        fpga_to_host(8'h63); // 'c'
        fpga_to_host(8'h64); // 'd'

        fpga_to_host(8'h0a); // \n
        fpga_to_host(8'h0d); // \r
        fpga_to_host(8'h31); // 1
        fpga_to_host(8'h35); // 5
        fpga_to_host(8'h31); // 1
        fpga_to_host(8'h3e); // >
        fpga_to_host(8'h20); // [space]

      end
    join

    // Test store command in BIOS mode
    $display("[TEST 3] Send [sw cafeaaaa 30000004] command. Expect to write 32'hcafeaaaa to both IMem[1] and DMem[1]");
    fork
      begin
        host_to_fpga(8'h73); // 's'
        host_to_fpga(8'h77); // 'w'
        host_to_fpga(8'h20); // [space]
        host_to_fpga(8'h63); // 'c'
        host_to_fpga(8'h61); // 'a'
        host_to_fpga(8'h66); // 'f'
        host_to_fpga(8'h65); // 'e'
        host_to_fpga(8'h61); // 'a'
        host_to_fpga(8'h61); // 'a'
        host_to_fpga(8'h61); // 'a'
        host_to_fpga(8'h61); // 'a'
        host_to_fpga(8'h20); // [space]
        host_to_fpga(8'h33); // '3'
        host_to_fpga(8'h30); // '0'
        host_to_fpga(8'h30); // '0'
        host_to_fpga(8'h30); // '0'
        host_to_fpga(8'h30); // '0'
        host_to_fpga(8'h30); // '0'
        host_to_fpga(8'h30); // '0'
        host_to_fpga(8'h34); // '4'
        host_to_fpga(8'h0d); // \r
      end
      begin
        // echo back the input characters ...
        fpga_to_host(8'h73); // 's'
        fpga_to_host(8'h77); // 'w'
        fpga_to_host(8'h20); // [space]
        fpga_to_host(8'h63); // 'c'
        fpga_to_host(8'h61); // 'a'
        fpga_to_host(8'h66); // 'f'
        fpga_to_host(8'h65); // 'e'
        fpga_to_host(8'h61); // 'a'
        fpga_to_host(8'h61); // 'a'
        fpga_to_host(8'h61); // 'a'
        fpga_to_host(8'h61); // 'a'
        fpga_to_host(8'h20); // [space]
        fpga_to_host(8'h33); // '3'
        fpga_to_host(8'h30); // '0'
        fpga_to_host(8'h30); // '0'
        fpga_to_host(8'h30); // '0'
        fpga_to_host(8'h30); // '0'
        fpga_to_host(8'h30); // '0'
        fpga_to_host(8'h30); // '0'
        fpga_to_host(8'h34); // '4'

        fpga_to_host(8'h0d); // \r
        fpga_to_host(8'h0a); // \n
        fpga_to_host(8'h31); // 1
        fpga_to_host(8'h35); // 5
        fpga_to_host(8'h31); // 1
        fpga_to_host(8'h3e); // >
        fpga_to_host(8'h20); // [space]
      end
    join

    $display("Imem[1]=%h DMem[1]=%h", `IMEM_PATH.mem[1], `DMEM_PATH.mem[1]);

    $display("Test Write to IMem");
    if (`IMEM_PATH.mem[1] === 32'hcafeaaaa) begin
      $display("PASSED!");
    end
    else
      $display("FAILED!");

    $display("Test Write to DMem");
    if (`DMEM_PATH.mem[1] === 32'hcafeaaaa) begin
      $display("PASSED!");
    end
    else
      $display("FAILED!");

    // Test load command in BIOS mode
    $display("[TEST 4] Send [lw 30000004] command. Expect to see: 30000004:cafeaaaa");
    fork
      begin
        host_to_fpga(8'h6c); // 'l'
        host_to_fpga(8'h77); // 'w'
        host_to_fpga(8'h20); // [space]
        host_to_fpga(8'h33); // '3'
        host_to_fpga(8'h30); // '0'
        host_to_fpga(8'h30); // '0'
        host_to_fpga(8'h30); // '0'
        host_to_fpga(8'h30); // '0'
        host_to_fpga(8'h30); // '0'
        host_to_fpga(8'h30); // '0'
        host_to_fpga(8'h34); // '4'
        host_to_fpga(8'h0d); // \r
      end
      begin
        // echo back the input characters ...
        fpga_to_host(8'h6c); // 'l'
        fpga_to_host(8'h77); // 'w'
        fpga_to_host(8'h20); // [space]
        fpga_to_host(8'h33); // '3'
        fpga_to_host(8'h30); // '0'
        fpga_to_host(8'h30); // '0'
        fpga_to_host(8'h30); // '0'
        fpga_to_host(8'h30); // '0'
        fpga_to_host(8'h30); // '0'
        fpga_to_host(8'h30); // '0'
        fpga_to_host(8'h34); // '4'
        fpga_to_host(8'h0d); // \r

        // message from BIOS program
        fpga_to_host(8'h0a); // \n
        fpga_to_host(8'h33); // '3'
        fpga_to_host(8'h30); // '0'
        fpga_to_host(8'h30); // '0'
        fpga_to_host(8'h30); // '0'
        fpga_to_host(8'h30); // '0'
        fpga_to_host(8'h30); // '0'
        fpga_to_host(8'h30); // '0'
        fpga_to_host(8'h34); // '4'
        fpga_to_host(8'h3a); // ':'
        fpga_to_host(8'h63); // 'c'
        fpga_to_host(8'h61); // 'a'
        fpga_to_host(8'h66); // 'f'
        fpga_to_host(8'h65); // 'e'
        fpga_to_host(8'h61); // 'a'
        fpga_to_host(8'h61); // 'a'
        fpga_to_host(8'h61); // 'a'
        fpga_to_host(8'h61); // 'a'

        fpga_to_host(8'h0d); // \r
        fpga_to_host(8'h0a); // \n
        fpga_to_host(8'h31); // 1
        fpga_to_host(8'h35); // 5
        fpga_to_host(8'h31); // 1
        fpga_to_host(8'h3e); // >
        fpga_to_host(8'h20); // [space]
      end
    join

    // Test jump command: switch to IMem address space
    $display("[TEST 5] Send [jal 10000000] command. Expect to see: jal 10000000");
    fork
      begin
        host_to_fpga(8'h6a); // 'j'
        host_to_fpga(8'h61); // 'a'
        host_to_fpga(8'h6c); // 'l'
        host_to_fpga(8'h20); // [space]
        host_to_fpga(8'h31); // '1'
        host_to_fpga(8'h30); // '0'
        host_to_fpga(8'h30); // '0'
        host_to_fpga(8'h30); // '0'
        host_to_fpga(8'h30); // '0'
        host_to_fpga(8'h30); // '0'
        host_to_fpga(8'h30); // '0'
        host_to_fpga(8'h30); // '0'
        host_to_fpga(8'h0d); // \r
      end
      begin
        // echo back the input characters ...
        fpga_to_host(8'h6a); // 'j'
        fpga_to_host(8'h61); // 'a'
        fpga_to_host(8'h6c); // 'l'
        fpga_to_host(8'h20); // [space]
        fpga_to_host(8'h31); // '1'
        fpga_to_host(8'h30); // '0'
        fpga_to_host(8'h30); // '0'
        fpga_to_host(8'h30); // '0'
        fpga_to_host(8'h30); // '0'
        fpga_to_host(8'h30); // '0'
        fpga_to_host(8'h30); // '0'
        fpga_to_host(8'h30); // '0'
        fpga_to_host(8'h0d); // \r
      end
    join

    // The instruction in IMem should be executed after jumping to IMem space
    $display("Test RF: RF[3]=%h", `RF_PATH.mem[3]);
    if (`RF_PATH.mem[3] === IMM[11:0]) begin
      $display("PASSED!");
    end
    else
      $display("FAILED!");

    #100;
    $display("BIOS testbench done! Num failed tests: %d", num_failed_tests);
    $finish();
  end

  initial begin
    repeat (TIMEOUT_CYCLE) @(posedge clk);
    $display("Timeout!");
    $finish();
  end

endmodule
