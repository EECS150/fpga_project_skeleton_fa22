`timescale 1ns/1ns

module z1top (
  input  CLK_125MHZ_FPGA,
  input  [3:0] BUTTONS,
  input  [1:0] SWITCHES,
  output [5:0] LEDS,

  input  FPGA_SERIAL_RX,
  output FPGA_SERIAL_TX
);

  wire cpu_clk;

  localparam CPU_CLOCK_PERIOD = 20;
  localparam CPU_CLOCK_FREQ   = 1_000_000_000 / CPU_CLOCK_PERIOD;
  // Clocking wizard IP from Vivado (wrapper of the PLLE module)
  // Generate CPU_CLOCK_FREQ clock from 125 MHz clock
  // PLL FREQ = (CLKFBOUT_MULT_F * 1000 / (CLKINx_PERIOD * DIVCLK_DIVIDE) must be within (800.000 MHz - 1600.000 MHz)
  // CLKOUTx_PERIOD = CLKINx_PERIOD x DIVCLK_DIVIDE x CLKOUT0_DIVIDE / CLKFBOUT_MULT_F
  clk_wiz #(
    .CLKIN1_PERIOD(8),
    .CLKFBOUT_MULT_F(8),
    .DIVCLK_DIVIDE(1),
    .CLKOUT0_DIVIDE(CPU_CLOCK_PERIOD)
  ) clk_wiz (
    .clk_out1(cpu_clk),       // output
    .reset(1'b0),             // input
    .locked(),                // output, unused
    .clk_in1(CLK_125MHZ_FPGA) // input
  );

  // Button parser
  // Sample the button signal every 500us
  localparam integer B_SAMPLE_CNT_MAX = 0.0005 * CPU_CLOCK_FREQ;
  // The button is considered 'pressed' after 100ms of continuous pressing
  localparam integer B_PULSE_CNT_MAX = 0.100 / 0.0005;

  wire [3:0] buttons_pressed;
  button_parser #(
    .WIDTH(4),
    .SAMPLE_CNT_MAX(B_SAMPLE_CNT_MAX),
    .PULSE_CNT_MAX(B_PULSE_CNT_MAX)
  ) bp (
    .clk(cpu_clk),
    .in(BUTTONS),
    .out(buttons_pressed)
  );

  wire reset = (buttons_pressed[0] & SWITCHES[1]);
  wire [31:0] csr;

  wire cpu_tx, cpu_rx;
  Riscv151 #(
    .CPU_CLOCK_FREQ(CPU_CLOCK_FREQ)
  ) cpu (
    .clk(cpu_clk),
    .rst(reset),
    .FPGA_SERIAL_TX(FPGA_SERIAL_TX),
    .FPGA_SERIAL_RX(FPGA_SERIAL_RX),
    .csr(csr)
  );

  assign LEDS[5:0] = csr[5:0];

endmodule
