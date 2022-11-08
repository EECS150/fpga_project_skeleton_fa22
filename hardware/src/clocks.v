module clocks #(
    parameter CLK_PERIOD = 8, // period of the primary clock into the FPGA
    // Sets the CPU clock = 125Mhz * 34 / 5 / 17 = 50 MHz
    parameter CPU_CLK_CLKFBOUT_MULT = 34,
    parameter CPU_CLK_DIVCLK_DIVIDE = 5,
    parameter CPU_CLK_CLKOUT_DIVIDE  = 17,
    // Sets the PWM clock = 125 MHz * 36 / 5 / 6 = 150 MHz
    parameter PWM_CLK_CLKFBOUT_MULT = 36,
    parameter PWM_CLK_DIVCLK_DIVIDE = 5,
    parameter PWM_CLK_CLKOUT_DIVIDE = 6
) (
    input clk_125mhz,
    output cpu_clk,
    output cpu_clk_locked,
    output pwm_clk,
    output pwm_clk_locked
);
    wire cpu_clk_int, cpu_clk_g;
    wire cpu_clk_pll_fb_out, cpu_clk_pll_fb_in;
    assign cpu_clk = cpu_clk_g;

    BUFG cpu_clk_buf (.I(cpu_clk_int), .O(cpu_clk_g));
    BUFG cpu_clk_f_buf (.I(cpu_clk_pll_fb_out), .O (cpu_clk_pll_fb_in));

    // This PLL generates the cpu_clk from the 125 Mhz clock
    PLLE2_ADV #(
        .BANDWIDTH            ("OPTIMIZED"),
        .COMPENSATION         ("BUF_IN"),  // Not "ZHOLD"
        .STARTUP_WAIT         ("FALSE"),
        .DIVCLK_DIVIDE        (CPU_CLK_DIVCLK_DIVIDE),
        .CLKFBOUT_MULT        (CPU_CLK_CLKFBOUT_MULT),
        .CLKFBOUT_PHASE       (0.000),
        .CLKOUT0_DIVIDE       (CPU_CLK_CLKOUT_DIVIDE),
        .CLKOUT0_PHASE        (0.000),
        .CLKOUT0_DUTY_CYCLE   (0.500),
        .CLKIN1_PERIOD        (CLK_PERIOD)
    ) plle2_cpu_inst (
        .CLKFBOUT            (cpu_clk_pll_fb_out),
        .CLKOUT0             (cpu_clk_int),
        .CLKOUT1             (),
        .CLKOUT2             (),
        .CLKOUT3             (),
        .CLKOUT4             (),
        .CLKOUT5             (),
        // Input clock control
        .CLKFBIN             (cpu_clk_pll_fb_in),
        .CLKIN1              (clk_125mhz),
        .CLKIN2              (1'b0),
        // Tied to always select the primary input clock
        .CLKINSEL            (1'b1),
        // Other control and status signals
        .LOCKED              (cpu_clk_locked),
        .PWRDWN              (1'b0),
        .RST                 (1'b0),
        .DCLK                (1'b0),
        .DEN                 (1'b0),
        .DI                  (16'd0),
        .DWE                 (1'b0),
        .DADDR               (7'd0),
        .DO                  (),
        .DRDY                ()
    );

    wire pwm_clk_int, pwm_clk_g;
    wire pwm_clk_pll_fb_out, pwm_clk_pll_fb_in;
    assign pwm_clk = pwm_clk_g;

    BUFG pwm_clk_buf (.I(pwm_clk_int), .O(pwm_clk_g));
    BUFG pwm_clk_f_buf (.I(pwm_clk_pll_fb_out), .O (pwm_clk_pll_fb_in));

    // This PLL generates the pwm_clk from the 125 Mhz clock
    PLLE2_ADV #(
        .BANDWIDTH            ("OPTIMIZED"),
        .COMPENSATION         ("BUF_IN"),  // Not "ZHOLD"
        .STARTUP_WAIT         ("FALSE"),
        .DIVCLK_DIVIDE        (PWM_CLK_DIVCLK_DIVIDE),
        .CLKFBOUT_MULT        (PWM_CLK_CLKFBOUT_MULT),
        .CLKFBOUT_PHASE       (0.000),
        .CLKOUT0_DIVIDE       (PWM_CLK_CLKOUT_DIVIDE),
        .CLKOUT0_PHASE        (0.000),
        .CLKOUT0_DUTY_CYCLE   (0.500),
        .CLKIN1_PERIOD        (CLK_PERIOD)
    ) plle2_pwm_inst (
        .CLKFBOUT            (pwm_clk_pll_fb_out),
        .CLKOUT0             (pwm_clk_int),
        .CLKOUT1             (),
        .CLKOUT2             (),
        .CLKOUT3             (),
        .CLKOUT4             (),
        .CLKOUT5             (),
        // Input clock control
        .CLKFBIN             (pwm_clk_pll_fb_in),
        .CLKIN1              (clk_125mhz),
        .CLKIN2              (1'b0),
        // Tied to always select the primary input clock
        .CLKINSEL            (1'b1),
        // Other control and status signals
        .LOCKED              (pwm_clk_locked),
        .PWRDWN              (1'b0),
        .RST                 (1'b0),
        .DCLK                (1'b0),
        .DEN                 (1'b0),
        .DI                  (16'd0),
        .DWE                 (1'b0),
        .DADDR               (7'd0),
        .DO                  (),
        .DRDY                ()
    );
endmodule
