
module Riscv151 #(
  parameter CPU_CLOCK_FREQ = 50_000_000,
  parameter RESET_PC       = 32'h4000_0000,
  parameter BAUD_RATE      = 115200,
  parameter BIOS_MIF_HEX   = "bios151v3.mif"
) (
  input  clk,
  input  rst,
  input  FPGA_SERIAL_RX,
  output FPGA_SERIAL_TX,
  output [31:0] csr
);
  // Memories
  localparam BIOS_AWIDTH = 11;
  localparam BIOS_DWIDTH = 32;

  wire [BIOS_AWIDTH-1:0] bios_addra, bios_addrb;
  wire [BIOS_DWIDTH-1:0] bios_douta, bios_doutb;

  // BIOS Memory
  // Synchronous read: read takes one cycle
  // Synchronous write: write takes one cycle
  SYNC_ROM_DP #(
    .AWIDTH(BIOS_AWIDTH),
    .DWIDTH(BIOS_DWIDTH),
    .MIF_HEX(BIOS_MIF_HEX)
  ) bios_mem(
    .q0(bios_douta),    // output
    .addr0(bios_addra), // input
    .en0(1'b1),

    .q1(bios_doutb),    // output
    .addr1(bios_addrb), // input
    .en1(1'b1),

    .clk(clk)
  );

  localparam DMEM_AWIDTH = 14;
  localparam DMEM_DWIDTH = 32;

  wire [DMEM_AWIDTH-1:0] dmem_addra;
  wire [DMEM_DWIDTH-1:0] dmem_dina, dmem_douta;
  wire [3:0] dmem_wea;

  // Data Memory
  // Synchronous read: read takes one cycle
  // Synchronous write: write takes one cycle
  // Write-byte-enable: select which of the four bytes to write
  SYNC_RAM_WBE #(
    .AWIDTH(DMEM_AWIDTH),
    .DWIDTH(DMEM_DWIDTH)
  ) dmem (
    .q(dmem_douta),    // output
    .d(dmem_dina),     // input
    .addr(dmem_addra), // input
    .wbe(dmem_wea),    // input
    .en(1'b1),
    .clk(clk)
  );

  localparam IMEM_AWIDTH = 14;
  localparam IMEM_DWIDTH = 32;

  wire [IMEM_AWIDTH-1:0] imem_addra, imem_addrb;
  wire [IMEM_DWIDTH-1:0] imem_douta, imem_doutb;
  wire [IMEM_DWIDTH-1:0] imem_dina, imem_dinb;
  wire [3:0] imem_wea, imem_web;

  // Instruction Memory
  // Synchronous read: read takes one cycle
  // Synchronous write: write takes one cycle
  // Write-byte-enable: select which of the four bytes to write
  SYNC_RAM_DP_WBE #(
    .AWIDTH(IMEM_AWIDTH),
    .DWIDTH(IMEM_DWIDTH)
  ) imem (
    .q0(imem_douta),    // output
    .d0(imem_dina),     // input
    .addr0(imem_addra), // input
    .wbe0(imem_wea),    // input
    .en0(1'b1),

    .q1(imem_doutb),    // output
    .d1(imem_dinb),     // input
    .addr1(imem_addrb), // input
    .wbe1(imem_web),    // input
    .en1(1'b1),

    .clk(clk)
  );

  wire rf_we;
  wire [4:0]  rf_ra1, rf_ra2, rf_wa;
  wire [31:0] rf_wd;
  wire [31:0] rf_rd1, rf_rd2;

  // Asynchronous read: read data is available in the same cycle
  // Synchronous write: write takes one cycle
  ASYNC_RAM_1W2R # (
    .AWIDTH(5),
    .DWIDTH(32)
  ) rf (
    .d0(rf_wd),     // input
    .addr0(rf_wa),  // input
    .we0(rf_we),    // input

    .q1(rf_rd1),    // output
    .addr1(rf_ra1), // input

    .q2(rf_rd2),    // output
    .addr2(rf_ra2), // input

    .clk(clk)
  );

  // UART Receiver
  wire [7:0] uart_rx_data_out;
  wire uart_rx_data_out_valid;
  wire uart_rx_data_out_ready;

  uart_receiver #(
    .CLOCK_FREQ(CPU_CLOCK_FREQ),
    .BAUD_RATE(BAUD_RATE)
  ) uart_rx (
    .clk(clk),
    .rst(rst),
    .data_out(uart_rx_data_out),             // output
    .data_out_valid(uart_rx_data_out_valid), // output
    .data_out_ready(uart_rx_data_out_ready), // input
    .serial_in(FPGA_SERIAL_RX)               // input
  );

  // UART Transmitter
  wire [7:0] uart_tx_data_in;
  wire uart_tx_data_in_valid;
  wire uart_tx_data_in_ready;

  uart_transmitter #(
    .CLOCK_FREQ(CPU_CLOCK_FREQ),
    .BAUD_RATE(BAUD_RATE)
  ) uart_tx (
    .clk(clk),
    .rst(rst),
    .data_in(uart_tx_data_in),             // input
    .data_in_valid(uart_tx_data_in_valid), // input
    .data_in_ready(uart_tx_data_in_ready), // output
    .serial_out(FPGA_SERIAL_TX)            // output
  );

  // TODO: Your code to implement a fully functioning RISC-V core
  // Add as many modules as you want
  // Feel free to move the memory modules around

endmodule
