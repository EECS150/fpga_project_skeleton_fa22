`include "axi_consts.vh"
`include "lenet_consts.vh"

module xcel_naive_memif #(
  parameter AXI_AWIDTH = 32,
  parameter AXI_DWIDTH = 32,
  parameter DWIDTH     = 8,
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

  input [31:0] ifm_ddr_addr, // IFM address in DDR
  input [31:0] wt_ddr_addr,  // WT address in DDR
  input [31:0] ofm_ddr_addr, // OFM address in DDR

  // IFM read
  input  [31:0]       ifm_addr,
  output [DWIDTH-1:0] ifm_dout,
  output              ifm_dout_valid,
  input               ifm_dout_ready, // wt read request from compute_unit

  // WT read
  input  [31:0]       wt_addr,
  output [DWIDTH-1:0] wt_dout,
  output              wt_dout_valid,
  input               wt_dout_ready, // ifm read request from compute_unit

  // OFM read
  input  [31:0] ofm_addr0,
  output [31:0] ofm_dout0,
  output        ofm_dout0_valid,
  input         ofm_dout0_ready, // ofm read request from compute_unit

  // OFM write
  input [31:0]  ofm_addr1,
  input [31:0]  ofm_din1,
  input         ofm_din1_valid, // write request from compute_unit
  output        ofm_din1_ready,
  input         ofm_we1         // unused here
);

  localparam integer WT_SIZE = WT_DIM * WT_DIM;

  wire xcel_read_request_fire  = xcel_read_request_valid & xcel_read_request_ready;
  wire xcel_read_data_fire     = xcel_read_data_valid & xcel_read_data_ready;
  wire xcel_write_request_fire = xcel_write_request_valid & xcel_write_request_ready;
  wire xcel_write_data_fire    = xcel_write_data_valid & xcel_write_data_ready;

  wire fetch_ifm = ifm_dout_ready;
  wire fetch_wt  = wt_dout_ready;
  wire fetch_ofm = ofm_dout0_ready;
  wire write_ofm = ofm_din1_valid;

  // Pipeline registers to meet higher frequency target
  wire fetch_ifm_pipe;
  REGISTER #(.N(1)) fetch_ifm_reg (
    .clk(clk),
    .d(fetch_ifm),
    .q(fetch_ifm_pipe)
  );

  wire fetch_wt_pipe;
  REGISTER #(.N(1)) fetch_wt_reg (
    .clk(clk),
    .d(fetch_wt),
    .q(fetch_wt_pipe)
  );

  wire fetch_ofm_pipe;
  REGISTER #(.N(1)) fetch_ofm_reg (
    .clk(clk),
    .d(fetch_ofm),
    .q(fetch_ofm_pipe)
  );

  wire write_ofm_pipe;
  REGISTER #(.N(1)) write_ofm_reg (
    .clk(clk),
    .d(write_ofm),
    .q(write_ofm_pipe)
  );

  wire [31:0] ifm_addr_pipe;
  REGISTER_CE #(.N(32)) ifm_addr_reg (
    .clk(clk),
    .d(ifm_addr),
    .q(ifm_addr_pipe),
    .ce(fetch_ifm)
  );

  wire [31:0] wt_addr_pipe;
  REGISTER_CE #(.N(32)) wt_addr_reg (
    .clk(clk),
    .d(wt_addr),
    .q(wt_addr_pipe),
    .ce(fetch_wt)
  );

  wire [31:0] ofm_addr0_pipe;
  REGISTER_CE #(.N(32)) ofm_addr0_reg (
    .clk(clk),
    .d(ofm_addr0),
    .q(ofm_addr0_pipe),
    .ce(fetch_ofm)
  );

  wire [31:0] ofm_addr1_pipe;
  REGISTER_CE #(.N(32)) ofm_addr1_reg (
    .clk(clk),
    .d(ofm_addr1),
    .q(ofm_addr1_pipe),
    .ce(write_ofm)
  );

  wire [31:0] ofm_din1_pipe;
  REGISTER_CE #(.N(32)) ofm_din1_reg (
    .clk(clk),
    .d(ofm_din1),
    .q(ofm_din1_pipe),
    .ce(write_ofm)
  );

  localparam STATE_IDLE          = 0;
  localparam STATE_READ_DDR_REQ  = 1;
  localparam STATE_READ_DDR      = 2;
  localparam STATE_WRITE_DDR_REQ = 3;
  localparam STATE_WRITE_DDR     = 4;
  localparam STATE_DONE          = 5;

  wire [2:0] state_value;
  reg  [2:0] state_next;
  REGISTER_R #(.N(3), .INIT(STATE_IDLE)) state_reg (
    .clk(clk),
    .rst(rst),
    .d(state_next),
    .q(state_value)
  );

  // Some states here might not be necessary and can be optimized away,
  // but are added to make the code appear more idiomatic and readable
  wire idle          = state_value == STATE_IDLE;
  wire read_ddr_req  = state_value == STATE_READ_DDR_REQ;
  wire read_ddr      = state_value == STATE_READ_DDR;
  wire write_ddr_req = state_value == STATE_WRITE_DDR_REQ;
  wire write_ddr     = state_value == STATE_WRITE_DDR;
  wire done          = state_value == STATE_DONE;

  always @(*) begin
    state_next = state_value;
    case (state_value)
    STATE_IDLE: begin
      if (fetch_ifm_pipe | fetch_wt_pipe | fetch_ofm_pipe)
        state_next = STATE_READ_DDR_REQ;
      else if (write_ofm_pipe)
        state_next = STATE_WRITE_DDR_REQ;
    end

    STATE_READ_DDR_REQ: begin
      if (xcel_read_request_fire)
        state_next = STATE_READ_DDR;
    end

    STATE_READ_DDR: begin
      if (xcel_read_data_fire)
        state_next = STATE_DONE;
    end

    STATE_WRITE_DDR_REQ: begin
      if (xcel_write_request_fire)
        state_next = STATE_WRITE_DDR;
    end

    STATE_WRITE_DDR: begin
      if (xcel_write_data_fire)
        state_next = STATE_DONE;
    end

    STATE_DONE: begin
      state_next = STATE_IDLE;
    end

    endcase
  end

  // Setup read request and read data
  // Reading WT and IFM one byte per transfer
  // Reading OFM 4 bytes per transfer
  assign xcel_read_request_valid  = read_ddr_req;
  assign xcel_read_addr           = fetch_ofm_pipe ? (ofm_ddr_addr + {ofm_addr0_pipe << 2}) :
                                    fetch_wt_pipe  ? (wt_ddr_addr  + {wt_addr_pipe   << 0}) :
                                                     (ifm_ddr_addr + {ifm_addr_pipe  << 0});
  assign xcel_read_len            = 1 - 1; // no burst (one data beat per transfer)
  assign xcel_read_burst          = `BURST_INCR;
  assign xcel_read_size           = fetch_ofm_pipe ? 3'd2 : 3'd0; // 4 bytes if fetching ofm, otherwise 1 byte
  assign xcel_read_data_ready     = read_ddr;

  // Setup write request and write data
  // Write OFM 4 bytes per transfer
  assign xcel_write_request_valid = write_ddr_req;
  assign xcel_write_addr          = ofm_ddr_addr + {ofm_addr1_pipe << 2};
  assign xcel_write_len           = 1 - 1; // no burst (one data beat per transfer)
  assign xcel_write_burst         = `BURST_INCR;
  assign xcel_write_size          = 3'd2; // 4 bytes;
  assign xcel_write_data_valid    = write_ddr;
  assign xcel_write_data          = ofm_din1;

  // extract the correct byte from the read data based on the byte offset
  wire [DWIDTH-1:0] byte_wt = wt_addr_pipe[1:0] == 2'b00 ? xcel_read_data[7:0]   :
                              wt_addr_pipe[1:0] == 2'b01 ? xcel_read_data[15:8]  :
                              wt_addr_pipe[1:0] == 2'b10 ? xcel_read_data[23:16] :
                                                           xcel_read_data[31:24];

  wire [DWIDTH-1:0] byte_ifm = ifm_addr_pipe[1:0] == 2'b00 ? xcel_read_data[7:0]   :
                               ifm_addr_pipe[1:0] == 2'b01 ? xcel_read_data[15:8]  :
                               ifm_addr_pipe[1:0] == 2'b10 ? xcel_read_data[23:16] :
                                                             xcel_read_data[31:24];

  // Read response to the compute_unit
  assign wt_dout   = byte_wt;
  assign ifm_dout  = byte_ifm;
  assign ofm_dout0 = xcel_read_data;

  assign wt_dout_valid   = read_ddr & xcel_read_data_valid;
  assign ifm_dout_valid  = read_ddr & xcel_read_data_valid;
  assign ofm_dout0_valid = read_ddr & xcel_read_data_valid;

  assign ofm_din1_ready = write_ddr & xcel_write_data_ready;

endmodule
