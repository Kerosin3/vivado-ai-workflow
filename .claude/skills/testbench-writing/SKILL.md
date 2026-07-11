---
name: testbench-writing
description: Write self-checking Verilog/SystemVerilog testbenches. Apply when creating a new RTL module, or when asked to verify/test existing RTL.
---

## Default approach

Write self-checking testbenches, not ones that dump waveforms for manual
inspection. A testbench that requires a human to look at a waveform viewer
to know if it passed is not done. Use `$display`/`$error` and a final
pass/fail summary, or SystemVerilog assertions if the toolchain supports
them (Vivado xsim does).

## Structure every testbench the same way

1. Clock/reset generation block, separate from stimulus
2. DUT instantiation
3. Stimulus tasks — one task per test scenario, named for what it checks
   (e.g. `test_reset_behavior`, `test_back_to_back_writes`), not `test1`/`test2`
4. Checker logic — compare DUT output against an independently-computed
   expected value, not a copy of the DUT's own internal logic
5. Final report: pass/fail count, exit non-zero on any failure so it's
   scriptable in a build pipeline

## Clock/reset pattern

```verilog
localparam CLK_PERIOD = 10; // 100 MHz

reg clk = 0;
always #(CLK_PERIOD/2) clk = ~clk;

reg rst_n = 0;
initial begin
    rst_n = 0;
    repeat (4) @(posedge clk);
    rst_n = 1;
end
```

## What to cover, in priority order

1. Reset behavior — outputs in known state, no X propagation after reset deasserts
2. Basic functional correctness — the "happy path"
3. Edge cases: min/max values, back-to-back operations with no idle cycles,
   simultaneous assert of multiple control signals
4. If the module has a FIFO/buffer: full and empty conditions specifically
5. Clock domain crossings, if any — these are the highest-risk area for
   subtle bugs, don't skip

## Self-checking pattern

```verilog
task automatic check_result(input [31:0] actual, input [31:0] expected, input string test_name);
    if (actual !== expected) begin
        $error("[FAIL] %s: expected %0d, got %0d", test_name, expected, actual);
        fail_count++;
    end else begin
        $display("[PASS] %s", test_name);
    end
endtask
```

## Running in this project's flow

Testbenches are simulation-only — they do not get added to `sources_1` via
the auto-glob in `tcl/build_bd.tcl`. Keep them in `rtl/tb/` or a separate
`sim/` directory so they never accidentally end up in synthesis. Run with
Vivado's simulator directly:

```bash
xvlog rtl/my_module.v rtl/tb/my_module_tb.v
xelab my_module_tb -s tb_sim
xsim tb_sim -runall
```

## Do not

- Write testbenches that only exercise the happy path
- Copy the DUT's internal computation into the checker (that just checks
  the module against itself, not against a spec)
- Leave `$display`-only testbenches with no pass/fail summary — always end
  with an explicit verdict
