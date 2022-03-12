`timescale 1ns/1ns

module conv3D_testbench();
  reg clk, rst;
  parameter CPU_CLOCK_PERIOD = 20;
  parameter CPU_CLOCK_FREQ   = 1_000_000_000 / CPU_CLOCK_PERIOD;

  initial clk = 0;
  always #(CPU_CLOCK_PERIOD/2) clk = ~clk;

  localparam TIMEOUT_CYCLE = 10_000_000;

  // TODO: change these parameters to test with the real layer parameters
  localparam DWIDTH     = 8;
  localparam IFM_DIM    = 28;
  localparam IFM_DEPTH  = 2;
  localparam WT_DIM     = 5;
  localparam OFM_DIM    = IFM_DIM - WT_DIM + 1;
  localparam OFM_DEPTH  = 2;

  localparam IFM_SIZE  = IFM_DIM * IFM_DIM;
  localparam IFM_LEN   = IFM_DEPTH * IFM_SIZE;

  localparam WT_SIZE   = WT_DIM * WT_DIM;
  localparam WT_VOLUME = WT_SIZE * IFM_DEPTH;
  localparam WT_LEN    = OFM_DEPTH * WT_VOLUME;

  localparam OFM_SIZE  = OFM_DIM * OFM_DIM;
  localparam OFM_LEN   = OFM_DEPTH * OFM_SIZE;

  localparam AXI_AWIDTH = 32;
  localparam AXI_DWIDTH = 32;

  wire [31:0] ifm_dim   = IFM_DIM;
  wire [31:0] ifm_size  = IFM_SIZE;
  wire [31:0] ifm_depth = IFM_DEPTH;
  wire [31:0] ifm_len   = IFM_LEN;

  wire [31:0] wt_volume = WT_VOLUME;
  wire [31:0] wt_len    = WT_LEN;

  wire [31:0] ofm_dim   = OFM_DIM;
  wire [31:0] ofm_size  = OFM_SIZE;
  wire [31:0] ofm_depth = OFM_DEPTH;
  wire [31:0] ofm_len   = OFM_LEN;

  // size the BRAMs large enough
  localparam WT_AWIDTH  = 10;
  localparam IFM_AWIDTH = 10;
  localparam OFM_AWIDTH = 13;

  wire [31:0] wt_addr;
  wire [31:0] wt_dout_word;

  SYNC_RAM #(
    .AWIDTH(WT_AWIDTH),
    .DWIDTH(32)
  ) wt_buffer (
    .clk(clk),
    .addr(wt_addr[31:2]),
    .d(32'b0),
    .q(wt_dout_word),
    .we(1'b0),
    .en(1'b1)
  );

  wire [31:0] ifm_addr;
  wire [31:0] ifm_dout_word;

  SYNC_RAM #(
    .AWIDTH(IFM_AWIDTH),
    .DWIDTH(32)
  ) ifm_buffer (
    .clk(clk),
    .addr(ifm_addr[31:2]),
    .d(32'b0),
    .q(ifm_dout_word),
    .we(1'b0),
    .en(1'b1)
  );

  wire [OFM_AWIDTH-1:0] ofm_addr0, ofm_addr1;
  wire [31:0]           ofm_din1, ofm_dout0;
  wire ofm_we1;

  SYNC_RAM_DP #(
    .AWIDTH(OFM_AWIDTH),
    .DWIDTH(32)
  ) ofm_buffer (
    .clk(clk),

    // Read
    .addr0(ofm_addr0),
    .d0(32'b0),
    .q0(ofm_dout0),
    .we0(1'b0),
    .en0(1'b1),

    // Write
    .addr1(ofm_addr1),
    .d1(ofm_din1),
    .q1(),
    .we1(ofm_we1),
    .en1(1'b1)
  );

  wire ifm_dout_valid;
  wire ifm_dout_ready;
  wire wt_dout_valid;
  wire wt_dout_ready;
  wire ofm_dout0_valid;
  wire ofm_dout0_ready;
  wire ofm_din1_valid;
  wire ofm_din1_ready;

  reg  compute_start;
  wire compute_idle;
  wire compute_done;

  wire [DWIDTH-1:0] wt_dout, ifm_dout;

  // TODO: replace the naive compute module here with your own optimized compute unit
  // The handshake interfaces can be trimmed off if your compute unit only reads
  // or writes to some BRAMs (static read and write)
  xcel_naive_compute #(
    .DWIDTH(DWIDTH),
    .WT_DIM(WT_DIM)
  ) dut (
    .clk(clk),
    .rst(rst),

    // IFM read
    .ifm_addr(ifm_addr),               // output
    .ifm_dout(ifm_dout),               // input
    .ifm_dout_valid(ifm_dout_valid),   // input
    .ifm_dout_ready(ifm_dout_ready),   // output

    // WT read
    .wt_addr(wt_addr),                 // output
    .wt_dout(wt_dout),                 // input
    .wt_dout_valid(wt_dout_valid),     // input
    .wt_dout_ready(wt_dout_ready),     // output

    // OFM read
    .ofm_addr0(ofm_addr0),             // output
    .ofm_dout0(ofm_dout0),             // input
    .ofm_dout0_valid(ofm_dout0_valid), // input
    .ofm_dout0_ready(ofm_dout0_ready), // output

    // OFM write
    .ofm_addr1(ofm_addr1),             // output
    .ofm_din1(ofm_din1),               // output 
    .ofm_din1_valid(ofm_din1_valid),   // output
    .ofm_din1_ready(ofm_din1_ready),   // input
    .ofm_we1(ofm_we1),

    .compute_start(compute_start),     // input
    .compute_idle(compute_idle),       // output
    .compute_done(compute_done),       // output

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

  reg read_wt  = 1'b0;
  reg read_ifm = 1'b0;
  reg read_ofm = 1'b0;

  // Read from synchronous memory blocks takes one cycle
  always @(posedge clk) begin
    if (read_wt === 1'b1)
      read_wt <= 1'b0;
    else if (wt_dout_ready === 1'b1)
      read_wt <= 1'b1;

    if (read_ifm === 1'b1)
      read_ifm <= 1'b0;
    else if (ifm_dout_ready === 1'b1)
      read_ifm <= 1'b1;

    if (read_ofm === 1'b1)
      read_ofm <= 1'b0;
    else if (ofm_dout0_ready === 1'b1)
      read_ofm <= 1'b1;
  end

  // Simple handshake logic
  assign ifm_dout_valid  = read_ifm;
  assign wt_dout_valid   = read_wt;
  assign ofm_dout0_valid = read_ofm;

  assign ofm_din1_ready = 1'b1;

  wire [1:0] ifm_byte_offset = ifm_addr[1:0];
  wire [1:0] wt_byte_offset  = wt_addr[1:0];

  assign ifm_dout = ifm_byte_offset == 2'b00 ? ifm_dout_word[7:0]   :
                    ifm_byte_offset == 2'b01 ? ifm_dout_word[15:8]  :
                    ifm_byte_offset == 2'b10 ? ifm_dout_word[23:16] :
                                               ifm_dout_word[31:24];

  assign wt_dout =  wt_byte_offset == 2'b00 ? wt_dout_word[7:0]   :
                    wt_byte_offset == 2'b01 ? wt_dout_word[15:8]  :
                    wt_byte_offset == 2'b10 ? wt_dout_word[23:16] :
                                              wt_dout_word[31:24];

  // See: sim/conv3D_sw.v
  conv3D_sw #(
    .IFM_DIM(IFM_DIM),
    .IFM_DEPTH(IFM_DEPTH),
    .OFM_DIM(OFM_DIM),
    .OFM_DEPTH(OFM_DEPTH),
    .WT_DIM(WT_DIM)
  ) sw();

  integer i;
  task init_data;
    begin
      for (i = 0; i < WT_LEN+3; i = i + 4) begin
        wt_buffer.mem[i/4] = {sw.wt_data[i + 3][7:0],
                              sw.wt_data[i + 2][7:0],
                              sw.wt_data[i + 1][7:0],
                              sw.wt_data[i + 0][7:0]};
      end

      for (i = 0; i < IFM_LEN+3; i = i + 4) begin
        ifm_buffer.mem[i/4] = {sw.ifm_data[i + 3][7:0],
                               sw.ifm_data[i + 2][7:0],
                               sw.ifm_data[i + 1][7:0],
                               sw.ifm_data[i + 0][7:0]};
      end

      for (i = 0; i < OFM_LEN; i = i + 1) begin
        ofm_buffer.mem[i] = $random;
      end
    end
  endtask

  integer num_mismatches = 0;

  task check_result;
    begin
      for (i = 0; i < OFM_LEN; i = i + 1) begin
        if (ofm_buffer.mem[i] !== sw.ofm_sw_data[i]) begin
          num_mismatches = num_mismatches + 1;
          $display("Mismatch at %d: expected %d, got %d",
                   i, sw.ofm_sw_data[i], ofm_buffer.mem[i]);
        end
      end
      if (num_mismatches == 0)
        $display("Test passed!");
      else
        $display("Test failed! Num. mismatches: %d", num_mismatches);
    end
  endtask

  reg [31:0] sim_cycle;
  reg compute_running;

  always @(posedge clk) begin
    if (rst === 1'b1) begin
      compute_running <= 1'b0;
      sim_cycle <= 1'b0;
    end
    else begin
      if (compute_start === 1'b1)
        compute_running <= 1'b1;
      if (compute_running === 1'b1)
        sim_cycle <= sim_cycle + 1;
    end
  end

  integer k;

  initial begin
    //$dumpfile("conv3D_testbench.vcd");
    //$dumpvars;

    #0;
    rst = 1'b1;
    compute_start = 1'b0;
    init_data();

    repeat (10) @(posedge clk);

    @(negedge clk);
    rst = 1'b0;

    // Run twice to check if the compute unit resets properly after the previous done
    for (k = 0; k < 2; k = k + 1) begin
      @(negedge clk);
      compute_start = 1'b1;
      $display("Start!");

      @(negedge clk);
      compute_start = 1'b0;

      wait (compute_done === 1'b1);
      @(posedge clk); #1;

      check_result();
      $display("Done in %d simulation cycles!", sim_cycle);
      repeat (100) @(posedge clk);
    end

    $finish();
  end

  initial begin
    repeat (TIMEOUT_CYCLE) @(posedge clk);
    $display("Timeout!");
    $finish();
  end

endmodule
