---
description: Review RTL style/comments against project conventions and fix violations
allowed-tools: Read, Edit, Grep, Glob
argument-hint: [file or leave empty for all rtl/*.v *.sv *.vhd]
---

Review the RTL style of $ARGUMENTS (or all files under `rtl/` if no
argument given) against the conventions in `CLAUDE.md`'s "Code conventions"
section and `.claude/skills/fpga-flow/SKILL.md`.

Check specifically for:
- Synchronous reset, active-low (rst_n) — flag any async or active-high reset
- snake_case signal names
- No latches (every branch in a clocked always block assigns every output)
- Comments explain *why*, not *what* — flag comments that just restate the
  signal/line next to them
- Module header comment present: purpose + non-obvious port behavior +
  timing assumptions
- No commented-out dead code left in
- Port list ordered inputs-then-outputs, grouped by clock domain if more than one
- One always block per distinct piece of logic, not combined unrelated state machines

For each file:
1. List violations found, with line numbers
2. Fix them directly (this command has Edit access) — don't just report,
   actually apply the fixes
3. If a fix is ambiguous or risky (e.g. changing reset polarity affects
   downstream timing), ask before changing it rather than guessing

End with a short summary: files checked, violations fixed, anything left
for manual review.
