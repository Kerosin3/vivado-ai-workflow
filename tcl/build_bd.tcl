# build_bd.tcl — block design creation
# PS7 config is applied directly from the official Digilent Zedboard preset
# (preset.xml from vivado-boards/new/board_files/zedboard) — no board_part
# detection, no vendor/ symlink dance needed. If you switch boards, replace
# the ZEDBOARD_PS7_PRESET dict below with your board's own preset.xml values.

set PART "xc7z020clg484-1"

# Extracted from Digilent's official Zedboard preset.xml (ps7_preset block)
array set ZEDBOARD_PS7_PRESET {
    PCW_APU_PERIPHERAL_FREQMHZ         650
    PCW_CRYSTAL_PERIPHERAL_FREQMHZ     33.333333
    PCW_FPGA0_PERIPHERAL_FREQMHZ       100
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

create_project proj ./build/proj -part $PART -force

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

assign_bd_address

validate_bd_design
make_wrapper -files [get_files system.bd] -top
add_files -norecurse ./build/proj/proj.gen/sources_1/bd/system/hdl/system_wrapper.v

save_bd_design
close_project
