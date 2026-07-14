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

Reports land in `build/reports/`. On a successful `bitstream.tcl` run, the
final `.bit` file is also copied to `output_products/local/` — that's the
folder to look in for the actual deliverable; `build/` itself is
regenerated/intermediate Vivado project output.

## Running a build in Docker

No local Vivado install needed — instead uses `zynq-ai-vivado:2024.1`, a
small local image built from `docker/Dockerfile.vivado`. Build it once:

```bash
docker build -t zynq-ai-vivado:2024.1 -f docker/Dockerfile.vivado docker
```

Then run the same 4 tcl stages, wrapped in `docker run`:

```bash
docker run --rm --user $(id -u):$(id -g) -e HOME=/tmp -e BUILD_DIR=./build-docker \
  -v "$(pwd)":/workspace -w /workspace \
  zynq-ai-vivado:2024.1 \
  bash -c 'source /home/vivadouser/Vivado/2024.1/settings64.sh; vivado -mode batch -source tcl/build_bd.tcl'
# repeat for tcl/synth.tcl, tcl/impl.tcl, tcl/bitstream.tcl
```

`-e HOME=/tmp` gives Vivado a writable home dir — `--user $(id -u):$(id -g)`
has no matching `/etc/passwd` entry in the container, so `$HOME` would
otherwise be unwritable. `--user $(id -u):$(id -g)` itself keeps output
files host-owned rather than root-owned; confirmed end-to-end (`build_bd.tcl`
run through this image produced a `build-docker/proj/proj.xpr` owned by the
host user).

Setting `BUILD_DIR=./build-docker` keeps this build's project tree and
reports (`build-docker/reports/`) separate from a local build's `build/` —
the tcl scripts read `BUILD_DIR` from the environment and fall back to
`./build` when it's unset, so the two never share (or fight over) the same
Vivado project. Don't run this at the same time as a local build or another
Docker build — only one Vivado process at a time, containerized or not.

The `/build-docker` slash command runs all of the above in sequence
(including building the image if it's missing).

### Why this image, and not a plain `docker pull`

Two other images were evaluated first and both had real blockers:

- `siliconbootcamp/xsim-synth-2024:riscv` launches cleanly, but its Vivado
  2024.1 install only has Artix-7 device files — `get_parts -quiet xc7z*`
  returns nothing, so `build_bd.tcl` fails at `create_project` for this
  project's `xc7z020clg484-1` target.
- `gusanagy/xilinx-vivado:2024.1-x11` (the base of `zynq-ai-vivado:2024.1`)
  does have `xc7z020clg484-1` (confirmed via `get_parts -quiet xc7z*`), but
  its `vivado` launcher hardcodes `LC_ALL=en_US.UTF-8`, a locale that isn't
  installed in the base image, so it aborts on startup with
  `locale::facet::_S_create_c_locale name not valid`.

`zynq-ai-vivado:2024.1` is `gusanagy/xilinx-vivado:2024.1-x11` plus
`locale-gen en_US.UTF-8` — see `docker/Dockerfile.vivado`. The fix has to be
baked into an image rather than repeated on every build, since containers
are ephemeral (`--rm`) and re-running `apt-get install locales` on every
stage would mean root + network access on every single build invocation.

## Final output

`write_bitstream` success is the only thing that matters as a deliverable —
everything else under `build/` / `build-docker/` is regenerated Vivado
project scaffolding. `tcl/bitstream.tcl` copies the resulting `.bit` file to:

- `output_products/local/` for a local `/build`
- `output_products/docker/` for a `/build-docker` run (selected via
  `ENGINE=docker`, since that stage's `docker run` sets it — `ENGINE`
  defaults to `local` when unset, matching the local flow)

Each successful bitstream build overwrites the previous `.bit` in that
folder — these are meant to be the current/latest known-good bitstream per
engine, not a version history (git history covers that, same rationale as
not versioning `build/reports/`).
