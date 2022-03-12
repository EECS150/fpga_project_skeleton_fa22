
module uart_transmitter #(
  parameter CLOCK_FREQ = 125_000_000,
  parameter BAUD_RATE = 115_200
) (
  input clk,
  input rst,

  input [7:0] data_in,
  input data_in_valid,
  output data_in_ready,

  output serial_out
);

  // TODO: Your code

endmodule
