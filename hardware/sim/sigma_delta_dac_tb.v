`timescale 1ns/1ns

module sigma_delta_dac_tb();
    
    parameter CODE_WIDTH = 10;
    parameter N = 3;
    parameter CYCLES = 2 ** CODE_WIDTH * N;
    parameter ERROR_MARGIN = 2;
    reg clock = 0;
    reg reset = 0;
    reg [CODE_WIDTH-1: 0] code;
    wire pwm;

    reg flag = 0;

    sigma_delta_dac # (
        .CODE_WIDTH(CODE_WIDTH)    
    ) sd_dac (
        .clk(clock),
        .rst(reset),
        .code(code),
        .pwm(pwm)
    );

    always #(4) clock <= ~clock;
    
    task sd_dac_single_test;
        input [CODE_WIDTH-1: 0] sd_input;
        integer i;
        integer counter, min, max;
        begin
            reset = 1;
            @(posedge clock);
            #(2);
            reset = 0;
            counter = 0;
            code = sd_input;
            for (i = 0; i < CYCLES; i = i + 1) begin
                @(posedge clock);
                #(2);
                if (pwm == 1) counter = counter + 1;
            end
            
            if (sd_input <= ERROR_MARGIN) min = 0;
            else min = sd_input - ERROR_MARGIN;
            
            if (sd_input > 2 ** CODE_WIDTH - ERROR_MARGIN) max = 2 ** CODE_WIDTH;
            else max = sd_input + ERROR_MARGIN;

            if ((counter/N < min) || (counter/N > max)) begin
                flag = 1;                
                $display("Input code is: %d;  Average number of 1 in the output sequence is: %.2f;    Accepted range is:(%4d - %4d); Not Correct!", sd_input, counter/N, min, max);
            end else
                $display("Input code is: %d;  Average number of 1 in the output sequence is: %.2f;    Accepted range is:(%4d - %4d); Correct!", sd_input, counter/N, min, max);
        end
    endtask    
        

    initial begin
        `ifdef IVERILOG
            $dumpfile("sigma_delta_dac_tb.fst");
            $dumpvars(0, sigma_delta_dac_tb);
        `endif
        `ifndef IVERILOG
            $vcdpluson;
        `endif

        sd_dac_single_test(10'd0);
        sd_dac_single_test(10'd1);
        sd_dac_single_test(10'd32);
        sd_dac_single_test(10'd300);
        sd_dac_single_test(10'd774);
        sd_dac_single_test(10'd1000);
        sd_dac_single_test(10'd1023);

        if (!flag)
            $display("All test passed!");
        else
            $display("Not passed");

        `ifndef IVERILOG
            $vcdplusoff;
        `endif
        $finish();
    end
endmodule
