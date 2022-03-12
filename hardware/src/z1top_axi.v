`timescale 1ns/1ns

module z1top_axi #(
  parameter AXI_AWIDTH = 32,
  parameter AXI_DWIDTH = 32,
  parameter AXI_MAX_BURST_LEN = 256,
  parameter CPU_CLOCK_FREQ = 50_000_000
) (
  input  CLK_125MHZ_FPGA,
  input  [3:0] BUTTONS,
  input  [1:0] SWITCHES,
  output [5:0] LEDS,

  input  FPGA_SERIAL_RX,
  output FPGA_SERIAL_TX,

  // AXI bus interface
  input axi_clk,
  input axi_resetn,

  // Read address channel
  output [3:0]            arid,
  output [AXI_AWIDTH-1:0] araddr,
  output                  arvalid,
  input                   arready,
  output [7:0]            arlen,
  output [2:0]            arsize,
  output [1:0]            arburst,
  // lock, cache, prot, qos, region, user (unused)

  // Read data channel
  input [3:0]             rid,
  input [AXI_DWIDTH-1:0]  rdata,
  input                   rvalid,
  output                  rready,
  input                   rlast,
  input [1:0]             rresp,
  // user (unused)

  // Write address channel
  output [3:0]            awid,
  output [AXI_AWIDTH-1:0] awaddr,
  output                  awvalid,
  input                   awready,
  output [7:0]            awlen,
  output [2:0]            awsize,
  output [1:0]            awburst,
  // lock, cache, prot, qos, region, user (unused)

  // Write data channel
  output [3:0]            wid,
  output [AXI_DWIDTH-1:0] wdata,
  output                  wvalid,
  input                   wready,
  output                  wlast,
  output [AXI_DWIDTH/8-1:0] wstrb,
  // user (unused)

  // Write response channel
  input [3:0]             bid,
  input [1:0]             bresp,
  input                   bvalid,
  output                  bready
  // user (unused)

);

  wire cpu_clk;

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
    .clk(axi_clk),
    .in(BUTTONS),
    .out(buttons_pressed)
  );

  wire reset = (buttons_pressed[0] & SWITCHES[1]);

  wire [31:0] csr;

  localparam DMEM_AWIDTH = 14;
  localparam DMEM_DWIDTH = 32;

  wire dma_start, dma_done, dma_idle, dma_dir;
  wire [31:0] dma_src_addr, dma_dst_addr, dma_len;

  wire xcel_start, xcel_idle, xcel_done;

  wire [31:0] ifm_ddr_addr, wt_ddr_addr, ofm_ddr_addr;
  wire [31:0] ifm_dim;
  wire [31:0] ifm_depth;

  wire [31:0] wt_depth;

  wire [31:0] ofm_dim;
  wire [31:0] ofm_depth;

  wire [DMEM_AWIDTH-1:0] dmem_addrb;
  wire [DMEM_DWIDTH-1:0] dmem_dinb, dmem_doutb;
  wire [3:0]  dmem_web;
  wire dmem_enb;

  Riscv151 #(
    .CPU_CLOCK_FREQ(CPU_CLOCK_FREQ)
  ) cpu (
    .clk(axi_clk),
    .rst(reset),
    .FPGA_SERIAL_TX(FPGA_SERIAL_TX),
    .FPGA_SERIAL_RX(FPGA_SERIAL_RX),
    .csr(csr),

    // Acccelerator Interfacing
    .xcel_start(xcel_start),
    .xcel_idle(xcel_idle & (~xcel_start)),
    .xcel_done(xcel_done & (~xcel_start)),

    .ifm_ddr_addr(ifm_ddr_addr),
    .wt_ddr_addr(wt_ddr_addr),
    .ofm_ddr_addr(ofm_ddr_addr),

    .ifm_dim(ifm_dim),
    .ifm_depth(ifm_depth),

    .ofm_dim(ofm_dim),
    .ofm_depth(ofm_depth),

    // DMA Interfacing
    .dma_start(dma_start),
    .dma_done(dma_done & (~dma_start)),
    .dma_idle(dma_idle & (~dma_start)),
    .dma_dir(dma_dir),
    .dma_src_addr(dma_src_addr),
    .dma_dst_addr(dma_dst_addr),
    .dma_len(dma_len),

    // Riscv151 DMem Interfacing
    .dmem_addrb(dmem_addrb),
    .dmem_dinb(dmem_dinb),
    .dmem_doutb(dmem_doutb),
    .dmem_web(dmem_web),
    .dmem_enb(dmem_enb)
  );

  assign LEDS[5:4] = 2'b11;

  wire                  core_read_request_valid;
  wire                  core_read_request_ready;
  wire [AXI_AWIDTH-1:0] core_read_addr;
  wire [31:0]           core_read_len;
  wire [2:0]            core_read_size;
  wire [1:0]            core_read_burst;
  wire [AXI_DWIDTH-1:0] core_read_data;
  wire                  core_read_data_valid;
  wire                  core_read_data_ready;

  wire                  core_write_request_valid;
  wire                  core_write_request_ready;
  wire [AXI_AWIDTH-1:0] core_write_addr;
  wire [31:0]           core_write_len;
  wire [2:0]            core_write_size;
  wire [1:0]            core_write_burst;
  wire [AXI_DWIDTH-1:0] core_write_data;
  wire                  core_write_data_valid;
  wire                  core_write_data_ready;

  axi_mm_adapter #(
    .AXI_AWIDTH(AXI_AWIDTH),
    .AXI_DWIDTH(AXI_DWIDTH)
  ) axi_mm_core (
    .clk(axi_clk),
    .resetn(axi_resetn | ~reset),

    .arid(arid),
    .araddr(araddr),
    .arvalid(arvalid),
    .arready(arready),
    .arlen(arlen),
    .arsize(arsize),
    .arburst(arburst),

    .rid(rid),
    .rdata(rdata),
    .rvalid(rvalid),
    .rready(rready),
    .rlast(rlast),
    .rresp(rresp),

    .awid(awid),
    .awaddr(awaddr),
    .awvalid(awvalid),
    .awready(awready),
    .awlen(awlen),
    .awsize(awsize),
    .awburst(awburst),

    .wid(wid),
    .wdata(wdata),
    .wvalid(wvalid),
    .wready(wready),
    .wlast(wlast),
    .wstrb(wstrb),

    .bid(bid),
    .bresp(bresp),
    .bvalid(bvalid),
    .bready(bready),

    .core_read_request_valid(core_read_request_valid),   // input
    .core_read_request_ready(core_read_request_ready),   // output
    .core_read_addr(core_read_addr),                     // input
    .core_read_len(core_read_len),                       // input
    .core_read_size(core_read_size),                     // input
    .core_read_burst(core_read_burst),                   // input
    .core_read_data(core_read_data),                     // output
    .core_read_data_valid(core_read_data_valid),         // output
    .core_read_data_ready(core_read_data_ready),         // input

    .core_write_request_valid(core_write_request_valid), // input
    .core_write_request_ready(core_write_request_ready), // output
    .core_write_addr(core_write_addr),                   // input
    .core_write_len(core_write_len),                     // input
    .core_write_size(core_write_size),                   // input
    .core_write_burst(core_write_burst),                 // input
    .core_write_data(core_write_data),                   // input
    .core_write_data_valid(core_write_data_valid),       // input
    .core_write_data_ready(core_write_data_ready)        // output
  );

  wire                  dma_read_request_valid;
  wire                  dma_read_request_ready;
  wire [AXI_AWIDTH-1:0] dma_read_addr;
  wire [31:0]           dma_read_len;
  wire [2:0]            dma_read_size;
  wire [1:0]            dma_read_burst;
  wire [AXI_DWIDTH-1:0] dma_read_data;
  wire                  dma_read_data_valid;
  wire                  dma_read_data_ready;

  wire                  dma_write_request_valid;
  wire                  dma_write_request_ready;
  wire [AXI_AWIDTH-1:0] dma_write_addr;
  wire [31:0]           dma_write_len;
  wire [2:0]            dma_write_size;
  wire [1:0]            dma_write_burst;
  wire [AXI_DWIDTH-1:0] dma_write_data;
  wire                  dma_write_data_valid;
  wire                  dma_write_data_ready;

  dma_controller #(
    .AXI_AWIDTH(AXI_AWIDTH),
    .AXI_DWIDTH(AXI_DWIDTH),
    .DMEM_AWIDTH(DMEM_AWIDTH),
    .DMEM_DWIDTH(DMEM_DWIDTH)
  ) dma_unit (
    .clk(axi_clk),
    .resetn(axi_resetn | ~reset),

    .dma_read_request_valid(dma_read_request_valid),
    .dma_read_request_ready(dma_read_request_ready),
    .dma_read_addr(dma_read_addr),
    .dma_read_len(dma_read_len),
    .dma_read_size(dma_read_size),
    .dma_read_burst(dma_read_burst),
    .dma_read_data(dma_read_data),
    .dma_read_data_valid(dma_read_data_valid),
    .dma_read_data_ready(dma_read_data_ready),

    .dma_write_request_valid(dma_write_request_valid),
    .dma_write_request_ready(dma_write_request_ready),
    .dma_write_addr(dma_write_addr),
    .dma_write_len(dma_write_len),
    .dma_write_size(dma_write_size),
    .dma_write_burst(dma_write_burst),
    .dma_write_data(dma_write_data),
    .dma_write_data_valid(dma_write_data_valid),
    .dma_write_data_ready(dma_write_data_ready),

    .dma_start(dma_start),
    .dma_done(dma_done),
    .dma_idle(dma_idle),
    .dma_dir(dma_dir),
    .dma_src_addr(dma_src_addr),
    .dma_dst_addr(dma_dst_addr),
    .dma_len(dma_len),

    .dmem_addr(dmem_addrb),
    .dmem_din(dmem_dinb),
    .dmem_dout(dmem_doutb),
    .dmem_wbe(dmem_web),
    .dmem_en(dmem_enb)
  );

  wire                  xcel_read_request_valid;
  wire                  xcel_read_request_ready;
  wire [AXI_AWIDTH-1:0] xcel_read_addr;
  wire [31:0]           xcel_read_len;
  wire [2:0]            xcel_read_size;
  wire [1:0]            xcel_read_burst;
  wire [AXI_DWIDTH-1:0] xcel_read_data;
  wire                  xcel_read_data_valid;
  wire                  xcel_read_data_ready;

  wire                  xcel_write_request_valid;
  wire                  xcel_write_request_ready;
  wire [AXI_AWIDTH-1:0] xcel_write_addr;
  wire [31:0]           xcel_write_len;
  wire [2:0]            xcel_write_size;
  wire [1:0]            xcel_write_burst;
  wire [AXI_DWIDTH-1:0] xcel_write_data;
  wire                  xcel_write_data_valid;
  wire                  xcel_write_data_ready;

  xcel_naive #(
    .AXI_AWIDTH(AXI_AWIDTH),
    .AXI_DWIDTH(AXI_DWIDTH)
  ) xcel_unit (
    .clk(axi_clk),
    .rst(~axi_resetn | reset),

    .xcel_read_request_valid(xcel_read_request_valid),
    .xcel_read_request_ready(xcel_read_request_ready),
    .xcel_read_addr(xcel_read_addr),
    .xcel_read_len(xcel_read_len),
    .xcel_read_size(xcel_read_size),
    .xcel_read_burst(xcel_read_burst),
    .xcel_read_data(xcel_read_data),
    .xcel_read_data_valid(xcel_read_data_valid),
    .xcel_read_data_ready(xcel_read_data_ready),

    .xcel_write_request_valid(xcel_write_request_valid),
    .xcel_write_request_ready(xcel_write_request_ready),
    .xcel_write_addr(xcel_write_addr),
    .xcel_write_len(xcel_write_len),
    .xcel_write_size(xcel_write_size),
    .xcel_write_burst(xcel_write_burst),
    .xcel_write_data(xcel_write_data),
    .xcel_write_data_valid(xcel_write_data_valid),
    .xcel_write_data_ready(xcel_write_data_ready),

    .xcel_start(xcel_start),
    .xcel_done(xcel_done),
    .xcel_idle(xcel_idle),

    .ifm_ddr_addr(ifm_ddr_addr),
    .wt_ddr_addr(wt_ddr_addr),
    .ofm_ddr_addr(ofm_ddr_addr),

    .ifm_dim(ifm_dim),
    .ifm_depth(ifm_depth),

    .ofm_dim(ofm_dim),
    .ofm_depth(ofm_depth)
  );

  wire xcel_busy;

  // High when the accelerator is running
  // Low when the accelerator is done (but yet to be restarted)
  REGISTER_R_CE #(.N(1)) acc_busy_reg (
    .clk(axi_clk),
    .rst((xcel_done & ~xcel_start) | ~axi_resetn | reset),
    .d(1'b1),
    .q(xcel_busy),
    .ce(xcel_start)
  );

  // Arbiter logic between {DMA, Accelerator} and {AXI Adapter} <-> DDR
  arbiter #(
    .AXI_AWIDTH(AXI_AWIDTH),
    .AXI_DWIDTH(AXI_DWIDTH)
  ) arb (

    .xcel_busy(xcel_busy),

     // Core interfacing (with the AXI Adapter)
    .core_read_request_valid(core_read_request_valid),   // output
    .core_read_request_ready(core_read_request_ready),   // input
    .core_read_addr(core_read_addr),                     // output
    .core_read_len(core_read_len),                       // output
    .core_read_size(core_read_size),                     // output
    .core_read_burst(core_read_burst),                   // output
    .core_read_data(core_read_data),                     // input
    .core_read_data_valid(core_read_data_valid),         // input
    .core_read_data_ready(core_read_data_ready),         // output

    .core_write_request_valid(core_write_request_valid), // output
    .core_write_request_ready(core_write_request_ready), // input
    .core_write_addr(core_write_addr),                   // output
    .core_write_len(core_write_len),                     // output
    .core_write_size(core_write_size),                   // output
    .core_write_burst(core_write_burst),                 // output
    .core_write_data(core_write_data),                   // output
    .core_write_data_valid(core_write_data_valid),       // output
    .core_write_data_ready(core_write_data_ready),       // input

    // DMA Controller interfacing
    .dma_read_request_valid(dma_read_request_valid),
    .dma_read_request_ready(dma_read_request_ready),
    .dma_read_addr(dma_read_addr),
    .dma_read_len(dma_read_len),
    .dma_read_size(dma_read_size),
    .dma_read_burst(dma_read_burst),
    .dma_read_data(dma_read_data),
    .dma_read_data_valid(dma_read_data_valid),
    .dma_read_data_ready(dma_read_data_ready),

    .dma_write_request_valid(dma_write_request_valid),
    .dma_write_request_ready(dma_write_request_ready),
    .dma_write_addr(dma_write_addr),
    .dma_write_len(dma_write_len),
    .dma_write_size(dma_write_size),
    .dma_write_burst(dma_write_burst),
    .dma_write_data(dma_write_data),
    .dma_write_data_valid(dma_write_data_valid),
    .dma_write_data_ready(dma_write_data_ready),

    // Accelerator interfacing
    .xcel_read_request_valid(xcel_read_request_valid),
    .xcel_read_request_ready(xcel_read_request_ready),
    .xcel_read_addr(xcel_read_addr),
    .xcel_read_len(xcel_read_len),
    .xcel_read_size(xcel_read_size),
    .xcel_read_burst(xcel_read_burst),
    .xcel_read_data(xcel_read_data),
    .xcel_read_data_valid(xcel_read_data_valid),
    .xcel_read_data_ready(xcel_read_data_ready),

    .xcel_write_request_valid(xcel_write_request_valid),
    .xcel_write_request_ready(xcel_write_request_ready),
    .xcel_write_addr(xcel_write_addr),
    .xcel_write_len(xcel_write_len),
    .xcel_write_size(xcel_write_size),
    .xcel_write_burst(xcel_write_burst),
    .xcel_write_data(xcel_write_data),
    .xcel_write_data_valid(xcel_write_data_valid),
    .xcel_write_data_ready(xcel_write_data_ready)
  );

endmodule
