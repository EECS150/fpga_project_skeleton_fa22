/*
A branch predictor module that implements a branch history table (BHT).

Branch prediction guessing is done with inputs *_guess (IF stage).
Branch prediction checking is done with inputs *_check (whichever stage
    the branch comparison is computed) and updates next prediction.

Predictions are updated via a 2-bit saturating counter.
*/

module branch_predictor #(
    parameter PC_WIDTH=32,
    parameter LINES=128
) (
    input clk,
    input reset,

    input [PC_WIDTH-1:0] pc_guess,
    input is_br_guess,

    input [PC_WIDTH-1:0] pc_check,
    input is_br_check,
    input br_taken_check,

    output br_pred_taken
);
    
    wire cache_hit_guess, cache_hit_check;
    wire [1:0] cache_out_guess, cache_out_check;
    wire [1:0] sat_out;

    // Since PC should be 4-byte aligned, discard 2 lowest bits of PC for caching
    bp_cache #(
        .AWIDTH(PC_WIDTH-2),
        .DWIDTH(2),
        .LINES(LINES)
    ) cache (
        .clk(clk),
        .reset(reset),
        .ra0(pc_guess[PC_WIDTH-1:2]),
        .ra1(pc_check[PC_WIDTH-1:2]),
        .wa(pc_check[PC_WIDTH-1:2]),
        .din(cache_hit_check ? sat_out : (br_taken_check ? 2'b10 : 2'b01)),
        .we(is_br_check),
        .hit0(cache_hit_guess),
        .dout0(cache_out_guess),
        .hit1(cache_hit_check),
        .dout1(cache_out_check)
    );

    sat_updn #(
        .WIDTH(2)
    ) sat (
        .in(cache_out_check),
        .up(br_taken_check),
        .dn(!br_taken_check),
        .out(sat_out)
    );

    assign br_pred_taken = is_br_guess && cache_hit_guess && cache_out_guess[1];

endmodule
