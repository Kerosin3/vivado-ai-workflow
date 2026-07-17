// led_snake.v
//
// Snake/chase pattern across the Zedboard's 8 user LEDs (LD0..LD7,
// active-high): a single lit LED rotates LD0 -> LD7 -> LD0 at a rate
// slow enough for a human eye to follow.
//
// Runs off the board's own 100 MHz oscillator (GCLK) through its own
// MMCM (clk_gen_100mhz.v) rather than the PS7's FCLK_CLK0, so the
// pattern is independent of the PS7/AXI fabric and stays visible
// regardless of how the block design's processor side is configured.
//
// Ports:
//   clk_in - external 100 MHz oscillator (GCLK pin), un-buffered
//   led    - active-high, one bit per LED; led[0] is LD0
//
// No external reset is wired to this feature (no spare button/pin
// allocated to it) — the MMCM's LOCKED output doubles as the module's
// active-low reset, so the counters can't start from an undefined state
// before the generated clock is stable.

module led_snake #(
    parameter integer TICK_DIV = 25_000_000  // 100 MHz / 25e6 = 4 Hz step rate
) (
    input  wire       clk_in,
    output wire [7:0] led
);

    localparam integer TICK_CNT_W = $clog2(TICK_DIV);

    wire clk;
    wire rst_n;

    clk_gen_100mhz clk_gen_inst (
        .clk_in  (clk_in),
        .clk_out (clk),
        .locked  (rst_n)
    );

    reg [TICK_CNT_W-1:0] tick_cnt;
    reg                  tick;

    // Divides the system clock down to a single-cycle pulse every
    // TICK_DIV cycles that advances the snake by one LED.
    always @(posedge clk) begin
        if (!rst_n) begin
            tick_cnt <= {TICK_CNT_W{1'b0}};
            tick     <= 1'b0;
        end else if (tick_cnt == TICK_DIV - 1) begin
            tick_cnt <= {TICK_CNT_W{1'b0}};
            tick     <= 1'b1;
        end else begin
            tick_cnt <= tick_cnt + 1'b1;
            tick     <= 1'b0;
        end
    end

    reg [7:0] led_reg;

    // Single lit LED rotates LD0 -> LD7 -> LD0 each tick.
    always @(posedge clk) begin
        if (!rst_n)
            led_reg <= 8'b0000_0001;
        else if (tick)
            led_reg <= {led_reg[6:0], led_reg[7]};
    end

    assign led = led_reg;

endmodule
