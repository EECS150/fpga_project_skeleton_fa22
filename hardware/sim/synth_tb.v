`timescale 1ns/1ns

module synth_tb();
    parameter SYS_CLK_PERIOD = 8;
    parameter N_VOICES = 1;
    parameter NUM_SAMPLES = 60_000;
    parameter CARRIER_FCW = 123033; // FCW for 440 Hz frequency
    parameter MOD_FCW = 223696; // FCW for 800 Hz frequency
    parameter MOD_SHIFT = 8;

    reg clk;
    reg rst = 0;

    reg [N_VOICES-1:0] [23:0] carrier_fcws = CARRIER_FCW;
    reg [23:0] mod_fcw = MOD_FCW;
    reg [4:0] mod_shift = MOD_SHIFT;
    reg [N_VOICES-1:0] note_en = 0;

    wire [13:0] sample;
    wire sample_valid;
    reg sample_ready = 0;

    initial clk = 0;
    always #(SYS_CLK_PERIOD/2) clk = ~clk;

    synth #(
        .N_VOICES(N_VOICES)
    ) synth (
        .clk(clk),
        .rst(rst),
        .carrier_fcws(carrier_fcws),
        .mod_fcw(mod_fcw),
        .mod_shift(mod_shift),
        .note_en(note_en),
        .sample(sample),
        .sample_valid(sample_valid),
        .sample_ready(sample_ready)
    );

    integer audio_file;
    integer num_samples_fetched = 0;
    initial begin
        `ifdef IVERILOG
            $dumpfile("synth_tb.fst");
            $dumpvars(0, synth_tb);
        `endif
        `ifndef IVERILOG
            $vcdpluson;
        `endif

        audio_file = $fopen("synth_audio.txt", "w");
        rst = 1;
        @(posedge clk); #1;
        rst = 0;
        note_en = 1;

        fork
            // Thread to pull samples from the synth
            begin
                @(posedge clk); #1;
                repeat (NUM_SAMPLES) begin
                    while (!sample_valid) @(posedge clk); #1;
                    sample_ready = 1;
                    $fwrite(audio_file, "%b\n", sample);
                    num_samples_fetched = num_samples_fetched + 1;
                    @(posedge clk); #1;
                    sample_ready = 0;
                end
            end
            // Thread to check sample values for carrier freq 440 Hz, modulator freq 800 Hz, and MOD_SHIFT = 8
            begin
                @(num_samples_fetched == 1);
                assert(sample == 14'b00000000011001) else $error("Synth output after 1 sample does not match");
                @(num_samples_fetched == 2);
                assert(sample == 14'b00000001100100) else $error("Synth output after 2 samples does not match");
                @(num_samples_fetched == 10);
                assert(sample == 14'b00001011010100) else $error("Synth output after 10 samples does not match");
            end
        join

        $fclose(audio_file);

        `ifndef IVERILOG
            $vcdplusoff;
        `endif
        $finish();
    end
endmodule
