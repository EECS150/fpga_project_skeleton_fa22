
module debouncer #(
  parameter WIDTH              = 1,
  parameter SAMPLE_CNT_MAX     = 25000,
  parameter PULSE_CNT_MAX      = 150,
  parameter WRAPPING_CNT_WIDTH = $clog2(SAMPLE_CNT_MAX) + 1,
  parameter SAT_CNT_WIDTH      = $clog2(PULSE_CNT_MAX) + 1
) (
  input clk,
  input [WIDTH-1:0] glitchy_signal,
  output [WIDTH-1:0] debounced_signal
);

  // TODO: Your code

endmodule
