`timescale 1ns/1ns
`include "mem_path.vh"

module synth_top_tb();
    parameter SYS_CLK_PERIOD = 8;
    localparam BAUD_RATE       = 10_000_000;
    localparam BAUD_PERIOD     = 1_000_000_000 / BAUD_RATE; // 8680.55 ns

    reg clk;
    reg [3:0] buttons = 0;
    wire aud_sd, aud_pwm;
    reg serial_in;
    real approx_dac_code = 0;
    integer counter = 0;
    integer dac_accum = 0;
    reg [23:0] fcw;

    always @(posedge clk) begin
        counter <= counter + 1;
        if (counter == 2047) begin
            dac_accum <= 0;
            approx_dac_code <= $itor(dac_accum) / 2047;
        end else begin
            dac_accum <= dac_accum + aud_pwm;
        end
    end

    reg [31:0] cycle = 0;
    always @(posedge clk) begin
        cycle <= cycle + 1;
    end

    initial clk = 0;
    always #(SYS_CLK_PERIOD/2) clk = ~clk;

    integer i;
    // Host off-chip UART --> FPGA on-chip UART (receiver)
    // The host (testbench) sends a character to the CPU via the serial line
    task host_to_fpga;
        input [7:0] char_in;
        begin
          serial_in = 0;
          #(BAUD_PERIOD);
          // Data bits (payload)
          for (i = 0; i < 8; i = i + 1) begin
            serial_in = char_in[i];
            #(BAUD_PERIOD);
          end
          // Stop bit
          serial_in = 1;
          #(BAUD_PERIOD);

          $display("[time %t, sim. cycle %d] [Host (tb) --> FPGA_SERIAL_RX] Sent char 8'h%h",
                   $time, cycle, char_in);
          repeat (300) @(posedge clk);
        end
    endtask

    z1top #(
        .BAUD_RATE(BAUD_RATE),
        // Warning: CPU_CLOCK_FREQ must match the PLL parameters!
        .CPU_CLOCK_FREQ(50_000_000),
        // PLL Parameters: sets the CPU clock = 125Mhz * 34 / 5 / 17 = 50 MHz
        .CPU_CLK_CLKFBOUT_MULT(34),
        .CPU_CLK_DIVCLK_DIVIDE(5),
        .CPU_CLK_CLKOUT_DIVIDE(17),
        .B_SAMPLE_CNT_MAX(5),
        .B_PULSE_CNT_MAX(5),
        // The PC the RISC-V CPU should start at after reset
        .RESET_PC(32'h1000_0000),
        .N_VOICES(4)
    ) top (
        .CLK_125MHZ_FPGA(clk),
        .BUTTONS(buttons),
        .SWITCHES(2'b00),
        .LEDS(),
        .FPGA_SERIAL_RX(serial_in),
        .FPGA_SERIAL_TX(),
        .AUD_PWM(aud_pwm),
        .AUD_SD(aud_sd)
    );

    initial begin
        // Load program
        $readmemh("../../software/piano/piano.hex", top.`IMEM_PATH.mem, 0, 16384-1);
        $readmemh("../../software/piano/piano.hex", top.`DMEM_PATH.mem, 0, 16384-1);

        `ifndef IVERILOG
            $vcdpluson;
        `endif
        `ifdef IVERILOG
            $dumpfile("synth_top_tb.fst");
            $dumpvars(0, synth_top_tb);
        `endif

        repeat (10) @(posedge clk);

        // wait until the PLL is locked
        while (top.pwm_rst) @(posedge clk);

        // Reset
        buttons[0] = 1'b1;
        repeat (50) @(posedge clk); #1;
        buttons[0] = 1'b0;

        // Send stimulus from UART

        // Set the modulator shift
        host_to_fpga(8'd2);
        host_to_fpga(8'd8);
        repeat (100) @(posedge clk);
        assert(top.synth_mod_shift == 'd8);

        // Set the synth shift
        // host_to_fpga(8'd5);
        // host_to_fpga(8'd2);
        // repeat (100) @(posedge clk);
        // assert(top.synth_synth_shift == 'd2);

        // Set the modulator FCW (4000 Hz)
        fcw = 24'd1118481;
        host_to_fpga(8'd1);
        host_to_fpga(fcw[7:0]);
        host_to_fpga(fcw[15:8]);
        host_to_fpga(fcw[23:16]);
        repeat (100) @(posedge clk);
        assert(top.synth_mod_fcw == fcw);

        // Start playing a note (10000 Hz)
        fcw = 24'd2796202;
        host_to_fpga(8'd3);
        host_to_fpga(fcw[7:0]);
        host_to_fpga(fcw[15:8]);
        host_to_fpga(fcw[23:16]);
        repeat (100) @(posedge clk);
        assert(top.synth_carrier_fcws[0] == fcw);
        assert(top.synth_note_en[0] == 1'b1);

        // Start playing a second note
        // fcw = 24'd1006202;
        // host_to_fpga(8'd3);
        // host_to_fpga(fcw[7:0]);
        // host_to_fpga(fcw[15:8]);
        // host_to_fpga(fcw[23:16]);
        // repeat (100) @(posedge clk);
        // assert(top.synth_carrier_fcws[1] == fcw);
        // assert(top.synth_note_en[1] == 1'b1);

        repeat (5000) @(posedge clk);

        // Stop playing a note (10000 Hz)
        fcw = 24'd2796202;
        host_to_fpga(8'd4);
        host_to_fpga(fcw[7:0]);
        host_to_fpga(fcw[15:8]);
        host_to_fpga(fcw[23:16]);
        repeat (100) @(posedge clk);
        assert(top.synth_note_en[0] == 1'b0);

        repeat (1000) @(posedge clk);

        $finish();
    end
endmodule
