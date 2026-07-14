---
description: Run the full build pipeline (bd -> synth -> impl -> bitstream) inside the local zynq-ai-vivado:2024.1 Docker image, stopping on first failure
allowed-tools: Bash(docker run *), Bash(docker build *), Bash(docker image inspect *), Read
---

This is the Docker-based equivalent of `/build` — same 4 tcl stages, run
through a containerized Vivado instead of the local install. Output lands in
`build-docker/` (not `build/`), so it never collides with a local build's
project tree or reports.

Do not run this at the same time as a local `/build` (or another
`/build-docker`) — only one Vivado process, containerized or not, at a time.

## One-time image setup

This project uses a small local derivative image, `zynq-ai-vivado:2024.1`,
built from `docker/Dockerfile.vivado` (base: `gusanagy/xilinx-vivado:2024.1-x11`,
plus `locale-gen en_US.UTF-8` — the base image's `vivado` launcher hardcodes
`LC_ALL=en_US.UTF-8` and crashes on startup without it, and since containers
are ephemeral that fix has to be baked into an image rather than redone
every run). It's also the only evaluated image confirmed to have Zynq-7000
(`xc7z020clg484-1`) device support — the smaller
`siliconbootcamp/xsim-synth-2024:riscv` image does not (Artix-7 only).

Build it once if `zynq-ai-vivado:2024.1` isn't present locally:
```
docker image inspect zynq-ai-vivado:2024.1 >/dev/null 2>&1 || \
  docker build -t zynq-ai-vivado:2024.1 -f docker/Dockerfile.vivado docker
```

## Running the pipeline

Run these in order, stopping immediately if any step fails (non-zero exit
or "FAILED" in output) rather than continuing to the next stage. Each step
mounts the repo root at `/workspace`, sources Vivado's environment, and sets
`BUILD_DIR=./build-docker` so the tcl scripts write there instead of
`./build`:

1. ```
   docker run --rm --user $(id -u):$(id -g) -e HOME=/tmp -e BUILD_DIR=./build-docker \
     -v "$(pwd)":/workspace -w /workspace \
     zynq-ai-vivado:2024.1 \
     bash -c 'source /home/vivadouser/Vivado/2024.1/settings64.sh; vivado -mode batch -source tcl/build_bd.tcl'
   ```
2. ```
   docker run --rm --user $(id -u):$(id -g) -e HOME=/tmp -e BUILD_DIR=./build-docker \
     -v "$(pwd)":/workspace -w /workspace \
     zynq-ai-vivado:2024.1 \
     bash -c 'source /home/vivadouser/Vivado/2024.1/settings64.sh; vivado -mode batch -source tcl/synth.tcl'
   ```
3. ```
   docker run --rm --user $(id -u):$(id -g) -e HOME=/tmp -e BUILD_DIR=./build-docker \
     -v "$(pwd)":/workspace -w /workspace \
     zynq-ai-vivado:2024.1 \
     bash -c 'source /home/vivadouser/Vivado/2024.1/settings64.sh; vivado -mode batch -source tcl/impl.tcl'
   ```
   — after this, report the WNS value from the output before continuing
4. ```
   docker run --rm --user $(id -u):$(id -g) -e HOME=/tmp -e BUILD_DIR=./build-docker -e ENGINE=docker \
     -v "$(pwd)":/workspace -w /workspace \
     zynq-ai-vivado:2024.1 \
     bash -c 'source /home/vivadouser/Vivado/2024.1/settings64.sh; vivado -mode batch -source tcl/bitstream.tcl'
   ```
   On success, the `.bit` file is copied to `output_products/docker/`
   (`ENGINE=docker` picks that subfolder — `tcl/bitstream.tcl` defaults to
   `output_products/local/` when `ENGINE` is unset, which is what the local
   `/build` flow uses).

`-e HOME=/tmp` gives Vivado a writable home dir under `--user
$(id -u):$(id -g)` (that numeric UID has no `/etc/passwd` entry in the
container, so `$HOME` would otherwise be unset/unwritable). `--user
$(id -u):$(id -g)` keeps all output files host-owned instead of root-owned.

If $ARGUMENTS specifies a stage to start from (e.g. "synth", "impl",
"bitstream"), skip the earlier stages and start from there instead of the
full pipeline.
