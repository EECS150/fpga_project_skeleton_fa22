
module arbiter #(
  parameter AXI_AWIDTH = 32,
  parameter AXI_DWIDTH = 32
) (

  // if xcel_busy is HIGH, xcel will communicate with the AXI adapter,
  // otherwise dma
  input xcel_busy,

  // Core (client) interface
  output                  core_read_request_valid,
  input                   core_read_request_ready,
  output [AXI_AWIDTH-1:0] core_read_addr,
  output [31:0]           core_read_len,
  output [2:0]            core_read_size,
  output [1:0]            core_read_burst,
  input  [AXI_DWIDTH-1:0] core_read_data,
  input                   core_read_data_valid,
  output                  core_read_data_ready,

  output                  core_write_request_valid,
  input                   core_write_request_ready,
  output [AXI_AWIDTH-1:0] core_write_addr,
  output [31:0]           core_write_len,
  output [2:0]            core_write_size,
  output [1:0]            core_write_burst,
  output [AXI_DWIDTH-1:0] core_write_data,
  output                  core_write_data_valid,
  input                   core_write_data_ready,

  // DMA Controller interface
  input                    dma_read_request_valid,
  output                   dma_read_request_ready,
  input  [AXI_AWIDTH-1:0]  dma_read_addr,
  input  [31:0]            dma_read_len,
  input  [2:0]             dma_read_size,
  input  [1:0]             dma_read_burst,
  output [AXI_DWIDTH-1:0]  dma_read_data,
  output                   dma_read_data_valid,
  input                    dma_read_data_ready,

  input                    dma_write_request_valid,
  output                   dma_write_request_ready,
  input [AXI_AWIDTH-1:0]   dma_write_addr,
  input [31:0]             dma_write_len,
  input [2:0]              dma_write_size,
  input [1:0]              dma_write_burst,
  input [AXI_DWIDTH-1:0]   dma_write_data,
  input                    dma_write_data_valid,
  output                   dma_write_data_ready,

  // Accelerator interface
  input                    xcel_read_request_valid,
  output                   xcel_read_request_ready,
  input  [AXI_AWIDTH-1:0]  xcel_read_addr,
  input  [31:0]            xcel_read_len,
  input  [2:0]             xcel_read_size,
  input  [1:0]             xcel_read_burst,
  output [AXI_DWIDTH-1:0]  xcel_read_data,
  output                   xcel_read_data_valid,
  input                    xcel_read_data_ready,

  input                    xcel_write_request_valid,
  output                   xcel_write_request_ready,
  input [AXI_AWIDTH-1:0]   xcel_write_addr,
  input [31:0]             xcel_write_len,
  input [2:0]              xcel_write_size,
  input [1:0]              xcel_write_burst,
  input [AXI_DWIDTH-1:0]   xcel_write_data,
  input                    xcel_write_data_valid,
  output                   xcel_write_data_ready
);

  assign core_read_request_valid = xcel_busy ? xcel_read_request_valid :
                                               dma_read_request_valid;
  assign dma_read_request_ready  = core_read_request_ready;
  assign xcel_read_request_ready = core_read_request_ready;

  assign core_read_addr  = xcel_busy ? xcel_read_addr  :
                                       dma_read_addr;
  assign core_read_len   = xcel_busy ? xcel_read_len   :
                                       dma_read_len;
  assign core_read_size  = xcel_busy ? xcel_read_size  :
                                       dma_read_size;
  assign core_read_burst = xcel_busy ? xcel_read_burst :
                                       dma_read_burst;

  assign dma_read_data  = core_read_data;
  assign xcel_read_data = core_read_data;

  assign dma_read_data_valid  = core_read_data_valid;
  assign xcel_read_data_valid = core_read_data_valid;

  assign core_read_data_ready = xcel_busy ? xcel_read_data_ready :
                                            dma_read_data_ready;

  assign core_write_request_valid = xcel_busy ? xcel_write_request_valid :
                                                dma_write_request_valid;

  assign dma_write_request_ready  = core_write_request_ready;
  assign xcel_write_request_ready = core_write_request_ready;

  assign core_write_addr  = xcel_busy ? xcel_write_addr  :
                                        dma_write_addr;
  assign core_write_len   = xcel_busy ? xcel_write_len   :
                                        dma_write_len;
  assign core_write_size  = xcel_busy ? xcel_write_size  :
                                        dma_write_size;
  assign core_write_burst = xcel_busy ? xcel_write_burst :
                                        dma_write_burst;
  assign core_write_data  = xcel_busy ? xcel_write_data  :
                                        dma_write_data;

  assign core_write_data_valid = xcel_busy ? xcel_write_data_valid :
                                             dma_write_data_valid;

  assign dma_write_data_ready  = core_write_data_ready;
  assign xcel_write_data_ready = core_write_data_ready;

endmodule
