`include "axi_consts.vh"

module axi_mm_write #(
  parameter AXI_AWIDTH = 32,
  parameter AXI_DWIDTH = 32,
  parameter AXI_MAX_BURST_LEN = 256
) (
  input clk,
  input resetn, // active-low reset

  // Write request address channel
  output [3:0]            awid,
  output [AXI_AWIDTH-1:0] awaddr,
  output                  awvalid,
  input                   awready,
  output [7:0]            awlen,
  output [2:0]            awsize,
  output [1:0]            awburst,
  // lock, cache, prot, qos, region, user (unused)

  // Write request data channel
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
  output                  bready,
  // user (unused)

  // Core (client) write interface
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

  // number of data transfers (beats) = len + 1
  // number of bytes in transfer = 2^size

  wire aw_fire    = awvalid & awready;
  wire dw_fire    = wvalid  & wready;
  wire bresp_fire = bvalid  & bready;

  wire core_write_request_fire = core_write_request_valid & core_write_request_ready;
  wire core_write_data_fire    = core_write_data_valid    & core_write_data_ready;

  localparam NUM_DBYTES = AXI_DWIDTH / 8;

  localparam STATE_AW_IDLE = 2'b00;
  localparam STATE_AW_RUN  = 2'b01;
  localparam STATE_AW_DONE = 2'b10;

  localparam STATE_DW_IDLE = 2'b00;
  localparam STATE_DW_RUN  = 2'b01;
  localparam STATE_DW_DONE = 2'b10;

  wire [1:0] state_aw_value;
  reg  [1:0] state_aw_next;
  wire [1:0] state_dw_value;
  reg  [1:0] state_dw_next;

  REGISTER_R #(.N(2), .INIT(STATE_AW_IDLE)) state_aw_reg (
    .clk(clk),
    .rst(~resetn),
    .d(state_aw_next),
    .q(state_aw_value)
  );

  REGISTER_R #(.N(2), .INIT(STATE_DW_IDLE)) state_dw_reg (
    .clk(clk),
    .rst(~resetn),
    .d(state_dw_next),
    .q(state_dw_value)
  );

  wire [AXI_AWIDTH-1:0] waddr_next, waddr_value;
  wire waddr_ce;
  REGISTER_R_CE #(.N(AXI_AWIDTH), .INIT(0)) waddr_reg (
    .clk(clk),
    .rst(~resetn),
    .d(waddr_next),
    .q(waddr_value),
    .ce(waddr_ce)
  );

  wire [31:0] wlen_next, wlen_value;
  wire wlen_ce;
  REGISTER_R_CE #(.N(32), .INIT(0)) wlen_reg (
    .clk(clk),
    .rst(~resetn),
    .d(wlen_next),
    .q(wlen_value),
    .ce(wlen_ce)
  );

  wire [2:0] wsize_next, wsize_value;
  wire wsize_ce;
  REGISTER_R_CE #(.N(3), .INIT(0)) wsize_reg (
    .clk(clk),
    .rst(~resetn),
    .d(wsize_next),
    .q(wsize_value),
    .ce(wsize_ce)
  );

  wire [1:0] wburst_next, wburst_value;
  wire wburst_ce;
  REGISTER_R_CE #(.N(2), .INIT(0)) wburst_reg (
    .clk(clk),
    .rst(~resetn),
    .d(wburst_next),
    .q(wburst_value),
    .ce(wburst_ce)
  );

  wire [7:0] wbeat_cnt_next, wbeat_cnt_value;
  wire wbeat_cnt_ce, wbeat_cnt_rst;
  REGISTER_R_CE #(.N(8), .INIT(0)) wbeat_cnt_reg (
    .clk(clk),
    .rst(wbeat_cnt_rst),
    .d(wbeat_cnt_next),
    .q(wbeat_cnt_value),
    .ce(wbeat_cnt_ce)
  );

  // If a request has a burst length which is greater than the MAX_BURST_LEN,
  // we need to send multiple burst requests one after another to cover the
  // whole burst length
  //
  // e.g. assume len = MAX_BURST_LEN * N + k
  //      req0:     <addr0,  MAX_BURST_LEN>
  //      req1:     <addr0 + {MAX_BURST_LEN << size}, MAX_BURST_LEN>
  //      ...
  //      reqN:     <addr0 + {k << size}, k>

  // resume the request until the burst is fully covered
  wire wburst_resume_next, wburst_resume_value;
  wire wburst_resume_ce, wburst_resume_rst;
  REGISTER_R_CE #(.N(1), .INIT(0)) wburst_resume_reg (
    .clk(clk),
    .rst(wburst_resume_rst),
    .d(wburst_resume_next),
    .q(wburst_resume_value),
    .ce(wburst_resume_ce)
  );

  wire aw_idle = (state_aw_value == STATE_AW_IDLE);
  wire aw_run  = (state_aw_value == STATE_AW_RUN);
  wire aw_done = (state_aw_value == STATE_AW_DONE);

  wire dw_idle = (state_dw_value == STATE_DW_IDLE);
  wire dw_run  = (state_dw_value == STATE_DW_RUN);
  wire dw_done = (state_dw_value == STATE_DW_DONE);

  always @(*) begin
    state_aw_next = state_aw_value;
    case (state_aw_value)
      STATE_AW_IDLE: begin
        // start the request if the core sends a request, or
        // if we need to resume the request to finish the burst
        if (core_write_request_fire || wburst_resume_value)
          state_aw_next = STATE_AW_RUN;
      end

      STATE_AW_RUN: begin
        // if the AXI has submitted the request, this is done
        if (aw_fire) begin
          state_aw_next = STATE_AW_DONE;
        end
      end

      STATE_AW_DONE: begin
        // Need to wait for the write response before done
        if (bresp_fire)
          state_aw_next = STATE_AW_IDLE;
      end

    endcase
  end

  always @(*) begin
    state_dw_next = state_dw_value;
    case (state_dw_value)
      STATE_DW_IDLE: begin
        // start the request if the core sends a request, or
        // if we need to resume the request to finish the burst
        if (core_write_request_fire || wburst_resume_value)
          state_dw_next = STATE_DW_RUN;
      end

      STATE_DW_RUN: begin
        // if the last data is fired, we are done
        if (dw_fire && wlast) begin
          state_dw_next = STATE_DW_DONE;
        end
      end

      STATE_DW_DONE: begin
        // Need to wait for the write response before done
        if (bresp_fire)
          state_dw_next = STATE_DW_IDLE;
      end

    endcase
  end

  wire full_wburst = wlen_value > AXI_MAX_BURST_LEN - 1;

  // register the settings from the core client
  // (size, burst)
  assign wsize_next = core_write_size;
  assign wsize_ce   = core_write_request_fire;

  assign wburst_next = core_write_burst;
  assign wburst_ce   = core_write_request_fire;

  // Recalculate the address if we need to send multiple requests to cover
  // the full burst length
  assign waddr_next = core_write_request_fire ? core_write_addr :
                                                {waddr_value + {AXI_MAX_BURST_LEN << wsize_value}};
  assign waddr_ce   = core_write_request_fire | (dw_fire & wlast);

  // Recalculate the len if we need to send multiple requests to cover
  // the full burst length
  assign wlen_next = core_write_request_fire ? core_write_len :
                                               {wlen_value - AXI_MAX_BURST_LEN};
  assign wlen_ce   = core_write_request_fire | (dw_fire & wlast);

  // Resume the burst (or send a new request) if we yet to cover the whole burst length
  assign wburst_resume_next = full_wburst ? 1'b1 : 1'b0;
  assign wburst_resume_ce   = dw_fire & wlast;
  assign wburst_resume_rst  = dw_idle | (~resetn);

  // Count the number of write data beats to assert the 'last' signal
  assign wbeat_cnt_next = wbeat_cnt_value + 1;
  assign wbeat_cnt_ce   = dw_fire;
  assign wbeat_cnt_rst  = dw_idle | (~resetn);

  // Setup write request address for AXI adapter read
  assign awaddr  = waddr_value;
  assign awvalid = aw_run;
  assign awlen   = full_wburst ? {AXI_MAX_BURST_LEN - 1} : wlen_value;
  assign awsize  = wsize_value;
  assign awburst = wburst_value;

  // Setup write request data for AXI adapter write
  assign wdata   = core_write_data;
  assign wvalid  = dw_run & core_write_data_valid;
  assign wlast   = dw_run &
                   ((wbeat_cnt_value == wlen_value & ~full_wburst) |
                    (wbeat_cnt_value == AXI_MAX_BURST_LEN - 1));

  // write response channel is only ready when write request address and request data
  // are finally done
  assign bready  = aw_done & dw_done;

  assign core_write_request_ready = aw_idle &
                                    (~wburst_resume_value) &
                                    awready;
  assign core_write_data_ready    = dw_run & wready;

  // setup write strobe. Full word write for now?
  assign wstrb = dw_run ? {NUM_DBYTES{1'b1}} : {NUM_DBYTES{1'b0}};

  // Keep it simple: use ID 0 for now
  assign awid = 0;
  assign wid  = 0;
  assign bid  = 0;

endmodule
