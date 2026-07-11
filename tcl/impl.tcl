# impl.tcl — implementation (place & route) only, stops before bitstream
# Can be run standalone — Vivado will auto-run synth_1 first if it hasn't
# been run yet, or just pick up from wherever synth_1 already finished.

open_project ./build/proj/proj.xpr

launch_runs impl_1 -to_step route_design
wait_on_run impl_1

set status [get_property STATUS [get_runs impl_1]]
if {[string match "*ERROR*" $status] || [string match "*Failed*" $status]} {
    puts "IMPLEMENTATION FAILED: $status"
    close_project
    exit 1
}

open_run impl_1
file mkdir ./build/reports
report_timing_summary -file ./build/reports/timing_summary.rpt
report_utilization -file ./build/reports/utilization.rpt

if {[catch {exec grep -m1 -A2 "WNS" ./build/reports/timing_summary.rpt} wns]} {
    puts "Implementation complete. Timing: build/reports/timing_summary.rpt (could not extract WNS line automatically)"
} else {
    puts "Implementation complete. Timing: build/reports/timing_summary.rpt"
    puts $wns
}

close_project
