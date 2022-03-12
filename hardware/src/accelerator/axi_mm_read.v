`include "axi_consts.vh"

module axi_mm_read #(
  parameter AXI_AWIDTH = 32,
  parameter AXI_DWIDTH = 32,
  parameter AXI_MAX_BURST_LEN = 256
) (
  input clk,
  input resetn, // active-low reset

  // Read request address channel
  output [3:0]            arid,
  output [AXI_AWIDTH-1:0] araddr,
  output                  arvalid,
  input                   arready,
  output [7:0]            arlen,
  output [2:0]            arsize,
  output [1:0]            arburst,
  // lock, cache, prot, qos, region, user (unused)

  // Read response data channel
  input  [3:0]            rid,
  input  [AXI_DWIDTH-1:0] rdata,
  input                   rvalid,
  output                  rready,
  input                   rlast,
  input  [1:0]            rresp,
  // user (unused)

  // Core (client) read interface
  input                   core_read_request_valid,
  output                  core_read_request_ready,
  input  [AXI_AWIDTH-1:0] core_read_addr,
  input  [31:0]           core_read_len,
  input  [2:0]            core_read_size,
  input  [1:0]            core_read_burst,
  output [AXI_DWIDTH-1:0] core_read_data,
  output                  core_read_data_valid,
  input                   core_read_data_ready
);

  // number of data transfers (beats) = len + 1
  // number of bytes in transfer = 2^size

  wire ar_fire = arvalid & arready;
  wire dr_fire = rvalid  & rready;

  wire core_read_request_fire  = core_read_request_valid & core_read_request_ready;

  localparam STATE_AR_IDLE = 2'b00;
  localparam STATE_AR_RUN  = 2'b01;
  localparam STATE_AR_DONE = 2'b10;

  localparam STATE_DR_IDLE = 2'b00;
  localparam STATE_DR_RUN  = 2'b01;
  localparam STATE_DR_DONE = 2'b10;

  wire [1:0] state_ar_value;
  reg  [1:0] state_ar_next;
  wire [1:0] state_dr_value;
  reg  [1:0] state_dr_next;

  REGISTER_R #(.N(2), .INIT(STATE_AR_IDLE)) state_ar_reg (
    .clk(clk),
    .rst(~resetn),
    .d(state_ar_next),
    .q(state_ar_value)
  );

  REGISTER_R #(.N(2), .INIT(STATE_DR_IDLE)) state_dr_reg (
    .clk(clk),
    .rst(~resetn),
    .d(state_dr_next),
    .q(state_dr_value)
  );

  wire [AXI_AWIDTH-1:0] raddr_next, raddr_value;
  wire raddr_ce;
  REGISTER_R_CE #(.N(AXI_AWIDTH), .INIT(0)) raddr_reg (
    .clk(clk),
    .rst(~resetn),
    .d(raddr_next),
    .q(raddr_value),
    .ce(raddr_ce)
  );

  wire [31:0] rlen_next, rlen_value;
  wire rlen_ce;
  REGISTER_R_CE #(.N(32), .INIT(0)) rlen_reg (
    .clk(clk),
    .rst(~resetn),
    .d(rlen_next),
    .q(rlen_value),
    .ce(rlen_ce)
  );

  wire [2:0] rsize_next, rsize_value;
  wire rsize_ce;
  REGISTER_R_CE #(.N(3), .INIT(0)) rsize_reg (
    .clk(clk),
    .rst(~resetn),
    .d(rsize_next),
    .q(rsize_value),
    .ce(rsize_ce)
  );

  wire [1:0] rburst_next, rburst_value;
  wire rburst_ce;
  REGISTER_R_CE #(.N(2), .INIT(0)) rburst_reg (
    .clk(clk),
    .rst(~resetn),
    .d(rburst_next),
    .q(rburst_value),
    .ce(rburst_ce)
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
  wire rburst_resume_next, rburst_resume_value;
  wire rburst_resume_ce, rburst_resume_rst;

  REGISTER_R_CE #(.N(1), .INIT(0)) rburst_resume_reg (
    .clk(clk),
    .rst(rburst_resume_rst),
    .d(rburst_resume_next),
    .q(rburst_resume_value),
    .ce(rburst_resume_ce)
  );

  wire ar_idle = (state_ar_value == STATE_AR_IDLE);
  wire ar_run  = (state_ar_value == STATE_AR_RUN);
  wire ar_done = (state_ar_value == STATE_AR_DONE);

  wire dr_idle = (state_dr_value == STATE_DR_IDLE);
  wire dr_run  = (state_dr_value == STATE_DR_RUN);
  wire dr_done = (state_dr_value == STATE_DR_DONE);

  always @(*) begin
    state_ar_next = state_ar_value;
    case (state_ar_value)
      STATE_AR_IDLE: begin
        // start the request if the core sends a request, or
        // if we need to resume the request to finish the burst
        if (core_read_request_fire || rburst_resume_value)
          state_ar_next = STATE_AR_RUN;
      end

      STATE_AR_RUN: begin
        // if the AXI has submitted the request, this is done
        if (ar_fire) begin
          state_ar_next = STATE_AR_DONE;
        end
      end

      STATE_AR_DONE: begin
        state_ar_next = STATE_AR_IDLE;
      end

    endcase
  end

  always @(*) begin
    state_dr_next = state_dr_value;
    case (state_dr_value)
      STATE_DR_IDLE: begin
        // if the AXI has submitted the request, we'll wait for the
        // response data in the next state
        if (ar_fire)
          state_dr_next = STATE_DR_RUN;
      end

      STATE_DR_RUN: begin
        // if the last data is fired, we are done
        if (dr_fire && rlast) begin
          state_dr_next = STATE_DR_DONE;
        end
      end

      STATE_DR_DONE: begin
        state_dr_next = STATE_DR_IDLE;
      end

    endcase
  end

  wire full_rburst = rlen_value > AXI_MAX_BURST_LEN - 1;

  // register the settings from the core client
  // (size, burst)
  assign rsize_next = core_read_size;
  assign rsize_ce   = core_read_request_fire;

  assign rburst_next = core_read_burst;
  assign rburst_ce   = core_read_request_fire;

  // Recalculate the address if we need to send multiple requests to cover
  // the full burst length
  assign raddr_next = core_read_request_fire ? core_read_addr :
                                               raddr_value + (AXI_MAX_BURST_LEN << rsize_value);
  assign raddr_ce   = core_read_request_fire | (dr_fire & rlast);

  // Recalculate the len if we need to send multiple requests to cover
  // the full burst length
  assign rlen_next = core_read_request_fire ? core_read_len :
                                              rlen_value - AXI_MAX_BURST_LEN;
  assign rlen_ce   = core_read_request_fire | (dr_fire & rlast);

  // Resume the burst (or send a new request) if we yet to cover the whole burst length
  assign rburst_resume_next = full_rburst ? 1 : 0;
  assign rburst_resume_ce   = dr_fire & rlast;
  assign rburst_resume_rst  = dr_idle | (~resetn);

  // Setup read request for AXI adater read
  assign arvalid = ar_run;
  assign araddr  = raddr_value;
  assign arlen   = full_rburst ? AXI_MAX_BURST_LEN - 1 : rlen_value;
  assign arsize  = rsize_value;
  assign arburst = rburst_value;

  assign rready  = dr_run & core_read_data_ready;

  assign core_read_request_ready = dr_idle & (~rburst_resume_value);
  assign core_read_data          = rdata;
  assign core_read_data_valid    = dr_run & rvalid;

  // Keep it simple: use ID 0 for now
  assign arid = 0;

  // Keep it simple: ignore rid for now

endmodule
