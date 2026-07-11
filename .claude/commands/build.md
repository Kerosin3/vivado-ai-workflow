---
description: Run the full build pipeline (bd -> synth -> impl -> bitstream), stopping on first failure
allowed-tools: Bash(vivado *), Read
---

Run these in order, stopping immediately if any step fails (non-zero exit
or "FAILED" in output) rather than continuing to the next stage:

1. `vivado -mode batch -source tcl/build_bd.tcl`
2. `vivado -mode batch -source tcl/synth.tcl`
3. `vivado -mode batch -source tcl/impl.tcl` — after this, report the WNS
   value from the output before continuing
4. `vivado -mode batch -source tcl/bitstream.tcl`

If $ARGUMENTS specifies a stage to start from (e.g. "synth", "impl",
"bitstream"), skip the earlier stages and start from there instead of the
full pipeline.
