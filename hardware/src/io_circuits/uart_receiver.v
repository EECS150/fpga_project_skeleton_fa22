
module uart_receiver #(
  parameter CLOCK_FREQ = 125_000_000,
  parameter BAUD_RATE  = 115_200
) (
  input clk,
  input rst,

  output [7:0] data_out,
  output data_out_valid,
  input data_out_ready,

  input serial_in
);

  // See diagram in the lab guide
  localparam integer SYMBOL_EDGE_TIME = CLOCK_FREQ / BAUD_RATE;
  localparam integer SAMPLE_TIME      = SYMBOL_EDGE_TIME / 2;
  localparam CLOCK_COUNTER_WIDTH      = $clog2(SYMBOL_EDGE_TIME);

  wire [9:0] rx_shift_value;
  wire [9:0] rx_shift_next;
  wire rx_shift_ce;

  // MSB to LSB
  REGISTER_CE #(.N(10)) rx_shift (
    .q(rx_shift_value),
    .d(rx_shift_next),
    .ce(rx_shift_ce),
    .clk(clk)
  );

  wire [3:0] bit_counter_value;
  wire [3:0] bit_counter_next;
  wire bit_counter_ce, bit_counter_rst;

  REGISTER_R_CE #(.N(4), .INIT(0)) bit_counter (
    .q(bit_counter_value),
    .d(bit_counter_next),
    .ce(bit_counter_ce),
    .rst(bit_counter_rst),
    .clk(clk)
  );

  wire [CLOCK_COUNTER_WIDTH-1:0] clock_counter_value;
  wire [CLOCK_COUNTER_WIDTH-1:0] clock_counter_next;
  wire clock_counter_ce, clock_counter_rst;

  // Keep track of sample time and symbol edge time
  REGISTER_R_CE #(.N(CLOCK_COUNTER_WIDTH), .INIT(0)) clock_counter (
    .q(clock_counter_value),
    .d(clock_counter_next),
    .ce(clock_counter_ce),
    .rst(clock_counter_rst),
    .clk(clk)
  );

  wire data_out_fire = data_out_valid & data_out_ready;

  wire symbol_edge = (clock_counter_value == SYMBOL_EDGE_TIME - 1);
  wire sample_time = (clock_counter_value == SAMPLE_TIME - 1);
  wire done        = (bit_counter_value == 10 - 1) & sample_time;

  // 'has_byte' becomes HIGH once we finish sampling all 10 bits
  // ({stop_bit, char[7:0], start_bit}) from the serial interface
  wire has_byte;
  REGISTER_R_CE #(.N(1), .INIT(0)) has_byte_reg (
    .q(has_byte),
    .d(1'b1),
    .ce(done),
    .rst(data_out_fire),
    .clk(clk)
  );

  // 'start' becomes HIGH once we receive the start bit ('0') and
  // the bit counter has not started counting
  wire start;
  REGISTER_R_CE #(.N(1), .INIT(0)) start_reg (
    .q(start),
    .d(1'b1),
    .ce((serial_in == 0) && (bit_counter_value == 0)),
    .rst(done),
    .clk(clk)
  );

  assign rx_shift_next = {serial_in, rx_shift_value[9:1]};
  assign rx_shift_ce   = sample_time;

  assign bit_counter_next = bit_counter_value + 1;
  assign bit_counter_ce   = symbol_edge;
  assign bit_counter_rst  = done | rst;

  assign clock_counter_next = clock_counter_value + 1;
  assign clock_counter_ce   = start;
  assign clock_counter_rst  = symbol_edge | done | rst;

  assign data_out       = rx_shift_value[8:1];
  assign data_out_valid = has_byte;

endmodule
