`timescale 1ns/1ns
`define CLK_PERIOD 8

module branch_predictor_tb();
    // Generate 125 Mhz clock
    reg clk = 0;
    always #(`CLK_PERIOD/2) clk = ~clk;

    // I/O
    localparam PC_WIDTH = 32;
    localparam LINES = 8;
    reg rst;
    reg [PC_WIDTH-1:0] pc_guess, pc_check;
    reg is_br_guess, is_br_check, br_taken_check;
    wire br_pred_taken;

    branch_predictor #(
        .PC_WIDTH(PC_WIDTH),
        .LINES(LINES)
    ) DUT (
        .clk(clk),
        .reset(rst),
        .pc_guess(pc_guess),
        .is_br_guess(is_br_guess),
        .pc_check(pc_check),
        .is_br_check(is_br_check),
        .br_taken_check(br_taken_check),
        .br_pred_taken(br_pred_taken)
    );

    integer num_tests_failed;
    integer i;

    task test_pred(input [PC_WIDTH-1:0] pc, input is_br, input exp_pred_taken);
        begin
            pc_guess = pc;
            is_br_guess = is_br;
            #1;
            assert(br_pred_taken == exp_pred_taken) else begin
                $error("Expected branch taken prediction = %b, got %b", exp_pred_taken, br_pred_taken);
                num_tests_failed = num_tests_failed + 1;
            end
        end
    endtask

    task update_taken(input [PC_WIDTH-1:0] pc, input is_br, input br_taken);
        begin
            @(negedge clk);
            pc_check = pc;
            is_br_check = is_br;
            br_taken_check = br_taken;
            @(posedge clk); #1;
        end
    endtask

    /*
    A basic test that covers some different test cases for a given PC.
    It is not meant to be an exhaustive test.
    */
    task test_basic(input [PC_WIDTH-1:0] pc);
        begin
            $display("Testing branch prediction for PC address: %x", pc);
            test_pred(pc, 1, 0);     // On cache miss, branch should not be taken
            update_taken(pc, 0, 1);  // Non-branch
            test_pred(pc, 1, 0);     // Still cache miss
            update_taken(pc, 1, 1);  // Branch taken
            test_pred(pc, 1, 1);     // cntr should be 10
            update_taken(pc, 1, 1);  // Branch taken
            test_pred(pc, 1, 1);     // cntr should be 11
            update_taken(pc, 1, 1);  // Branch taken
            test_pred(pc, 1, 1);     // cntr should be 11 (saturation)
            update_taken(pc, 1, 0);  // Branch not taken
            test_pred(pc, 1, 1);     // cntr should be 10
            update_taken(pc, 1, 0);  // Branch not taken
            test_pred(pc, 1, 0);     // cntr should be 01
            update_taken(pc, 1, 0);  // Branch not taken
            test_pred(pc, 1, 0);     // cntr should be 00
            update_taken(pc, 1, 0);  // Branch not taken
            test_pred(pc, 1, 0);     // cntr should be 00 (saturation)
            update_taken(pc, 1, 1);  // Branch taken
            test_pred(pc, 1, 0);     // cntr should be 01
            update_taken(pc, 1, 1);  // Branch taken
            test_pred(pc, 1, 1);     // cntr should be 10
            update_taken(pc, 0, 1);  // Non-branch
            test_pred(pc, 1, 1);     // cntr should be 10
        end
    endtask

    initial begin
        `ifdef IVERILOG
            $dumpfile("branch_predictor_tb.fst");
            $dumpvars(0, branch_predictor_tb);
        `endif
        `ifndef IVERILOG
            $vcdpluson;
            $vcdplusmemon;
        `endif

        num_tests_failed = 0;
        
        is_br_check = 0;
        br_taken_check = 0;
        rst = 1;
        @(posedge clk); #1;
        rst = 0;

        repeat (5) @(negedge clk);

        for (i = 0; i < 2 * LINES; i = i + 1)
            test_basic(i << 2);
        
        $display("Testing branch prediction caching");
        for (i = 0; i < LINES; i = i + 1) begin
            test_pred(i << 2, 1, 0);            // On cache miss, should predict not taken
            test_pred((i + LINES) << 2, 1, 1);  // On cache hit, should predict the currently stored value (taken)
        end

        if (num_tests_failed > 0) $error("%d tests failed", num_tests_failed);
        else $display("All tests passed!");
        
        `ifndef IVERILOG
            $vcdplusoff;
        `endif
        $finish();
    end
endmodule
