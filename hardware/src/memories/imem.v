module imem (
  input clk,
  input ena,
  input [3:0] wea,
  input [13:0] addra,
  input [31:0] dina,
  input [13:0] addrb,
  output reg [31:0] doutb
);
  parameter DEPTH = 16384;

  // See page 133 of the Vivado Synthesis Guide for the template
  // https://www.xilinx.com/support/documentation/sw_manuals/xilinx2016_4/ug901-vivado-synthesis.pdf

  reg [31:0] mem [16384-1:0];
  integer i;
  always @(posedge clk) begin
    if (ena) begin
      for(i=0; i<4; i=i+1) begin
        if (wea[i]) begin
          mem[addra][i*8 +: 8] <= dina[i*8 +: 8];
        end
      end
    end
  end

  always @(posedge clk) begin
      doutb <= mem[addrb];
  end
endmodule
