`include "axi_consts.vh"
`include "lenet_consts.vh"

// This module implements conv3D
// The weight parameter is statically configured (Verilog parameters)
// The IFM and OFM paramters (dimension, depth) are set by the
// software program runnning on the CPU via Memory-mapped IO addresses
// (dynamically configured)
module xcel_naive #(
  parameter AXI_AWIDTH = 32,
  parameter AXI_DWIDTH = 32,
  parameter WT_DIM     = 5
) (
  input clk,
  input rst,

  // (simplified) read request address and read data channel for
  // interfacing with AXI adapter read
  output                  xcel_read_request_valid,
  input                   xcel_read_request_ready,
  output [AXI_AWIDTH-1:0] xcel_read_addr,
  output [31:0]           xcel_read_len,
  output [2:0]            xcel_read_size,
  output [1:0]            xcel_read_burst,
  input  [AXI_DWIDTH-1:0] xcel_read_data,
  input                   xcel_read_data_valid,
  output                  xcel_read_data_ready,

  // (simplified) write request address and write data channel for
  // interfacing with AXI adapter write
  output                  xcel_write_request_valid,
  input                   xcel_write_request_ready,
  output [AXI_AWIDTH-1:0] xcel_write_addr,
  output [31:0]           xcel_write_len,
  output [2:0]            xcel_write_size,
  output [1:0]            xcel_write_burst,
  output [AXI_DWIDTH-1:0] xcel_write_data,
  output                  xcel_write_data_valid,
  input                   xcel_write_data_ready,

  // For interfacing with IO controller logic in Riscv151
  input  xcel_start,
  output xcel_done,
  output xcel_idle,

  input [31:0] ifm_ddr_addr, // IFM address in DDR
  input [31:0] wt_ddr_addr,  // WT address in DDR
  input [31:0] ofm_ddr_addr, // OFM address in DDR

  input [31:0] ifm_dim,
  input [31:0] ifm_depth,
  input [31:0] ofm_dim,
  input [31:0] ofm_depth
);

  localparam integer WT_SIZE = WT_DIM * WT_DIM;
  localparam DWIDTH = 8;

  wire [31:0] ifm_size;  // ifm_dim * ifm_dim
  wire [31:0] ifm_len;   // ifm_depth * ifm_dim * ifm_dim

  wire [31:0] wt_volume; // ifm_depth * WT_DIM * WT_DIM
  wire [31:0] wt_len;    // ofm_depth * ifm_depth * WT_DIM * WT_DIM

  wire [31:0] ofm_size;  // ofm_dim * ofm_dim
  wire [31:0] ofm_len;   // ofm_depth * ofm_dim * ofm_dim

  // Register the configuration from Riscv151 IO
  REGISTER #(.N(32)) ifm_size_reg (
    .clk(clk),
    .d(ifm_dim * ifm_dim),
    .q(ifm_size)
  );

  REGISTER #(.N(32)) ifm_len_reg (
    .clk(clk),
    .d(ifm_size * ifm_depth),
    .q(ifm_len)
  );

  REGISTER #(.N(32)) wt_volume_reg (
    .clk(clk),
    .d(WT_SIZE * ifm_depth),
    .q(wt_volume)
  );

  REGISTER #(.N(32)) wt_len_reg (
    .clk(clk),
    .d(wt_volume * ofm_depth),
    .q(wt_len)
  );

  REGISTER #(.N(32)) ofm_size_reg (
    .clk(clk),
    .d(ofm_dim * ofm_dim),
    .q(ofm_size)
  );

  REGISTER #(.N(32)) ofm_len_reg (
    .clk(clk),
    .d(ofm_size * ofm_depth),
    .q(ofm_len)
  );

  wire [31:0]       wt_addr;
  wire [DWIDTH-1:0] wt_dout;
  wire wt_dout_valid;
  wire wt_dout_ready;

  wire [31:0]       ifm_addr;
  wire [DWIDTH-1:0] ifm_dout;
  wire ifm_dout_valid;
  wire ifm_dout_ready;

  wire [31:0] ofm_addr0;
  wire [31:0] ofm_dout0;
  wire ofm_dout0_valid;
  wire ofm_dout0_ready;

  wire [31:0] ofm_addr1;
  wire [31:0] ofm_din1;
  wire ofm_din1_valid;
  wire ofm_din1_ready;
  wire ofm_we1;

  wire compute_start, compute_done, compute_idle;

  // Compute unit: handles 3D Convolution operation
  xcel_naive_compute #(
    .DWIDTH(DWIDTH),
    .WT_DIM(WT_DIM)
  ) compute_unit (
    .clk(clk),
    .rst(rst),

    // IFM read (request to the memif_unit)
    .ifm_addr(ifm_addr),               // output
    .ifm_dout(ifm_dout),               // input
    .ifm_dout_valid(ifm_dout_valid),   // input
    .ifm_dout_ready(ifm_dout_ready),   // output

    // WT read (request to the memif_unit)
    .wt_addr(wt_addr),                 // output
    .wt_dout(wt_dout),                 // input
    .wt_dout_valid(wt_dout_valid),     // input
    .wt_dout_ready(wt_dout_ready),     // output

    // OFM read (request to the memif_unit)
    .ofm_addr0(ofm_addr0),             // output
    .ofm_dout0(ofm_dout0),             // input
    .ofm_dout0_valid(ofm_dout0_valid), // input
    .ofm_dout0_ready(ofm_dout0_ready), // output

    // OFM write (request to the memif_unit)
    .ofm_addr1(ofm_addr1),             // output
    .ofm_din1(ofm_din1),               // output 
    .ofm_din1_valid(ofm_din1_valid),   // output
    .ofm_din1_ready(ofm_din1_ready),   // input
    .ofm_we1(ofm_we1),

    // control & status signals
    .compute_start(compute_start),     // input
    .compute_idle(compute_idle),       // output
    .compute_done(compute_done),       // output

    // parameters
    .ifm_dim(ifm_dim),
    .ifm_size(ifm_size),
    .ifm_depth(ifm_depth),
    .ifm_len(ifm_len),

    .wt_volume(wt_volume),
    .wt_len(wt_len),

    .ofm_dim(ofm_dim),
    .ofm_size(ofm_size),
    .ofm_depth(ofm_depth),
    .ofm_len(ofm_len)
  );

  // Memory Interface unit: handles DDR read and write transactions
  xcel_naive_memif #(
    .AXI_AWIDTH(AXI_AWIDTH),
    .AXI_DWIDTH(AXI_DWIDTH),
    .WT_DIM(WT_DIM)
  ) memif_unit (
    .clk(clk),
    .rst(rst),

    // Read interface (<-> AXI adapter read logic)
    .xcel_read_request_valid(xcel_read_request_valid),   // output
    .xcel_read_request_ready(xcel_read_request_ready),   // input
    .xcel_read_addr(xcel_read_addr),                     // output
    .xcel_read_len(xcel_read_len),                       // output
    .xcel_read_size(xcel_read_size),                     // output
    .xcel_read_burst(xcel_read_burst),                   // output
    .xcel_read_data(xcel_read_data),                     // input
    .xcel_read_data_valid(xcel_read_data_valid),         // input
    .xcel_read_data_ready(xcel_read_data_ready),         // output

    // Write interface (<-> AXI adapter write logic)
    .xcel_write_request_valid(xcel_write_request_valid), // output
    .xcel_write_request_ready(xcel_write_request_ready), // input
    .xcel_write_addr(xcel_write_addr),                   // output
    .xcel_write_len(xcel_write_len),                     // output
    .xcel_write_size(xcel_write_size),                   // output
    .xcel_write_burst(xcel_write_burst),                 // output
    .xcel_write_data(xcel_write_data),                   // output
    .xcel_write_data_valid(xcel_write_data_valid),       // output
    .xcel_write_data_ready(xcel_write_data_ready),       // input

    // DDR addresses of IFM, WT, OFM
    .ifm_ddr_addr(ifm_ddr_addr),       // input
    .wt_ddr_addr(wt_ddr_addr),         // input
    .ofm_ddr_addr(ofm_ddr_addr),       // input

    // IFM read (response to the compute_unit)
    .ifm_addr(ifm_addr),               // input
    .ifm_dout(ifm_dout),               // output
    .ifm_dout_valid(ifm_dout_valid),   // output
    .ifm_dout_ready(ifm_dout_ready),   // input

    // WT read (response to the compute_unit)
    .wt_addr(wt_addr),                 // input
    .wt_dout(wt_dout),                 // output
    .wt_dout_valid(wt_dout_valid),     // output
    .wt_dout_ready(wt_dout_ready),     // input

    // OFM read (response to the compute_unit)
    .ofm_addr0(ofm_addr0),             // input
    .ofm_dout0(ofm_dout0),             // output
    .ofm_dout0_valid(ofm_dout0_valid), // output
    .ofm_dout0_ready(ofm_dout0_ready), // input

    // OFM write (request from the compute unit)
    .ofm_addr1(ofm_addr1),             // input
    .ofm_din1(ofm_din1),               // input
    .ofm_din1_valid(ofm_din1_valid),   // input
    .ofm_din1_ready(ofm_din1_ready),   // output
    .ofm_we1(ofm_we1)                  // input
  );

  assign compute_start = xcel_start;
  assign xcel_done     = compute_done;
  assign xcel_idle     = compute_idle;

endmodule
