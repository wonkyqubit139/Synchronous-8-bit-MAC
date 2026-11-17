# power using the switching activity from a gate level sim vcd (+ spef if given)

read_liberty $::env(LIB)
if {[llength [info commands read_lef]] && [info exists ::env(SCL)]} {
    read_lef $::env(SCL)/techlef/sky130_fd_sc_hd__nom.tlef
    read_lef $::env(SCL)/lef/sky130_fd_sc_hd.lef
    read_lef $::env(SCL)/lef/sky130_ef_sc_hd.lef
}
read_verilog $::env(NET)
link_design mac8
read_sdc $::env(SDC)
if {[info exists ::env(SPEF)]} { read_spef $::env(SPEF); set_propagated_clock [all_clocks] }
read_vcd -scope mac8_tb/dut $::env(VCD)
catch {report_activity_annotation}
report_power -digits 6 > $::env(OUT)/power_vcd.rpt
exit
