# vivado-flow — minimal skeleton

FPGA project for a Zedboard (Zynq-7000, `xc7z020clg484-1`), built via Vivado
in headless/batch mode. For copy-paste build commands see `TLDR.md`; for
full conventions and rules see `CLAUDE.md`.

## What's here

- `tcl/build_bd.tcl` / `synth.tcl` / `impl.tcl` / `bake_bitstream.tcl` — the
  four build stages, one file per stage
- `rtl/`, `constraints/` — your source and `.xdc`
- `docker/` — `Dockerfile.vivado` for the no-local-install build path
- `.claude/` — commands (`/build`, `/build-docker`), hooks, skills

## Setup

1. Either have Vivado installed locally (`/opt/XILINX/Vivado/2024.2`), or
   plan to use the Docker image instead — no local install needed for that path
2. Fill in `PART` in `tcl/build_bd.tcl` if not using a Zedboard
   (`xc7z020clg484-1` is the default)
3. `chmod +x .claude/hooks/check-timing-before-bitstream.sh`

## Building

Run `/build` (local Vivado) or `/build-docker` (containerized, builds the
image on first use) — see `TLDR.md` for the equivalent raw commands.

Each stage can also be run on its own — e.g. after only changing
constraints, re-run just `impl.tcl` + `bake_bitstream.tcl` without redoing
synthesis. Vivado's run system picks up incrementally as long as a stage's
inputs haven't changed.

Local and Docker builds use separate project trees (`build/` vs.
`build-docker/`) so switching between them never triggers a project-upgrade
prompt. Never run two Vivado processes — local or Docker — at the same time.

## Output

Reports land in `<build dir>/reports/`. The actual deliverable is the `.bit`
file, copied on a successful `bake_bitstream.tcl` run to
`output_products/local/` or `output_products/docker/` — each folder holds
only the current known-good bitstream for that engine, not a history.
