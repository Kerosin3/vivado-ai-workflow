// clk_gen_100mhz.v
//
// MMCM-based clock generator: takes the board's un-buffered 100 MHz
// oscillator (GCLK) and produces a jitter-filtered, globally-buffered
// 100 MHz system clock plus a lock indicator.
//
// MMCM chosen over PLLE2_BASE: this design has no need for PLLE2's lower
// jitter/power on a fixed simple ratio, and MMCM's fractional counters
// leave room to retune CLKOUT0 later without swapping primitives.
//
// Ports:
//   clk_in  - external 100 MHz oscillator, un-buffered
//   clk_out - buffered system clock, valid once locked is high
//   locked  - MMCM lock indicator; low during startup and while CLKIN
//             is unstable, so downstream logic can use it as reset

module clk_gen_100mhz #(
    parameter real    CLKIN_PERIOD_NS  = 10.0,  // 100 MHz board oscillator
    parameter real    CLKFBOUT_MULT_F  = 10.0,  // VCO = 100 MHz * 10 = 1000 MHz
    parameter real    CLKOUT0_DIVIDE_F = 10.0   // CLKOUT0 = 1000 MHz / 10 = 100 MHz
) (
    input  wire clk_in,
    output wire clk_out,
    output wire locked
);

    wire clkin1_buf;
    wire clkfbout;
    wire clkout0;

    IBUF clkin1_ibuf (
        .I (clk_in),
        .O (clkin1_buf)
    );

    MMCME2_BASE #(
        .BANDWIDTH        ("OPTIMIZED"),
        .CLKFBOUT_MULT_F  (CLKFBOUT_MULT_F),
        .CLKFBOUT_PHASE   (0.0),
        .CLKIN1_PERIOD    (CLKIN_PERIOD_NS),
        .CLKOUT0_DIVIDE_F (CLKOUT0_DIVIDE_F),
        .CLKOUT0_DUTY_CYCLE (0.5),
        .CLKOUT0_PHASE    (0.0),
        .DIVCLK_DIVIDE    (1),
        .REF_JITTER1      (0.010),
        .STARTUP_WAIT     ("FALSE")
    ) mmcm_inst (
        .CLKIN1   (clkin1_buf),
        .CLKFBIN  (clkfbout),
        .RST      (1'b0),
        .PWRDWN   (1'b0),
        .CLKOUT0  (clkout0),
        .CLKFBOUT (clkfbout),
        .LOCKED   (locked)
    );

    BUFG clkout0_bufg (
        .I (clkout0),
        .O (clk_out)
    );

endmodule
