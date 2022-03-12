`include "axi_consts.vh"
`include "lenet_consts.vh"

module xcel_naive_compute #(
  parameter DWIDTH = 8,
  parameter WT_DIM = 5
) (
  input clk,
  input rst,

  // IFM read
  output [31:0]       ifm_addr,
  input [DWIDTH-1:0]  ifm_dout,
  input               ifm_dout_valid,
  output              ifm_dout_ready,

  // WT read
  output [31:0]       wt_addr,
  input  [DWIDTH-1:0] wt_dout,
  input               wt_dout_valid,
  output              wt_dout_ready,

  // OFM read
  output [31:0] ofm_addr0,
  input  [31:0] ofm_dout0,
  input         ofm_dout0_valid,
  output        ofm_dout0_ready,

  // OFM write
  output [31:0] ofm_addr1,
  output [31:0] ofm_din1,
  output        ofm_din1_valid,
  input         ofm_din1_ready,
  output        ofm_we1,

  // control & status signals
  input  compute_start,
  output compute_idle,
  output compute_done,

  // parameters
  input [31:0] ifm_dim,
  input [31:0] ifm_size,
  input [31:0] ifm_depth,
  input [31:0] ifm_len,

  input [31:0] wt_volume,
  input [31:0] wt_len,

  input [31:0] ofm_dim,
  input [31:0] ofm_size,
  input [31:0] ofm_depth,
  input [31:0] ofm_len
);

  localparam integer WT_SIZE = WT_DIM * WT_DIM;

  wire ifm_dout_fire  = ifm_dout_valid  & ifm_dout_ready;
  wire wt_dout_fire   = wt_dout_valid   & wt_dout_ready;
  wire ofm_dout0_fire = ofm_dout0_valid & ofm_dout0_ready;
  wire ofm_din1_fire  = ofm_din1_valid  & ofm_din1_ready;

  localparam STATE_IDLE       = 0;
  localparam STATE_FETCH_OFM  = 1;
  localparam STATE_FETCH_WT   = 2;
  localparam STATE_FETCH_IFM  = 3;
  localparam STATE_COMPUTE    = 4;
  localparam STATE_WRITE_OFM  = 5;
  localparam STATE_DONE       = 6;

  wire [2:0] state_value;
  reg  [2:0] state_next;

  REGISTER_R #(.N(3), .INIT(STATE_IDLE)) state_reg (
    .clk(clk),
    .rst(rst),
    .d(state_next),
    .q(state_value)
  );

  // input channel count: 0 -> ifm_depth - 1
  wire [31:0] ic_cnt_next, ic_cnt_value;
  wire ic_cnt_ce, ic_cnt_rst;

  REGISTER_R_CE #(.N(32), .INIT(0)) ic_cnt_reg (
    .clk(clk),
    .rst(ic_cnt_rst),
    .d(ic_cnt_next),
    .q(ic_cnt_value),
    .ce(ic_cnt_ce)
  );

  // output channel count: 0 -> ofm_depth - 1
  wire [31:0] oc_cnt_next, oc_cnt_value;
  wire oc_cnt_ce, oc_cnt_rst;

  REGISTER_R_CE #(.N(32), .INIT(0)) oc_cnt_reg (
    .clk(clk),
    .rst(oc_cnt_rst),
    .d(oc_cnt_next),
    .q(oc_cnt_value),
    .ce(oc_cnt_ce)
  );

  // 0 --> WT_DIM - 1
  // keep track of the current sliding window in y-direction
  // (for fetching wt and ifm)
  wire [31:0] window_y_next, window_y_value;
  wire window_y_rst, window_y_ce;

  REGISTER_R_CE #(.N(32), .INIT(0)) window_y_reg (
    .clk(clk),
    .rst(window_y_rst),
    .d(window_y_next),
    .q(window_y_value),
    .ce(window_y_ce)
  );

  // 0 --> WT_DIM - 1
  // keep track of the current sliding window in x-direction
  // (for fetching wt and ifm)
  wire [31:0] window_x_next, window_x_value;
  wire window_x_rst, window_x_ce;

  REGISTER_R_CE #(.N(32), .INIT(0)) window_x_reg (
    .clk(clk),
    .rst(window_x_rst),
    .d(window_x_next),
    .q(window_x_value),
    .ce(window_x_ce)
  );

  // keep track of IFM index of the current sliding window
  // (for fetching ifm)
  wire [31:0] ifm_idx_next, ifm_idx_value;
  wire ifm_idx_ce, ifm_idx_rst;

  REGISTER_R_CE #(.N(32), .INIT(0)) ifm_idx_reg (
    .clk(clk),
    .rst(ifm_idx_rst),
    .d(ifm_idx_next),
    .q(ifm_idx_value),
    .ce(ifm_idx_ce)
  );

  // 0 --> ofm_dim - 1
  // Keep track of OFM index of the current computing channel (y-direction)
  wire [31:0] ofm_y_next, ofm_y_value;
  wire ofm_y_rst, ofm_y_ce;

  REGISTER_R_CE #(.N(32), .INIT(0)) ofm_y_reg (
    .clk(clk),
    .rst(ofm_y_rst),
    .d(ofm_y_next),
    .q(ofm_y_value),
    .ce(ofm_y_ce)
  );

  // 0 --> ofm_dim - 1
  // Keep track of OFM index of the current computing channel (x-direction)
  wire [31:0] ofm_x_next, ofm_x_value;
  wire ofm_x_rst, ofm_x_ce;

  REGISTER_R_CE #(.N(32), .INIT(0)) ofm_x_reg (
    .clk(clk),
    .rst(ofm_x_rst),
    .d(ofm_x_next),
    .q(ofm_x_value),
    .ce(ofm_x_ce)
  );

  // For calculating the OFM indexing value
  wire [31:0] ofm_offset0_next, ofm_offset0_value;
  wire ofm_offset0_ce, ofm_offset0_rst;

  REGISTER_R_CE #(.N(32), .INIT(0)) ofm_offset0_reg (
    .clk(clk),
    .rst(ofm_offset0_rst),
    .d(ofm_offset0_next),
    .q(ofm_offset0_value),
    .ce(ofm_offset0_ce)
  );

  // For calculating the OFM indexing value
  wire [31:0] ofm_offset1_next, ofm_offset1_value;
  wire ofm_offset1_ce, ofm_offset1_rst;

  REGISTER_R_CE #(.N(32), .INIT(0)) ofm_offset1_reg (
    .clk(clk),
    .rst(ofm_offset1_rst),
    .d(ofm_offset1_next),
    .q(ofm_offset1_value),
    .ce(ofm_offset1_ce)
  );

  // For calculating the IFM indexing value
  wire [31:0] ifm_offset0_next, ifm_offset0_value;
  wire ifm_offset0_ce, ifm_offset0_rst;

  REGISTER_R_CE #(.N(32), .INIT(0)) ifm_offset0_reg (
    .clk(clk),
    .rst(ifm_offset0_rst),
    .d(ifm_offset0_next),
    .q(ifm_offset0_value),
    .ce(ifm_offset0_ce)
  );

  // For calculating the IFM indexing value
  wire [31:0] ifm_offset1_next, ifm_offset1_value;
  wire ifm_offset1_ce, ifm_offset1_rst;

  REGISTER_R_CE #(.N(32), .INIT(0)) ifm_offset1_reg (
    .clk(clk),
    .rst(ifm_offset1_rst),
    .d(ifm_offset1_next),
    .q(ifm_offset1_value),
    .ce(ifm_offset1_ce)
  );

  // For calculating the WT indexing value
  wire [31:0] wt_offset0_next, wt_offset0_value;
  wire wt_offset0_ce, wt_offset0_rst;

  REGISTER_R_CE #(.N(32), .INIT(0)) wt_offset0_reg (
    .clk(clk),
    .rst(wt_offset0_rst),
    .d(wt_offset0_next),
    .q(wt_offset0_value),
    .ce(wt_offset0_ce)
  );

  // For calculating the WT indexing value
  wire [31:0] wt_offset1_next, wt_offset1_value;
  wire wt_offset1_ce, wt_offset1_rst;

  REGISTER_R_CE #(.N(32), .INIT(0)) wt_offset1_reg (
    .clk(clk),
    .rst(wt_offset1_rst),
    .d(wt_offset1_next),
    .q(wt_offset1_value),
    .ce(wt_offset1_ce)
  );

  // Count the number of shifts per sliding window (WT_SIZE)
  wire [31:0] shift_cnt_next, shift_cnt_value;
  wire shift_cnt_ce, shift_cnt_rst;

  REGISTER_R_CE #(.N(32), .INIT(0)) shift_cnt_reg (
    .clk(clk),
    .rst(shift_cnt_rst),
    .d(shift_cnt_next),
    .q(shift_cnt_value),
    .ce(shift_cnt_ce)
  );

  // For holding OFM read data (partial sum from previous channels)
  wire [31:0] ofm_data_next, ofm_data_value;
  wire ofm_data_ce, ofm_data_rst;

  REGISTER_R_CE #(.N(32), .INIT(0)) ofm_data_reg (
    .clk(clk),
    .rst(ofm_data_rst),
    .d(ofm_data_next),
    .q(ofm_data_value),
    .ce(ofm_data_ce)
  );

  // keep the state of the done signal
  // It needs to stay HIGH after the compute is done
  // and restart to 0 once the compute starts again
  wire compute_done_next, compute_done_value;
  wire compute_done_ce, compute_done_rst;
  REGISTER_R_CE #(.N(1), .INIT(0)) compute_done_reg (
    .clk(clk),
    .rst(compute_done_rst),
    .d(compute_done_next),
    .q(compute_done_value),
    .ce(compute_done_ce)
  );

  wire [DWIDTH-1:0] wt_sr_next [0:WT_SIZE-1];
  wire [DWIDTH-1:0] wt_sr_value[0:WT_SIZE-1];
  wire wt_sr_ce [0:WT_SIZE-1];
  wire wt_sr_rst[0:WT_SIZE-1];

  genvar i;
  generate
    for (i = 0; i < WT_SIZE; i = i + 1) begin
      REGISTER_R_CE #(.N(DWIDTH), .INIT(0)) wt_sr_reg (
        .clk(clk),
        .rst(wt_sr_rst[i]),
        .d(wt_sr_next[i]),
        .q(wt_sr_value[i]),
        .ce(wt_sr_ce[i])
      );
    end
  endgenerate

  wire [DWIDTH-1:0] ifm_sr_next [0:WT_SIZE-1];
  wire [DWIDTH-1:0] ifm_sr_value[0:WT_SIZE-1];
  wire ifm_sr_ce [0:WT_SIZE-1];
  wire ifm_sr_rst[0:WT_SIZE-1];

  generate
    for (i = 0; i < WT_SIZE; i = i + 1) begin
      REGISTER_R_CE #(.N(DWIDTH), .INIT(0)) ifm_sr_reg (
        .clk(clk),
        .rst(ifm_sr_rst[i]),
        .d(ifm_sr_next[i]),
        .q(ifm_sr_value[i]),
        .ce(ifm_sr_ce[i])
      );
    end
  endgenerate

  wire [31:0] acc_next, acc_value;
  wire acc_ce, acc_rst;

  REGISTER_R_CE #(.N(32), .INIT(0)) acc_reg (
    .clk(clk),
    .rst(acc_rst),
    .d(acc_next),
    .q(acc_value),
    .ce(acc_ce)
  );

  wire [31:0] window_index = window_y_value * WT_DIM + window_x_value;

  assign wt_addr   = wt_offset0_value  + wt_offset1_value  + window_index;
  assign ifm_addr  = ifm_offset0_value + ifm_offset1_value + ofm_x_value + ifm_idx_value;
  assign ofm_addr0 = ofm_offset0_value + ofm_offset1_value + ofm_x_value;
  assign ofm_addr1 = ofm_offset0_value + ofm_offset1_value + ofm_x_value;

  wire idle          = state_value == STATE_IDLE;
  wire fetch_ofm     = state_value == STATE_FETCH_OFM;
  wire fetch_wt      = state_value == STATE_FETCH_WT;
  wire fetch_ifm     = state_value == STATE_FETCH_IFM;
  wire compute       = state_value == STATE_COMPUTE;
  wire write_ofm     = state_value == STATE_WRITE_OFM;
  wire done          = state_value == STATE_DONE;

  wire shift_done  = compute & (shift_cnt_value == WT_SIZE - 1);

  wire read_wt_success   = fetch_wt  & wt_dout_fire;
  wire read_ifm_success  = fetch_ifm & ifm_dout_fire;
  wire read_ofm_success  = fetch_ofm & ofm_dout0_fire;
  wire write_ofm_success = write_ofm & ofm_din1_fire;

  // conv2D is done when we write the last OFM result
  wire conv2D_done = write_ofm_success &
                     (ofm_x_value == ofm_dim - 1) &
                     (ofm_y_value == ofm_dim - 1);

  // conv3D is done when we write the last OFM result
  // of the last ifm channel of the last ofm channel
  wire conv3D_done = conv2D_done &
                     (ic_cnt_value == ifm_depth - 1) &
                     (oc_cnt_value == ofm_depth - 1);

  // Read from OFM when we need to accumulate the past (partial) OFM result
  // with the current computing result
  // Read from WT at the beginning -- fetch all WT_SIZE weight elements
  // Read from IFM next -- fetch all WT_SIZE ifm elements of the current sliding
  // window that we are computing
  // Write a single OFM element back to DDR whenever we finish one sliding-window
  // computation
  always @(*) begin
    state_next = state_value;

    case (state_value)
      STATE_IDLE: begin
        if (compute_start) begin
          // Skip the OFM fetch stage since we don't read from OFM
          // for the initial computation of the first output channel
          state_next = STATE_FETCH_WT;
        end
      end

      STATE_FETCH_OFM: begin
        if (ofm_dout0_fire)
          state_next = STATE_FETCH_WT;
      end

      // fetch WT_SIZE weight elements
      STATE_FETCH_WT: begin
        if (window_index == WT_SIZE - 1 && wt_dout_fire)
          state_next = STATE_FETCH_IFM;
      end

      // fetch WT_SIZE ifm elements (one WT_DIM x WT_DIM window of ifm)
      STATE_FETCH_IFM: begin
        if (window_index == WT_SIZE - 1 && ifm_dout_fire)
          state_next = STATE_COMPUTE;
      end

      // one sliding-window computation
      STATE_COMPUTE: begin
        if (shift_cnt_value == WT_SIZE - 1)
          state_next = STATE_WRITE_OFM;
      end

      STATE_WRITE_OFM: begin
        if (ofm_din1_fire) begin
          if (conv3D_done)
            state_next = STATE_DONE;
          else begin
            // Don't fetch ofm if we are computing the first channel
            if (ic_cnt_value == 0 && (~conv2D_done))
              state_next = STATE_FETCH_IFM;
            // If we compute all the IFM channels, fetch the next set of weights
            else if (conv2D_done && ic_cnt_value == ifm_depth - 1)
              state_next = STATE_FETCH_WT;
            // Otherwise we fetch the old (partial) ofm from previous ifm channel to
            // accumulate with th next compute iteration of the current ifm channel
            else
              state_next = STATE_FETCH_OFM;
          end
        end
      end

      STATE_DONE: begin
        state_next = STATE_IDLE;
      end

    endcase
  end


  assign compute_idle = idle;
  assign compute_done = compute_done_value;

  assign compute_done_next = 1'b1;
  assign compute_done_ce   = done;
  assign compute_done_rst  = (idle & compute_start) | rst;

  // update output channel counter when we finish conv2D of all IFM channel
  // (convolving with the current weight)
  assign oc_cnt_next = oc_cnt_value + 1;
  assign oc_cnt_ce   = (conv2D_done & ic_cnt_value == ifm_depth - 1);
  assign oc_cnt_rst  = idle;

  // OFM indexing setup
  // ofm[ofm_offset0 + ofm_offset1 + ofm_x]
  //
  // current result of the sliding window
  assign ofm_x_next = ofm_x_value + 1;
  assign ofm_x_ce   = write_ofm & ofm_din1_fire;
  assign ofm_x_rst  = (write_ofm & ofm_din1_fire & (ofm_x_value == ofm_dim - 1)) | idle;

  // current result of the sliding window
  assign ofm_y_next = ofm_y_value + 1;
  assign ofm_y_ce   = write_ofm & ofm_din1_fire & (ofm_x_value == ofm_dim - 1);
  assign ofm_y_rst  = conv2D_done | idle;

  // next OFM row
  assign ofm_offset1_next = ofm_offset1_value + ofm_dim;
  assign ofm_offset1_ce   = write_ofm & ofm_din1_fire & (ofm_x_value == ofm_dim - 1);
  assign ofm_offset1_rst  = conv2D_done | idle;

  // next OFM channel
  assign ofm_offset0_next = ofm_offset0_value + ofm_size;
  assign ofm_offset0_ce   = (conv2D_done & ic_cnt_value == ifm_depth - 1);
  assign ofm_offset0_rst  = idle;

  // update input channel counter when we finish conv2D of the current channel
  assign ic_cnt_next = ic_cnt_value + 1;
  assign ic_cnt_ce   = conv2D_done;
  assign ic_cnt_rst  = (conv2D_done & ic_cnt_value == ifm_depth - 1) | idle;

  // IFM indexing setup
  // ifm[ifm_offset0 + ifm_offset1 + ofm_x + ifm_idx]
  //
  // current sliding window indexing
  assign ifm_idx_next = (window_x_value == WT_DIM - 1) ? (ifm_idx_value + ifm_dim - WT_DIM + 1) :
                                                         (ifm_idx_value + 1);
  assign ifm_idx_ce   = fetch_ifm & ifm_dout_fire;
  assign ifm_idx_rst  = (window_index == WT_SIZE - 1) & ifm_dout_fire;

  // next IFM row
  assign ifm_offset1_next = ifm_offset1_value + ifm_dim;
  assign ifm_offset1_ce   = shift_done & (ofm_x_value == ofm_dim - 1);
  assign ifm_offset1_rst  = conv2D_done | idle;

  // next IFM channel
  assign ifm_offset0_next = ifm_offset0_value + ifm_size;
  assign ifm_offset0_ce   = conv2D_done;
  assign ifm_offset0_rst  = (conv2D_done & ic_cnt_value == ifm_depth - 1) | idle;

  // WT indexing setup
  // wt[wt_offset0 + wt_offset1 + window_y * WT_SIZE + window_x]
  //
  // next WT channel
  assign wt_offset1_next = wt_offset1_value + WT_SIZE;
  assign wt_offset1_ce   = conv2D_done;
  assign wt_offset1_rst  = (conv2D_done & ic_cnt_value == ifm_depth - 1) | idle;

  // next WT (set of new WT channels)
  assign wt_offset0_next = wt_offset0_value + wt_volume;
  assign wt_offset0_ce   = (conv2D_done & ic_cnt_value == ifm_depth - 1);
  assign wt_offset0_rst  = idle;

  // current sliding window (x)
  assign window_x_next = window_x_value + 1;
  assign window_x_ce   = read_wt_success | read_ifm_success;
  assign window_x_rst  = (window_x_value == WT_DIM - 1) &
                         (read_wt_success | read_ifm_success);

  // current sliding window (y)
  assign window_y_next = window_y_value + 1;
  assign window_y_ce   = (window_x_value == WT_DIM - 1) &
                         (read_wt_success | read_ifm_success);
  assign window_y_rst  = (window_y_value == WT_DIM - 1) &
                         (window_x_value == WT_DIM - 1) &
                         (read_wt_success | read_ifm_success);

  // Read request to the Memory Interface unit
  assign wt_dout_ready   = fetch_wt;
  assign ifm_dout_ready  = fetch_ifm;
  assign ofm_dout0_ready = fetch_ofm;

  // Write request to the Memory Interface unit
  assign ofm_din1       = ofm_data_value + acc_value;
  assign ofm_din1_valid = write_ofm;
  assign ofm_we1        = ofm_din1_fire;

  // Shift registers to hold weight data
  generate
    for (i = 0; i < WT_SIZE; i = i + 1) begin
      if (i == WT_SIZE - 1)
        assign wt_sr_next[i] = fetch_wt ? wt_dout : wt_sr_value[0];
      else
        assign wt_sr_next[i] = wt_sr_value[i + 1];

      assign wt_sr_ce[i]  = read_wt_success | compute;
      assign wt_sr_rst[i] = idle;
    end
  endgenerate

  // Shift registers to hold ifm data
  generate
    for (i = 0; i < WT_SIZE; i = i + 1) begin
      if (i == WT_SIZE - 1)
        assign ifm_sr_next[i] = fetch_ifm ? ifm_dout : ifm_sr_value[0];
      else
        assign ifm_sr_next[i] = ifm_sr_value[i + 1];

      assign ifm_sr_ce[i]  = read_ifm_success | compute;
      assign ifm_sr_rst[i] = idle;
    end
  endgenerate

  // Reg the read OFM data from the DDR
  assign ofm_data_next = ofm_dout0;
  assign ofm_data_ce   = read_ofm_success;
  assign ofm_data_rst  = (conv2D_done & ic_cnt_value == ifm_depth - 1) | idle;

  // A single multiply-accumulator to compute one sliding-window computation of an OFM element
  //        wt[0] <-- wt[1] <-- wt[2] <-- ... <-- wt[WT_SIZE-1]
  //        |                                        ^
  //        |________________________________________|
  //        |
  // acc = +*
  //        |________________________________________
  //        |                                        |
  //        |                                        v
  //        ifm[0] <-- ifm[1] <-- ifm[2] <-- ... <-- ifm[WT_SIZE-1]

  // Use of DSP block here is not necessary unless we'd like to optimize
  // for higher clock frequency (< 8ns), since 8b signed multiplication
  // is not very expensive when implementing with LUTs

  wire signed [15:0] ifm_s0 = $signed(ifm_sr_value[0]);
  wire signed [15:0] wt_s0  = $signed(wt_sr_value[0]);
  (* use_dsp48 = "yes" *) wire signed [15:0] tmp  = ifm_s0 * wt_s0;

  assign acc_next = acc_value + {{16{tmp[15]}}, tmp[15:0]};
  assign acc_ce   = compute;
  assign acc_rst  = fetch_ifm | idle;

  // shift count. Count WT_SIZE cycles to finish one sliding-window computation
  assign shift_cnt_next = shift_cnt_value + 1;
  assign shift_cnt_ce   = compute;
  assign shift_cnt_rst  = shift_done | idle;

endmodule
