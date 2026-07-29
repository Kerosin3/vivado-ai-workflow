# build_bd.tcl — block design creation
# PS7 config is applied directly from the official Digilent Zedboard preset
# (preset.xml from vivado-boards/new/board_files/zedboard) — no board_part
# detection, no vendor/ symlink dance needed. If you switch boards, replace
# the ZEDBOARD_PS7_PRESET dict below with your board's own preset.xml values.

# BUILD_DIR lets the same script target an isolated project tree per build
# engine (e.g. ./build-docker when run inside the xsim-synth container),
# so a local and a dockerized Vivado never share/upgrade the same .xpr.
set BUILD_DIR [expr {[info exists ::env(BUILD_DIR)] ? $::env(BUILD_DIR) : "./build"}]

set PART "xc7z020clg484-1"

# Extracted from Digilent's official Zedboard preset.xml (ps7_preset block),
# plus FPGA1 (below) added on top for the AD9361 FMC interface.
array set ZEDBOARD_PS7_PRESET {
    PCW_APU_PERIPHERAL_FREQMHZ         650
    PCW_CRYSTAL_PERIPHERAL_FREQMHZ     33.333333
    PCW_FPGA0_PERIPHERAL_FREQMHZ       100
    PCW_FPGA1_PERIPHERAL_FREQMHZ       200
    PCW_EN_CLK1_PORT                   1
    PCW_ENET0_PERIPHERAL_ENABLE        1
    PCW_ENET0_ENET0_IO                 {MIO 16 .. 27}
    PCW_ENET0_GRP_MDIO_ENABLE          1
    PCW_ENET0_RESET_ENABLE             0
    PCW_GPIO_MIO_GPIO_ENABLE           1
    PCW_QSPI_PERIPHERAL_ENABLE         1
    PCW_QSPI_GRP_FBCLK_ENABLE          1
    PCW_QSPI_GRP_SINGLE_SS_ENABLE      1
    PCW_SD0_PERIPHERAL_ENABLE          1
    PCW_SD0_GRP_CD_ENABLE              1
    PCW_SD0_GRP_CD_IO                  {MIO 47}
    PCW_SD0_GRP_WP_ENABLE              1
    PCW_SDIO_PERIPHERAL_FREQMHZ        50
    PCW_TTC0_PERIPHERAL_ENABLE         1
    PCW_UART1_PERIPHERAL_ENABLE        1
    PCW_USB0_PERIPHERAL_ENABLE         1
    PCW_USB0_RESET_ENABLE              1
    PCW_USB0_RESET_IO                  {MIO 46}
    PCW_PRESET_BANK1_VOLTAGE           {LVCMOS 1.8V}
    PCW_UIPARAM_DDR_PARTNO             {MT41K128M16 JT-125}
    PCW_UIPARAM_DDR_FREQ_MHZ           525
    PCW_UIPARAM_DDR_BOARD_DELAY0       0.176
    PCW_UIPARAM_DDR_BOARD_DELAY1       0.159
    PCW_UIPARAM_DDR_BOARD_DELAY2       0.162
    PCW_UIPARAM_DDR_BOARD_DELAY3       0.187
    PCW_UIPARAM_DDR_DQS_TO_CLK_DELAY_0 -0.073
    PCW_UIPARAM_DDR_DQS_TO_CLK_DELAY_1 -0.034
    PCW_UIPARAM_DDR_DQS_TO_CLK_DELAY_2 -0.03
    PCW_UIPARAM_DDR_DQS_TO_CLK_DELAY_3 -0.082
    PCW_UIPARAM_DDR_TRAIN_DATA_EYE     1
    PCW_UIPARAM_DDR_TRAIN_READ_GATE    1
    PCW_UIPARAM_DDR_TRAIN_WRITE_LEVEL  1
}

create_project proj $BUILD_DIR/proj -part $PART -force

# Vendored Analog Devices IP (ip_repo/analog/library/axi_ad9361 — see the
# README there for origin/provenance) for the AD9361 FMC daughtercard.
set_property ip_repo_paths [list ./ip_repo/analog/library] [current_project]
update_ip_catalog -rebuild

# Constraints — everything under constraints/ gets added to constrs_1
set xdc_files [glob -nocomplain ./constraints/*.xdc]
if {[llength $xdc_files] > 0} {
    add_files -fileset constrs_1 -norecurse $xdc_files
} else {
    puts "WARNING: no .xdc files found in constraints/ — pin/timing constraints missing"
}

# RTL sources — everything under rtl/ gets added to sources_1
set rtl_files [glob -nocomplain ./rtl/*.v ./rtl/*.sv ./rtl/*.vhd]
if {[llength $rtl_files] > 0} {
    add_files -fileset sources_1 -norecurse $rtl_files
}

create_bd_design "system"
create_bd_cell -type ip -vlnv xilinx.com:ip:processing_system7:5.5 ps7

# Build the -dict argument from the preset array and apply it in one call
set preset_args {}
foreach {key val} [array get ZEDBOARD_PS7_PRESET] {
    lappend preset_args "CONFIG.$key" $val
}
set_property -dict $preset_args [get_bd_cells ps7]

apply_bd_automation -rule xilinx.com:bd_rule:processing_system7 \
    -config {make_external "FIXED_IO, DDR"} [get_bd_cells ps7]

# AXI-Lite register peripheral (rtl/axi_lite_regs.v) on the PS7's GP0 AXI
# master. The axi4 automation rule inserts the SmartConnect, wires up
# FCLK_CLK0 and a matching reset synchronizer, and assigns an address.
create_bd_cell -type module -reference axi_lite_regs axi_lite_regs_0

apply_bd_automation -rule xilinx.com:bd_rule:axi4 -config { \
    Clk_master {Auto} Clk_slave {Auto} Clk_xbar {Auto} \
    Master {/ps7/M_AXI_GP0} Slave {/axi_lite_regs_0/S_AXI} \
    ddr_seg {Auto} intc_ip {New AXI SmartConnect} master_apm {0} \
} [get_bd_intf_pins axi_lite_regs_0/S_AXI]

# AD9361 FMC daughtercard (vendored analog.com:user:axi_ad9361, see
# ip_repo/analog/README.md) -- digital LVDS interface + AXI-Lite register
# access only, at this stage. The ADC/DAC streaming datapath (DMA,
# channel pack/unpack, TDD sync) is deliberately not wired up yet: it only
# matters once the PS side runs Linux + the IIO driver, so unused
# ADC/DAC-path and TDD ports are tied off below instead.
create_bd_cell -type ip -vlnv analog.com:user:axi_ad9361:1.0 axi_ad9361_0

apply_bd_automation -rule xilinx.com:bd_rule:axi4 -config { \
    Clk_master {Auto} Clk_slave {Auto} Clk_xbar {Auto} \
    Master {/ps7/M_AXI_GP0} Slave {/axi_ad9361_0/s_axi} \
    ddr_seg {Auto} intc_ip {Auto} master_apm {0} \
} [get_bd_intf_pins axi_ad9361_0/s_axi]

# delay_clk needs a stable 200MHz reference for IDELAYCTRL calibration
# (FCLK1, enabled in the PS7 preset above, purely for this).
connect_bd_net [get_bd_pins ps7/FCLK_CLK1] [get_bd_pins axi_ad9361_0/delay_clk]

# l_clk is the interface clock axi_ad9361 recovers from rx_clk_in; clk is
# its own config/DDS-domain input -- looped back per ADI's own reference
# wiring (fmcomms2_bd.tcl) rather than driven from a separate source.
connect_bd_net [get_bd_pins axi_ad9361_0/l_clk] [get_bd_pins axi_ad9361_0/clk]

# Tie off everything belonging to the deferred ADC/DAC streaming datapath
# and TDD sync -- see the note above the cell.
create_bd_cell -type ip -vlnv xilinx.com:ip:xlconstant:1.1 const_zero_1b
set_property -dict {CONFIG.CONST_WIDTH 1 CONFIG.CONST_VAL 0} [get_bd_cells const_zero_1b]
create_bd_cell -type ip -vlnv xilinx.com:ip:xlconstant:1.1 const_zero_16b
set_property -dict {CONFIG.CONST_WIDTH 16 CONFIG.CONST_VAL 0} [get_bd_cells const_zero_16b]

foreach pin {adc_dovf dac_dunf dac_sync_in tdd_sync gps_pps up_enable up_txnrx} {
    connect_bd_net [get_bd_pins const_zero_1b/dout] [get_bd_pins axi_ad9361_0/$pin]
}
foreach pin {dac_data_i0 dac_data_q0 dac_data_i1 dac_data_q1} {
    connect_bd_net [get_bd_pins const_zero_16b/dout] [get_bd_pins axi_ad9361_0/$pin]
}

# Physical LVDS interface -- pin-mapped in constraints/board.xdc to the
# Zedboard FMC LPC connector (Vadj = 2.5V).
foreach port {rx_clk_in_p rx_clk_in_n rx_frame_in_p rx_frame_in_n} {
    create_bd_port -dir I ${port}
}
foreach port {tx_clk_out_p tx_clk_out_n tx_frame_out_p tx_frame_out_n} {
    create_bd_port -dir O ${port}
}
create_bd_port -dir I -from 5 -to 0 rx_data_in_p
create_bd_port -dir I -from 5 -to 0 rx_data_in_n
create_bd_port -dir O -from 5 -to 0 tx_data_out_p
create_bd_port -dir O -from 5 -to 0 tx_data_out_n
create_bd_port -dir O enable
create_bd_port -dir O txnrx

foreach pin {rx_clk_in_p rx_clk_in_n rx_frame_in_p rx_frame_in_n rx_data_in_p rx_data_in_n \
             tx_clk_out_p tx_clk_out_n tx_frame_out_p tx_frame_out_n tx_data_out_p tx_data_out_n \
             enable txnrx} {
    connect_bd_net [get_bd_ports $pin] [get_bd_pins axi_ad9361_0/$pin]
}

assign_bd_address

# LED snake demo (rtl/led_snake.v, rtl/clk_gen_100mhz.v) -- a free-running
# PL-only block wired straight to the board's own oscillator through its
# own MMCM, not through PS7/FCLK_CLK0, so the pattern stays visible
# regardless of how the PS7 side of the block design is configured.
create_bd_cell -type module -reference led_snake led_snake_0

create_bd_port -dir I -type clock GCLK
connect_bd_net [get_bd_ports GCLK] [get_bd_pins led_snake_0/clk_in]

create_bd_port -dir O -from 7 -to 0 led
connect_bd_net [get_bd_ports led] [get_bd_pins led_snake_0/led]

validate_bd_design
make_wrapper -files [get_files system.bd] -top
add_files -norecurse $BUILD_DIR/proj/proj.gen/sources_1/bd/system/hdl/system_wrapper.v

# With led_snake.v/clk_gen_100mhz.v added to sources_1 alongside the BD
# wrapper, Vivado's top auto-detection picks led_snake instead of
# system_wrapper (both look like un-instantiated roots to the plain
# hierarchy check, since the BD only references its module cells through
# IP Integrator metadata, not a textual instantiation) -- pin it explicitly.
set_property top system_wrapper [current_fileset]
update_compile_order -fileset sources_1

save_bd_design
close_project
