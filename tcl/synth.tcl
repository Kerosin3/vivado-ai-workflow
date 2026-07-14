# synth.tcl — synthesis only
# Can be run standalone, or as the first stage of the pipeline.

set BUILD_DIR [expr {[info exists ::env(BUILD_DIR)] ? $::env(BUILD_DIR) : "./build"}]

open_project $BUILD_DIR/proj/proj.xpr

launch_runs synth_1
wait_on_run synth_1

set status [get_property STATUS [get_runs synth_1]]
if {[string match "*ERROR*" $status] || [string match "*Failed*" $status]} {
    puts "SYNTH FAILED: $status"
    close_project
    exit 1
}

open_run synth_1
file mkdir $BUILD_DIR/reports
report_utilization -file $BUILD_DIR/reports/utilization_synth.rpt

puts "Synthesis complete. Report: $BUILD_DIR/reports/utilization_synth.rpt"
close_project
