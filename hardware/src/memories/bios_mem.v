module bios_mem (
    input clk,
    input ena,
    input [11:0] addra,
    output reg [31:0] douta,
    input enb,
    input [11:0] addrb,
    output reg [31:0] doutb
);
    parameter DEPTH = 4096;
    reg [31:0] mem [4096-1:0];
    always @(posedge clk) begin
        if (ena) begin
            douta <= mem[addra];
        end
    end

    always @(posedge clk) begin
        if (enb) begin
            doutb <= mem[addrb];
        end
    end

    `define STRINGIFY_BIOS(x) `"x/../software/bios/bios.hex`"
    `ifdef SYNTHESIS
        initial begin
            $readmemh(`STRINGIFY_BIOS(`ABS_TOP), mem);
        end
    `endif
endmodule
