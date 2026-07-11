# synth.tcl — synthesis only
# Can be run standalone, or as the first stage of the pipeline.

open_project ./build/proj/proj.xpr

launch_runs synth_1
wait_on_run synth_1

set status [get_property STATUS [get_runs synth_1]]
if {[string match "*ERROR*" $status] || [string match "*Failed*" $status]} {
    puts "SYNTH FAILED: $status"
    close_project
    exit 1
}

open_run synth_1
file mkdir ./build/reports
report_utilization -file ./build/reports/utilization_synth.rpt

puts "Synthesis complete. Report: build/reports/utilization_synth.rpt"
close_project
