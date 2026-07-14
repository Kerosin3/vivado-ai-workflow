# bitstream.tcl — write_bitstream only
# Requires impl_1 to already be routed (run impl.tcl first, or this will
# auto-trigger synth+impl from scratch if they haven't run yet).
# The check-timing-before-bitstream.sh hook checks this file's report before
# allowing this script to run when STRICT_TIMING=1 is set.

set BUILD_DIR [expr {[info exists ::env(BUILD_DIR)] ? $::env(BUILD_DIR) : "./build"}]

open_project $BUILD_DIR/proj/proj.xpr

launch_runs impl_1 -to_step write_bitstream
wait_on_run impl_1

set status [get_property STATUS [get_runs impl_1]]
if {[string match "*ERROR*" $status] || [string match "*Failed*" $status]} {
    puts "BITSTREAM GENERATION FAILED: $status"
    close_project
    exit 1
}

set bit_files [glob -nocomplain $BUILD_DIR/proj/proj.runs/impl_1/*.bit]
if {[llength $bit_files] > 0} {
    puts "Bitstream generated: [lindex $bit_files 0]"
} else {
    puts "WARNING: write_bitstream reported success but no .bit file found"
}

close_project
