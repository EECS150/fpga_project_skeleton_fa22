`include "axi_consts.vh"

module axi_mm_adapter #(
  parameter AXI_AWIDTH = 32,
  parameter AXI_DWIDTH = 32,
  parameter AXI_MAX_BURST_LEN = 256
) (
  input clk,
  input resetn, // active-low reset

  // AXI bus interface

  // Read address channel
  output [3:0]            arid,
  (* mark_debug = "True" *) output [AXI_AWIDTH-1:0] araddr,
  (* mark_debug = "True" *) output                  arvalid,
  (* mark_debug = "True" *) input                   arready,
  (* mark_debug = "True" *) output [7:0]            arlen,
  (* mark_debug = "True" *) output [2:0]            arsize,
  (* mark_debug = "True" *) output [1:0]            arburst,
  // lock, cache, prot, qos, region, user (unused)

  // Read data channel
  input  [3:0]            rid,
  (* mark_debug = "True" *) input  [AXI_DWIDTH-1:0] rdata,
  (* mark_debug = "True" *) input                   rvalid,
  (* mark_debug = "True" *) output                  rready,
  (* mark_debug = "True" *) input                   rlast,
  input  [1:0]            rresp,
  // user (unused)

  // Write address channel
  output [3:0]            awid,
  (* mark_debug = "True" *) output [AXI_AWIDTH-1:0] awaddr,
  (* mark_debug = "True" *) output                  awvalid,
  (* mark_debug = "True" *) input                   awready,
  (* mark_debug = "True" *) output [7:0]            awlen,
  (* mark_debug = "True" *) output [2:0]            awsize,
  (* mark_debug = "True" *) output [1:0]            awburst,
  // lock, cache, prot, qos, region, user (unused)

  // Write data channel
  output [3:0]            wid,
  (* mark_debug = "True" *) output [AXI_DWIDTH-1:0]   wdata,
  (* mark_debug = "True" *) output                    wvalid,
  (* mark_debug = "True" *) input                     wready,
  (* mark_debug = "True" *) output                    wlast,
  (* mark_debug = "True" *) output [AXI_DWIDTH/8-1:0] wstrb,
  // user (unused)

  // Write response channel
  input [3:0] bid,
  input [1:0] bresp,
  input       bvalid,
  output      bready,
  // user (unused)

  // Core (client) interface
  // Read request address and Read response data
  input                   core_read_request_valid,
  output                  core_read_request_ready,
  input  [AXI_AWIDTH-1:0] core_read_addr,
  input  [31:0]           core_read_len,
  input  [2:0]            core_read_size,
  input  [1:0]            core_read_burst,
  output [AXI_DWIDTH-1:0] core_read_data,
  output                  core_read_data_valid,
  input                   core_read_data_ready,

  // Write request address and Write request data
  // (no write response -- assuming write always succeeds)
  input                   core_write_request_valid,
  output                  core_write_request_ready,
  input  [AXI_AWIDTH-1:0] core_write_addr,
  input  [31:0]           core_write_len,
  input  [2:0]            core_write_size,
  input  [1:0]            core_write_burst,
  input  [AXI_DWIDTH-1:0] core_write_data,
  input                   core_write_data_valid,
  output                  core_write_data_ready
);

  axi_mm_write #(.AXI_AWIDTH(AXI_AWIDTH), .AXI_DWIDTH(AXI_DWIDTH)) write_unit (
    .clk(clk),
    .resetn(resetn),

     // write request address interface
    .awid(awid),
    .awaddr(awaddr),
    .awvalid(awvalid),
    .awready(awready),
    .awlen(awlen),
    .awsize(awsize),
    .awburst(awburst),

     // write request data interface
    .wid(wid),
    .wdata(wdata),
    .wvalid(wvalid),
    .wready(wready),
    .wlast(wlast),
    .wstrb(wstrb),

     // write response interface
    .bid(bid),
    .bresp(bresp),
    .bvalid(bvalid),
    .bready(bready),

    // core (client) write interface
    .core_write_request_valid(core_write_request_valid),
    .core_write_request_ready(core_write_request_ready),
    .core_write_addr(core_write_addr),
    .core_write_len(core_write_len),
    .core_write_size(core_write_size),
    .core_write_burst(core_write_burst),
    .core_write_data(core_write_data),
    .core_write_data_valid(core_write_data_valid),
    .core_write_data_ready(core_write_data_ready)
  );

  axi_mm_read #(.AXI_AWIDTH(AXI_AWIDTH), .AXI_DWIDTH(AXI_DWIDTH)) read_unit (
    .clk(clk),
    .resetn(resetn),

     // read request address interface
    .arid(arid),
    .araddr(araddr),
    .arvalid(arvalid),
    .arready(arready),
    .arlen(arlen),
    .arsize(arsize),
    .arburst(arburst),

     // read response data interface
    .rid(rid),
    .rdata(rdata),
    .rvalid(rvalid),
    .rready(rready),
    .rlast(rlast),
    .rresp(rresp),

    // core (client) read interface
    .core_read_request_valid(core_read_request_valid),
    .core_read_request_ready(core_read_request_ready),
    .core_read_addr(core_read_addr),
    .core_read_len(core_read_len),
    .core_read_size(core_read_size),
    .core_read_burst(core_read_burst),
    .core_read_data(core_read_data),
    .core_read_data_valid(core_read_data_valid),
    .core_read_data_ready(core_read_data_ready)
  );

endmodule
