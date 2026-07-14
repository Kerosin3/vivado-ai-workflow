# Project: vivado-flow

Simple FPGA project, synthesized via locally-installed Vivado in headless/batch mode.

## Build

Local (requires Vivado installed at `/opt/XILINX/Vivado/2024.2`):

```
source /opt/XILINX/Vivado/2024.2/settings64.sh
vivado -mode batch -source tcl/build_bd.tcl
vivado -mode batch -source tcl/synth.tcl
vivado -mode batch -source tcl/impl.tcl
vivado -mode batch -source tcl/bake_bitstream.tcl
```

Or use the `/build` command to run all four stages in order.

### Docker build

Same 4 stages, run through a local image `zynq-ai-vivado:2024.1` (built from
`docker/Dockerfile.vivado`, base `gusanagy/xilinx-vivado:2024.1-x11` +
`locale-gen en_US.UTF-8` — the base image's vivado launcher hardcodes
`LC_ALL=en_US.UTF-8` and crashes without it) instead of a local Vivado
install. This is the only evaluated image with Zynq-7000 (`xc7z020clg484-1`)
device support — `siliconbootcamp/xsim-synth-2024:riscv` was tried first but
only has Artix-7 parts. Use the `/build-docker` command, or run manually:

```
docker build -t zynq-ai-vivado:2024.1 -f docker/Dockerfile.vivado docker
docker run --rm --user $(id -u):$(id -g) -e HOME=/tmp -e BUILD_DIR=./build-docker \
  -v "$(pwd)":/workspace -w /workspace \
  zynq-ai-vivado:2024.1 \
  bash -c 'source /home/vivadouser/Vivado/2024.1/settings64.sh; vivado -mode batch -source tcl/build_bd.tcl'
```
(repeat for synth.tcl / impl.tcl / bake_bitstream.tcl)

`BUILD_DIR=./build-docker` keeps the containerized project tree and reports
separate from the local `./build/` one, so switching between engines never
triggers a Vivado project-version-upgrade prompt in batch mode. The tcl
scripts default to `./build` when `BUILD_DIR` is unset. `-e HOME=/tmp` gives
Vivado a writable home dir since `--user $(id -u):$(id -g)` has no matching
`/etc/passwd` entry in the container.

## Reports

After a build, reports live in `<BUILD_DIR>/reports/` (`build/reports/` for
local, `build-docker/reports/` for the Docker flow):
- `timing_summary.rpt` — timing, check WNS/TNS
- `utilization.rpt` — resource usage (LUT/FF/BRAM/DSP)

## Final output

The only real deliverable is the `.bit` file — `build/` and `build-docker/`
are regenerated Vivado project scaffolding, not something to hand off.
`tcl/bake_bitstream.tcl` copies a successful `write_bitstream` result to
`output_products/local/` or `output_products/docker/` (picked via the
`ENGINE` env var, default `local`) — that's the folder to point at for
flashing or handoff, not `build/proj/proj.runs/impl_1/`. Each successful
build overwrites the previous `.bit` there; it's the current known-good
bitstream per engine, not a version history.

## Target

- Board: Zedboard
- PL target frequency: 100 MHz

## Timing

Project is early-stage — not everything is wired up yet, so timing closure
is not a hard gate right now.

- WNS >= 0 is the eventual target before flashing real hardware
- Negative WNS is expected and fine to iterate on for now — report the
  number, don't block progress over it
- The hook only hard-blocks write_bitstream if STRICT_TIMING=1 is set;
  by default it just warns. Set STRICT_TIMING=1 once closer to real
  board bring-up

## Hard rules

- Commit any RTL change to git before the next build iteration
- Do not launch multiple Vivado processes simulatiosly — this includes the
  Docker flow: a containerized Vivado is still a Vivado process, so never
  run `/build` and `/build-docker` (or two `/build-docker`s) at the same time
- Board files for the target board must already be installed in the local Vivado
  (`/opt/XILINX/Vivado/2024.2/data/boards/board_files/`) — don't assume apply_board_preset will
  just work without checking first

## Code conventions

- RTL: synchronous reset, active-low (`rst_n`)
- Signal names: snake_case
- TCL scripts: one file = one flow stage (build_bd / synth / impl / bake_bitstream / export_hw)
- use spaces as indents, 4 spaces as one indent level
- use lowRISC styleguide as basys for your codestyle
- in case using AXI - use Xilinx AXI port naming conventions

### Comments

- Comment *why*, not *what* — `// wait 2 cycles for BRAM read latency`,
  not `// increment counter`
- Every module gets a header comment: purpose, one line per port if the
  port name alone isn't self-explanatory, and any non-obvious timing
  assumption (e.g. "expects cs_n asserted for exactly 3 clk cycles")
- Comment any deviation from the obvious/naive implementation — if the
  code looks weird for a reason (timing closure, resource sharing,
  clock domain crossing), say why right there, not in a commit message
  that will be disconnected from the code later
- No commented-out code left in — if it's not needed, delete it (git
  history keeps it, no need for a `// old version:` block cluttering the file)
- No restating the signal name in the comment (`// data_valid signal` above
  `data_valid` is noise, not documentation)
- Do not overhelm explaining and commenting code - write only necessary explanation
  and put more detail when part is complex

### Module structure

- Port list: inputs first, then outputs, grouped by clock domain if there's
  more than one
- Parameters declared before ports, with a one-line comment for any
  non-obvious default
- One `always` block per distinct piece of logic — don't combine unrelated
  state machines into a single block for brevity
