`include "axi_consts.vh"

// DMA controller for sending data between RISC-V DMem and off-chip DDR
module dma_controller #(
  parameter AXI_AWIDTH  = 32,
  parameter AXI_DWIDTH  = 32,
  parameter DMEM_AWIDTH = 14,
  parameter DMEM_DWIDTH = 32
) (
  input clk,
  input resetn,

  // (simplified) read request address and read data channel for
  // interfacing with AXI adapter read
  output                  dma_read_request_valid,
  input                   dma_read_request_ready,
  output [AXI_AWIDTH-1:0] dma_read_addr,
  output [31:0]           dma_read_len,
  output [2:0]            dma_read_size,
  output [1:0]            dma_read_burst,
  input  [AXI_DWIDTH-1:0] dma_read_data,
  input                   dma_read_data_valid,
  output                  dma_read_data_ready,

  // (simplified) write request address and write data channel for
  // interfacing with AXI adapter write
  output                  dma_write_request_valid,
  input                   dma_write_request_ready,
  output [AXI_AWIDTH-1:0] dma_write_addr,
  output [31:0]           dma_write_len,
  output [2:0]            dma_write_size,
  output [1:0]            dma_write_burst,
  output [AXI_DWIDTH-1:0] dma_write_data,
  output                  dma_write_data_valid,
  input                   dma_write_data_ready,
 
  // For interfacing with the IO controller logic in Riscv151
  input  dma_start,
  output dma_done,
  output dma_idle,
  input  dma_dir, // 1: DMem -> DDR, 0: DDR -> DMem
  input [31:0] dma_src_addr,
  input [31:0] dma_dst_addr,
  input [31:0] dma_len,

  // For interfacing with the DMem (port b) in Riscv151
  output [DMEM_AWIDTH-1:0]   dmem_addr,
  output [DMEM_DWIDTH-1:0]   dmem_din,
  input  [DMEM_DWIDTH-1:0]   dmem_dout,
  output [DMEM_DWIDTH/8-1:0] dmem_wbe,
  output                     dmem_en
);

  wire dma_write_request_fire = dma_write_request_valid & dma_write_request_ready;
  wire dma_write_data_fire    = dma_write_data_valid    & dma_write_data_ready;
  wire dma_read_request_fire  = dma_read_request_valid  & dma_read_request_ready;
  wire dma_read_data_fire     = dma_read_data_valid     & dma_read_data_ready;

  localparam STATE_IDLE          = 3'b000;
  localparam STATE_WRITE_DDR_ST1 = 3'b001;
  localparam STATE_WRITE_DDR_ST2 = 3'b010;
  localparam STATE_READ_DDR      = 3'b011;
  localparam STATE_DONE          = 3'b100;

  wire [2:0] state_value;
  reg  [2:0] state_next;
  REGISTER_R #(.N(3), .INIT(STATE_IDLE)) state_reg (
    .clk(clk),
    .rst(~resetn),
    .d(state_next),
    .q(state_value)
  );

  // count the number of data write transfers
  // use this to index to the DMem on a write transaction
  wire [31:0] write_cnt_next, write_cnt_value;
  wire write_cnt_ce, write_cnt_rst;
  REGISTER_R_CE #(.N(32), .INIT(0)) write_cnt_reg (
    .clk(clk),
    .rst(write_cnt_rst),
    .d(write_cnt_next),
    .q(write_cnt_value),
    .ce(write_cnt_ce)
  );

  // count the number of data read transfers
  // use this to index to the DMem on a read transaction
  wire [31:0] read_cnt_next, read_cnt_value;
  wire read_cnt_ce, read_cnt_rst;
  REGISTER_R_CE #(.N(32), .INIT(0)) read_cnt_reg (
    .clk(clk),
    .rst(read_cnt_rst),
    .d(read_cnt_next),
    .q(read_cnt_value),
    .ce(read_cnt_ce)
  );

  // keep the state of the done signal
  // It needs to stay HIGH after the DMA is done
  // and restart to 0 once the DMA starts again
  wire dma_done_next, dma_done_value;
  wire dma_done_ce, dma_done_rst;
  REGISTER_R_CE #(.N(1), .INIT(0)) dma_done_reg (
    .clk(clk),
    .rst(dma_done_rst),
    .d(dma_done_next),
    .q(dma_done_value),
    .ce(dma_done_ce)
  );

  wire idle       = state_value == STATE_IDLE;
  wire read_ddr   = state_value == STATE_READ_DDR;
  wire write_ddr1 = state_value == STATE_WRITE_DDR_ST1;
  wire write_ddr2 = state_value == STATE_WRITE_DDR_ST2;
  wire done       = state_value == STATE_DONE;

  always @(*) begin
    state_next = state_value;
    case (state_value)
    STATE_IDLE: begin
      if (dma_start) begin
        if (dma_dir == 0)
          state_next = STATE_READ_DDR;
        else
          state_next = STATE_WRITE_DDR_ST1;
      end
    end

    STATE_READ_DDR: begin
      if (read_cnt_value == dma_len)
        state_next = STATE_DONE;
    end

    STATE_WRITE_DDR_ST1: begin
      // a buffer state to setup reading from DMem,
      // since reading from synchronous memory takes one cycle
      if (dma_write_request_fire)
        state_next = STATE_WRITE_DDR_ST2;
    end

    STATE_WRITE_DDR_ST2: begin
      if (write_cnt_value == dma_len)
        state_next = STATE_DONE;
    end

    STATE_DONE: begin
      state_next = STATE_IDLE;
    end

    endcase
  end

  assign dma_idle = idle;
  assign dma_done = dma_done_value;

  assign dma_done_next = 1'b1;
  assign dma_done_ce   = done;
  assign dma_done_rst  = (idle & dma_start);

  assign write_cnt_next = write_cnt_value + 1;
  assign write_cnt_ce   = (write_ddr1 && dma_write_request_fire) | dma_write_data_fire;
  assign write_cnt_rst  = idle;

  assign read_cnt_next = read_cnt_value + 1;
  assign read_cnt_ce   = dma_read_data_fire;
  assign read_cnt_rst  = idle;

  // setup DMA write request address and data
  // use burst mode INCR with a length of dma_len and 4 bytes per data beat
  assign dma_write_request_valid = write_ddr1;
  assign dma_write_addr          = dma_dst_addr;
  assign dma_write_len           = dma_len - 1;
  assign dma_write_burst         = `BURST_INCR;
  assign dma_write_size          = 3'd2; // 2^2 bytes
  assign dma_write_data_valid    = write_ddr2;
  assign dma_write_data          = dmem_dout;

  // setup DMA read request address and read response data
  // use burst mode INCR with a length of dma_len and 4 bytes per data beat
  assign dma_read_request_valid = read_ddr;
  assign dma_read_addr          = dma_src_addr;
  assign dma_read_len           = dma_len - 1;
  assign dma_read_burst         = `BURST_INCR;
  assign dma_read_size          = 3'd2; // 2^2 bytes
  assign dma_read_data_ready    = read_ddr;

  // setup DMem access
  // write to DMem on a read from DDR, and read from DMem on a write from DDR
  assign dmem_addr = read_ddr ? (dma_dst_addr + read_cnt_value) :
                                (dma_src_addr + write_cnt_value);
  assign dmem_wbe  = (read_ddr & dma_read_data_fire) ? 4'b1111 : 4'b0;
  assign dmem_din  = dma_read_data;

  // use the enable pin of DMem to make sure that the DMem dout
  // won't get updated when there is no handshake on write/read data
  assign dmem_en   = write_ddr1 |
                     dma_write_data_fire |
                     dma_read_data_fire;
endmodule
