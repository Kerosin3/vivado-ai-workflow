# bake_bitstream.tcl — triggers write_bitstream, then copies the resulting
# .bit to output_products/. Named "bake" rather than "bitstream" so the
# filename doesn't imply a direct 1:1 call to Vivado's write_bitstream Tcl
# command — this actually drives the whole impl_1 run up to that step via
# launch_runs, and packages the result afterward.
# Requires impl_1 to already be routed (run impl.tcl first, or this will
# auto-trigger synth+impl from scratch if they haven't run yet).
# The check-timing-before-bitstream.sh hook checks this file's report before
# allowing this script to run when STRICT_TIMING=1 is set.

set BUILD_DIR [expr {[info exists ::env(BUILD_DIR)] ? $::env(BUILD_DIR) : "./build"}]

# ENGINE picks which output_products/ subfolder the final .bit lands in —
# "local" (default) or "docker", set by the /build-docker flow.
set ENGINE [expr {[info exists ::env(ENGINE)] ? $::env(ENGINE) : "local"}]

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
    set bit_file [lindex $bit_files 0]
    puts "Bitstream generated: $bit_file"

    set out_dir "output_products/$ENGINE"
    file mkdir $out_dir
    file copy -force $bit_file $out_dir
    puts "Copied to $out_dir/[file tail $bit_file]"
} else {
    puts "WARNING: write_bitstream reported success but no .bit file found"
}

close_project
