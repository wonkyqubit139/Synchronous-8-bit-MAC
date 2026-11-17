# STA + power for a synthesized netlist, ACT = input toggle rate for the vectorless power

read_liberty $::env(LIB)
# openroad needs the lef files too, standalone opensta doesn't
if {[llength [info commands read_lef]] && [info exists ::env(SCL)]} {
    read_lef $::env(SCL)/techlef/sky130_fd_sc_hd__nom.tlef
    read_lef $::env(SCL)/lef/sky130_fd_sc_hd.lef
    read_lef $::env(SCL)/lef/sky130_ef_sc_hd.lef
}
read_verilog $::env(NET)
link_design mac8
read_sdc $::env(SDC)
set_power_activity -input -activity $::env(ACT)
set out $::env(OUT)

report_checks -path_delay max -format full_clock_expanded -fields {slew cap input_pins fanout} -digits 3 > $out/timing_setup.rpt
report_checks -path_delay min -format full_clock_expanded -digits 3 > $out/timing_hold.rpt
# reg to reg only, so the io delay assumption doesn't hide the real logic delay
report_checks -path_delay max -from [all_registers -clock_pins] -to [all_registers -data_pins] -digits 3 > $out/timing_reg2reg.rpt
# option names differ in openroad's copy of opensta
if {[catch {report_checks -path_delay max -group_path_count 5 -endpoint_path_count 1 -digits 3 -format end > $out/timing_top_endpoints.rpt}]} {
    report_checks -path_delay max -group_count 5 -endpoint_count 1 -digits 3 -format end > $out/timing_top_endpoints.rpt
}
report_power -digits 6 > $out/power.rpt

# small summary for the other scripts
set f [open $out/summary.txt w]
puts $f "wns_setup [sta::format_time [sta::worst_slack_cmd max] 4]"
puts $f "wns_hold  [sta::format_time [sta::worst_slack_cmd min] 4]"
puts $f "tns_setup [sta::format_time [sta::total_negative_slack_cmd max] 4]"
close $f
exit
