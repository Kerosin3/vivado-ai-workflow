# vivado-flow — minimal skeleton

## What's here

- `CLAUDE.md` — project memory for Claude Code, loaded automatically every session
- `.claude/settings.json` + `.claude/hooks/` — blocks write_bitstream if timing isn't closed
- `tcl/build_bd.tcl` — block design creation, PS7 configured directly from the
  Zedboard preset (Digilent preset.xml values, baked in as a Tcl dict)
- `tcl/synth.tcl` — synthesis only
- `tcl/impl.tcl` — implementation (place & route), stops before bitstream
- `tcl/bitstream.tcl` — write_bitstream only
- `rtl/`, `constraints/` — empty, for your source and .xdc

## Setup

Requires Vivado already installed on this machine (`/opt/XILINX/Vivado/2024.2`).

1. Fill in PART in `tcl/build_bd.tcl` if not using a Zedboard (`xc7z020clg484-1` is the default)
2. Fill in board/target frequency in `CLAUDE.md`
3. `chmod +x .claude/hooks/check-timing-before-bitstream.sh`

## Running a build

```bash
source /opt/XILINX/Vivado/2024.2/settings64.sh
vivado -mode batch -source tcl/build_bd.tcl
vivado -mode batch -source tcl/synth.tcl
vivado -mode batch -source tcl/impl.tcl
vivado -mode batch -source tcl/bitstream.tcl
```

Each stage can also be run on its own — e.g. after only changing constraints,
you can re-run just `impl.tcl` + `bitstream.tcl` without redoing synthesis.
Vivado's run system picks up incrementally from wherever a stage left off,
as long as its inputs haven't changed.

Tip: add `source .../settings64.sh` to `~/.bashrc`/`~/.zshrc` once, so you don't have to re-run it in every new terminal session.

Reports land in `build/reports/`.
