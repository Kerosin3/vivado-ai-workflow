# TLDR

FPGA project for a **Zedboard** (Zynq-7000, `xc7z020clg484-1`), PL target
100 MHz. Built with **Vivado 2024.x** in headless/batch mode via Tcl scripts
— no GUI, no manual project clicking. Two ways to run the build: a local
Vivado install, or a Docker image (for machines without Vivado installed).

Full details: `CLAUDE.md` (build rules, conventions) and `README.md`
(setup, rationale). This file is just the fast path.

## Run locally

Requires Vivado installed at `/opt/XILINX/Vivado/2024.2`.

```bash
source /opt/XILINX/Vivado/2024.2/settings64.sh
vivado -mode batch -source tcl/build_bd.tcl
vivado -mode batch -source tcl/synth.tcl
vivado -mode batch -source tcl/impl.tcl
vivado -mode batch -source tcl/bake_bitstream.tcl
```

Or just run the `/build` command.

## Run in Docker

No local Vivado needed. Uses a local image, `zynq-ai-vivado:2024.1`, built
from `docker/Dockerfile.vivado` (fixes a locale crash and a WebTalk/libudev
crash present in the upstream base image).

```bash
docker build -t zynq-ai-vivado:2024.1 -f docker/Dockerfile.vivado docker

docker run --rm --user $(id -u):$(id -g) -e HOME=/tmp -e BUILD_DIR=./build-docker \
  -v "$(pwd)":/workspace -w /workspace \
  zynq-ai-vivado:2024.1 \
  bash -c 'source /home/vivadouser/Vivado/2024.1/settings64.sh; vivado -mode batch -source tcl/build_bd.tcl'
# repeat for tcl/synth.tcl, tcl/impl.tcl, tcl/bake_bitstream.tcl
```

Or just run the `/build-docker` command (also builds the image if missing).

## Output

Only the `.bit` file matters as a deliverable. On a successful build it's
copied to:

- `output_products/local/` — local build
- `output_products/docker/` — Docker build

Everything else under `build/` / `build-docker/` is regenerated Vivado
project scaffolding, not something to hand off.

## Rules that matter

- Never run two Vivado processes at once (local + Docker counts as two)
- Commit RTL changes before the next build iteration
- Negative WNS is expected/fine for now (early-stage project) — it only
  hard-blocks `bake_bitstream` if `STRICT_TIMING=1` is set
