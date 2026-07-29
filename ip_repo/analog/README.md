# Vendored Analog Devices HDL IP

`library/axi_ad9361` (AXI-mapped AD9361 digital interface core) plus its
`library/common` / `library/xilinx/common` dependencies, vendored from:

  https://github.com/analogdevicesinc/hdl
  branch: hdl_2023_r2
  commit: d146370c10fdd55156de2bafdd9b24292c01b6e1

Packaged as a Vivado IP (`component.xml`) locally with Vivado 2024.2.2
(ADI_IGNORE_VERSION_CHECK=1 — repo's declared required version was 2023.2,
close enough for a plain-Verilog core with no version-specific primitives).

Only the files axi_ad9361 actually depends on were copied (per
`library/axi_ad9361/Makefile`'s GENERIC_DEPS/XILINX_DEPS) — not ADI's full
`library/` tree. The ADC/DAC streaming datapath (util_wfifo/util_rfifo,
util_cpack2/util_upack2, axi_dmac, util_tdd_sync, util_clkdiv) is NOT
vendored — that path only matters once the PS side runs Linux + the IIO
driver, which this project defers. Right now axi_ad9361 is wired up for its
digital LVDS interface + AXI-Lite register access only, so unused ADC/DAC
port and TDD inputs are tied off in tcl/build_bd.tcl.

Licensed under GPL2 OR ADI's ADIBSD license (see LICENSE_GPL2 /
LICENSE_ADIBSD in this directory) — ADI's own dual-license terms, unchanged.
