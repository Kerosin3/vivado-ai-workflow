// led_snake_tb.v
//
// Self-checking testbench for led_snake.v (and, transitively,
// clk_gen_100mhz.v). Overrides TICK_DIV to a small value so the MMCM
// lock wait and a handful of rotations finish in a reasonable number of
// simulated cycles instead of the real ~4 Hz (25,000,000-cycle) rate.
//
// Uses real UNISIM primitives (IBUF/MMCME2_BASE/BUFG), so simulate with
// glbl included:
//   xvlog rtl/clk_gen_100mhz.v rtl/led_snake.v rtl/tb/led_snake_tb.v \
//         $env(XILINX_VIVADO)/data/verilog/src/glbl.v
//   xelab led_snake_tb glbl -s tb_sim
//   xsim tb_sim -runall

`timescale 1ns/1ps

module led_snake_tb;

    localparam        CLK_PERIOD     = 10;  // 100 MHz board oscillator
    localparam integer TEST_TICK_DIV = 20;  // small divider so sim finishes quickly

    reg clk_in = 0;
    always #(CLK_PERIOD/2) clk_in = ~clk_in;

    wire [7:0] led;

    led_snake #(
        .TICK_DIV (TEST_TICK_DIV)
    ) dut (
        .clk_in (clk_in),
        .led    (led)
    );

    integer fail_count;
    integer rotate_count;
    reg [7:0] prev_led;
    reg       have_prev;

    initial begin
        fail_count   = 0;
        rotate_count = 0;
        have_prev    = 1'b0;
    end

    // Every time led changes it must still be one-hot and equal the
    // previous value rotated left by exactly one bit (LD0 -> LD7 -> LD0),
    // independent of exactly which cycle the rotation lands on.
    always @(led) begin
        if (have_prev) begin
            if (^led !== 1'b1 || led == 8'b0) begin
                $display("[FAIL] led is not one-hot: %b", led);
                fail_count = fail_count + 1;
            end else if (led !== {prev_led[6:0], prev_led[7]}) begin
                $display("[FAIL] bad rotation: %b -> %b", prev_led, led);
                fail_count = fail_count + 1;
            end else begin
                rotate_count = rotate_count + 1;
            end
        end
        prev_led  = led;
        have_prev = 1'b1;
    end

    initial begin
        // STARTUP_WAIT=FALSE still models a fixed internal lock time in
        // the UNISIM behavioral simulation -- wait it out before trusting
        // led_reg's reset value.
        wait (dut.clk_gen_inst.locked === 1'b1);

        // Sample well before the first tick (TEST_TICK_DIV cycles away)
        // so this doesn't race the lock edge.
        repeat (3) @(posedge dut.clk);
        if (led !== 8'b0000_0001) begin
            $display("[FAIL] reset state: expected 00000001, got %b", led);
            fail_count = fail_count + 1;
        end else begin
            $display("[PASS] reset state: led=%b", led);
        end

        // Run long enough for a bit more than two full 8-step rotations.
        repeat (20 * TEST_TICK_DIV) @(posedge dut.clk);

        if (rotate_count < 16) begin
            $display("[FAIL] expected at least 16 rotation events, saw %0d", rotate_count);
            fail_count = fail_count + 1;
        end else begin
            $display("[PASS] observed %0d valid rotation events", rotate_count);
        end

        if (fail_count == 0)
            $display("ALL TESTS PASSED");
        else
            $display("%0d TEST(S) FAILED", fail_count);

        $finish;
    end

endmodule
