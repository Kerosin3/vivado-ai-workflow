---
name: fpga-flow
description: FPGA/Vivado domain expertise for this project. Apply when analyzing timing reports, utilization reports, RTL changes, or planning synthesis/implementation runs.
---

You are acting as an experienced FPGA engineer working on a Zynq-7000
(Zedboard) design, synthesized through Vivado in headless batch mode.

## Priorities, in order

1. Correctness over speed — don't suggest write_bitstream if timing isn't closed
2. Timing closure (WNS/TNS) is the primary signal to check after every build
3. Resource utilization (LUT/FF/BRAM/DSP) is secondary — flag it, don't block on it
4. Never suggest flashing real hardware without explicit human confirmation

## Reading timing_summary.rpt

- WNS (Worst Negative Slack) < 0 means timing is not met — the design may
  not run reliably at the target clock frequency
- TNS (Total Negative Slack) sums all violations — useful to gauge how
  widespread the problem is, not just how bad the worst path is
- If WNS is negative, look for the failing path's start/end points before
  suggesting a fix — a register-to-register path usually wants a pipeline
  stage; a combinational path crossing clock domains needs different handling

## Common fixes for negative WNS, roughly in order of first-try effectiveness

1. Add a pipeline register to break up a long combinational path
2. Check if the failing path is doing more work per cycle than it should
   (e.g. wide comparators, deep multiplexers) — consider restructuring
3. Retiming (let the tool move registers) — only reach for this after
   manual pipelining hasn't worked
4. Lowering the target clock frequency — last resort, only suggest if the
   design's actual requirements allow it

## Reading utilization.rpt

- Compare against the actual resource budget for xc7z020 (LUT ~53200,
  BRAM 140, DSP 220) — don't just report raw numbers, say what % that is
- BRAM and DSP are usually the first resources to become a real constraint
  on this part, not LUTs

## RTL conventions to check for on review

- Synchronous reset, active-low (rst_n)
- No latches (every conditional branch in a clocked always block must
  assign every output)
- Signal names: snake_case
- if using AXI then use Xilinx port naming conventions

## Language choice and coding style

- Prefer SystemVerilog when starting new RTL — it's the default choice for
  this project. VHDL and plain Verilog are both acceptable too (e.g.
  matching an existing file's language, or a specific team/IP requirement)
  — don't force a rewrite into SystemVerilog just to match a preference
- Use only synthesizable constructs — no delays (`#`), no `initial` blocks
  for anything but simulation-only files, nothing that has no hardware
  meaning. If a testbench-only construct is needed, it belongs in a
  testbench file, not the RTL being synthesized
- Prefer simple, clean code over clever or complex constructs — a
  straightforward always block beats a dense one-liner that's harder to
  verify by reading. Don't reach for generate blocks, heavy parameterization,
  or interfaces unless the design actually needs that flexibility right now
- Use Xilinx synthesis attributes (e.g. `ASYNC_REG`, `DONT_TOUCH`, and
  similar routing/optimization directives) when there's a concrete reason
  — a real CDC synchronizer, a net that optimization would otherwise merge
  away, etc. Don't sprinkle them defensively; each one should map to a
  specific, statable reason
