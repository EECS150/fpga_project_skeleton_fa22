`include "axi_consts.vh"

module xcel_opt #(
  parameter AXI_AWIDTH = 32,
  parameter AXI_DWIDTH = 32,
  parameter WT_DIM = 5
) (
  input clk,
  input rst,

  output                  xcel_read_request_valid,
  input                   xcel_read_request_ready,
  output [AXI_AWIDTH-1:0] xcel_read_addr,
  output [31:0]           xcel_read_len,
  output [2:0]            xcel_read_size,
  output [1:0]            xcel_read_burst,
  input  [AXI_DWIDTH-1:0] xcel_read_data,
  input                   xcel_read_data_valid,
  output                  xcel_read_data_ready,

  output                  xcel_write_request_valid,
  input                   xcel_write_request_ready,
  output [AXI_AWIDTH-1:0] xcel_write_addr,
  output [31:0]           xcel_write_len,
  output [2:0]            xcel_write_size,
  output [1:0]            xcel_write_burst,
  output [AXI_DWIDTH-1:0] xcel_write_data,
  output                  xcel_write_data_valid,
  input                   xcel_write_data_ready,
 
  input  xcel_start,
  output xcel_done,
  output xcel_idle
);

  // TODO: Your code to implement an optimized hardware accelerator.

endmodule
